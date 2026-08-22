import 'package:db_exporter/db_exporter.dart';
import 'package:db_exporter_example/databases/all.dart';
import 'package:db_exporter_example/demo_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'verifier.dart';

/// Rows each demo database seeds. Exports are checked against these, so a
/// truncated or empty file fails rather than silently passing.
const _expectedRows = <String, Map<String, int>>{
  'sqflite': {'schools': 4, 'teachers': 6},
  'sqlite3': {'books': 5, 'orders': 4},
  'drift': {'artists': 4, 'albums': 5, 'tracks': 6},
};

/// Destinations that complete without a human tapping anything.
///
/// `share()` and `saveAs()` open system UI and block until dismissed, so they
/// cannot run unattended — the example app covers those by hand.
const _destinations = <String, ExportDestination>{
  'appDirectory': ExportDestination.appDirectory(),
  'appCache': ExportDestination.appDirectory(temporary: true),
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final database in buildDemoDatabases()) {
    group('${database.package} (${database.dataset})', () {
      setUpAll(() async => database.open());
      tearDownAll(() async => database.close());

      final expected = _expectedRows[database.package]!;

      for (final format in ExportFormat.values) {
        for (final entry in _destinations.entries) {
          test('${format.name} -> ${entry.key}', () async {
            final exporter = DbExporter(
              database.source,
              destination: entry.value,
            );

            final result = await exporter.export(format: format);

            expect(result.userCancelled, isFalse);
            expect(result.files, isNotEmpty);
            expect(result.deliveredPath, isNotNull);

            // The point of the suite: read the file back and count rows.
            final summary = await Verifier.verify(result, expected);
            expect(summary, isNotEmpty);
          });
        }
      }

      test('table filtering exports only what was asked for', () async {
        final only = expected.keys.first;
        final exporter = DbExporter(
          database.source,
          destination: const ExportDestination.appDirectory(),
        );

        final result = await exporter.exportJson(tables: [only]);

        expect(result.tables, [only]);
        expect(result.totalRows, expected[only]);
      });

      test('excludeTables drops the table', () async {
        final dropped = expected.keys.first;
        final exporter = DbExporter(
          database.source,
          destination: const ExportDestination.appDirectory(),
        );

        final result = await exporter.exportJson(excludeTables: [dropped]);

        expect(result.tables, isNot(contains(dropped)));
      });

      test('maxRowsPerTable caps each table', () async {
        final exporter = DbExporter(
          database.source,
          destination: const ExportDestination.appDirectory(),
        );

        final result = await exporter.exportJson(maxRowsPerTable: 2);

        expect(result.totalRows, lessThanOrEqualTo(2 * expected.length));
      });

      test('onProgress reports every table', () async {
        final seen = <String>[];
        final exporter = DbExporter(
          database.source,
          destination: const ExportDestination.appDirectory(),
        );

        await exporter.exportCsv(
          onProgress: (done, total, table) {
            if (table != null) seen.add(table);
          },
        );

        expect(seen.toSet(), expected.keys.toSet());
      });

      test('an unknown table name is rejected', () async {
        final exporter = DbExporter(database.source);
        await expectLater(
          exporter.exportCsv(tables: const ['no_such_table']),
          throwsA(isA<DbExportException>()),
        );
      });

      test('the raw copy reopens and matches the source', () async {
        final exporter = DbExporter(
          database.source,
          destination: const ExportDestination.appDirectory(),
        );

        final result = await exporter.exportDatabaseFile();

        expect(result.format, ExportFormat.rawDatabase);
        expect(result.files, hasLength(1));
        await Verifier.verify(result, expected);
      });
    });
  }

  group('cross-cutting', () {
    late DemoDatabase database;

    setUpAll(() async {
      database = buildDemoDatabases().first;
      await database.open();
    });
    tearDownAll(() async => database.close());

    test('CSV writes one file per table, other formats write one', () async {
      final exporter = DbExporter(
        database.source,
        destination: const ExportDestination.appDirectory(),
      );

      final csv = await exporter.exportCsv();
      final json = await exporter.exportJson();

      expect(csv.files.length, greaterThan(1));
      expect(json.files, hasLength(1));
      expect(ExportFormat.csv.isMultiFile, isTrue);
      expect(ExportFormat.json.isMultiFile, isFalse);
    });

    test('filenames carry a timestamp, and can be told not to', () async {
      final stamped = DbExporter(
        database.source,
        destination: const ExportDestination.appDirectory(),
      );
      final plain = DbExporter(
        database.source,
        destination: const ExportDestination.appDirectory(),
        fileName: 'fixed',
        timestampFileNames: false,
      );

      expect(
        (await stamped.exportJson()).single.name,
        matches(RegExp(r'_\d{8}_\d{6}\.json$')),
      );
      expect((await plain.exportJson()).single.name, 'fixed.json');
    });

    test('a directory destination is created when missing', () async {
      final exporter = DbExporter(database.source);
      final result = await exporter.exportJson(
        destination: const ExportDestination.directory(
          '/tmp/db_exporter_integration',
        ),
      );

      expect(result.deliveredPath, '/tmp/db_exporter_integration');
    });
  });
}
