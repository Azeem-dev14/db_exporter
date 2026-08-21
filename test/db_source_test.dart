import 'package:db_exporter/db_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for a real connection: enough of SQLite's answers to exercise
/// the introspection paths without pulling sqflite into the test.
class FakeDatabase {
  FakeDatabase({
    required this.tables,
    required this.rows,
    this.walBusy = 0,
    this.failCheckpoint = false,
  });

  final List<String> tables;
  final Map<String, List<Map<String, Object?>>> rows;
  final int walBusy;
  final bool failCheckpoint;

  final List<String> executed = <String>[];

  Future<List<Map<String, Object?>>> query(String sql) async {
    executed.add(sql);

    if (sql.contains('sqlite_master')) {
      return [
        for (final table in tables) {'name': table},
      ];
    }
    if (sql.startsWith('PRAGMA table_info')) {
      final table = _identifier(sql);
      final rowsForTable = rows[table] ?? const [];
      final columns =
          rowsForTable.isEmpty ? const <String>[] : rowsForTable.first.keys;
      return [
        for (final column in columns) {'name': column},
      ];
    }
    if (sql.startsWith('PRAGMA wal_checkpoint')) {
      if (failCheckpoint) throw StateError('database is locked');
      return [
        {'busy': walBusy, 'log': 3, 'checkpointed': 3},
      ];
    }
    if (sql.startsWith('SELECT * FROM')) {
      final table = _identifier(sql);
      final all = rows[table] ?? const [];
      final limit = RegExp(r'LIMIT (\d+)').firstMatch(sql);
      if (limit == null) return all;
      return all.take(int.parse(limit.group(1)!)).toList();
    }
    return const [];
  }

  static String _identifier(String sql) =>
      RegExp('"(.*?)"').firstMatch(sql)!.group(1)!;
}

void main() {
  final people = [
    {'id': 1, 'name': 'Ada'},
    {'id': 2, 'name': 'Grace'},
    {'id': 3, 'name': 'Katherine'},
  ];

  group('tableNames', () {
    test('filters out SQLite and ORM bookkeeping tables', () async {
      final fake = FakeDatabase(
        tables: ['android_metadata', 'people', 'sqlite_sequence'],
        rows: {'people': people},
      );
      final source = DbSource(query: fake.query);
      expect(await source.tableNames(), ['people']);
    });

    test('keeps them when asked to', () async {
      final fake = FakeDatabase(
        tables: ['android_metadata', 'people'],
        rows: {'people': people},
      );
      final source = DbSource(query: fake.query, includeInternalTables: true);
      expect(await source.tableNames(), ['android_metadata', 'people']);
    });
  });

  group('readTable', () {
    test('reads every row when unbounded', () async {
      final fake = FakeDatabase(tables: ['people'], rows: {'people': people});
      final data = await DbSource(query: fake.query).readTable('people');

      expect(data.name, 'people');
      expect(data.columns, ['id', 'name']);
      expect(data.rowCount, 3);
      expect(data.truncated, isFalse);
    });

    test('flags truncation and trims to the limit', () async {
      final fake = FakeDatabase(tables: ['people'], rows: {'people': people});
      final data = await DbSource(query: fake.query)
          .readTable('people', maxRows: 2);

      expect(data.rowCount, 2);
      expect(data.truncated, isTrue);
    });

    test('does not flag truncation when the table just fits', () async {
      final fake = FakeDatabase(tables: ['people'], rows: {'people': people});
      final data = await DbSource(query: fake.query)
          .readTable('people', maxRows: 3);

      expect(data.rowCount, 3);
      expect(data.truncated, isFalse);
    });

    test('rejects an unknown table', () async {
      final fake = FakeDatabase(tables: ['people'], rows: {'people': people});
      await expectLater(
        DbSource(query: fake.query).readTable('ghosts'),
        throwsA(isA<DbExportException>()),
      );
    });
  });

  group('checkpointWal', () {
    test('reports success when SQLite is not busy', () async {
      final fake = FakeDatabase(tables: const [], rows: const {});
      expect(await DbSource(query: fake.query).checkpointWal(), isTrue);
      expect(fake.executed.single, 'PRAGMA wal_checkpoint(TRUNCATE)');
    });

    test('reports failure when readers blocked the checkpoint', () async {
      final fake = FakeDatabase(tables: const [], rows: const {}, walBusy: 1);
      expect(await DbSource(query: fake.query).checkpointWal(), isFalse);
    });

    test('swallows errors rather than aborting the export', () async {
      final fake = FakeDatabase(
        tables: const [],
        rows: const {},
        failCheckpoint: true,
      );
      expect(await DbSource(query: fake.query).checkpointWal(), isFalse);
    });
  });

  group('identifier quoting', () {
    test('escapes embedded double quotes', () {
      expect(DbSource.quoteIdentifier('we"ird'), '"we""ird"');
    });

    test('is applied to table reads', () async {
      final fake = FakeDatabase(
        tables: ['order'],
        rows: {'order': [{'id': 1}]},
      );
      await DbSource(query: fake.query).readTable('order');
      expect(fake.executed, contains('SELECT * FROM "order"'));
    });
  });

  group('run', () {
    test('prefers the execute callback when provided', () async {
      final fake = FakeDatabase(tables: const [], rows: const {});
      final executed = <String>[];
      final source = DbSource(
        query: fake.query,
        execute: (sql) async => executed.add(sql),
      );

      await source.run('VACUUM');
      expect(executed, ['VACUUM']);
      expect(fake.executed, isEmpty);
    });

    test('falls back to the query callback', () async {
      final fake = FakeDatabase(tables: const [], rows: const {});
      await DbSource(query: fake.query).run('VACUUM');
      expect(fake.executed, ['VACUUM']);
    });
  });
}
