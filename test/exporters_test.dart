import 'dart:convert';
import 'dart:io';

import 'package:db_exporter/db_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory staging;

  setUp(() async {
    staging = await Directory.systemTemp.createTemp('db_exporter_test_');
  });

  tearDown(() async {
    if (staging.existsSync()) await staging.delete(recursive: true);
  });

  final people = TableData(
    name: 'people',
    columns: const ['id', 'name'],
    rows: const [
      {'id': 1, 'name': 'Ada'},
      {'id': 2, 'name': 'Grace, "the Amazing"'},
    ],
  );

  final projects = TableData(
    name: 'projects',
    columns: const ['id', 'title'],
    rows: const [
      {'id': 1, 'title': 'Analytical Engine'},
    ],
  );

  group('CsvExporter', () {
    test('writes one file per table, named after the table', () async {
      final files = await const CsvExporter().write(
        tables: [people, projects],
        stagingDirectory: staging,
        baseName: 'app_20260822_143001',
      );

      expect(files, hasLength(2));
      expect(files.map((f) => f.table), ['people', 'projects']);
      expect(files.first.name, 'app_20260822_143001_people.csv');
    });

    test('quotes and escapes cell contents', () async {
      final files = await const CsvExporter(includeBom: false).write(
        tables: [people],
        stagingDirectory: staging,
        baseName: 'app',
      );

      final csv = await files.single.file.readAsString();
      expect(csv, startsWith('id,name\r\n'));
      expect(csv, contains('"Grace, ""the Amazing"""'));
    });

    test('reports a non-zero size for what it wrote', () async {
      final files = await const CsvExporter().write(
        tables: [people],
        stagingDirectory: staging,
        baseName: 'app',
      );
      expect(files.single.sizeInBytes, greaterThan(0));
    });
  });

  group('JsonExporter', () {
    test('keys rows by table and preserves value types', () async {
      final files = await const JsonExporter().write(
        tables: [people, projects],
        stagingDirectory: staging,
        baseName: 'app',
      );

      final decoded = jsonDecode(await files.single.file.readAsString())
          as Map<String, Object?>;

      expect(decoded.keys, containsAll(['people', 'projects']));
      final rows = decoded['people']! as List<Object?>;
      expect(rows, hasLength(2));
      // Numbers must survive as numbers, not stringified.
      expect((rows.first! as Map<String, Object?>)['id'], 1);
    });

    test('records row counts in the metadata block', () async {
      final files = await const JsonExporter().write(
        tables: [people],
        stagingDirectory: staging,
        baseName: 'app',
      );

      final decoded = jsonDecode(await files.single.file.readAsString())
          as Map<String, Object?>;
      final meta = decoded['_meta']! as Map<String, Object?>;
      final tables = meta['tables']! as Map<String, Object?>;
      final entry = tables['people']! as Map<String, Object?>;

      expect(entry['rows'], 2);
    });

    test('can omit the metadata block', () async {
      final files = await const JsonExporter(includeMetadata: false).write(
        tables: [people],
        stagingDirectory: staging,
        baseName: 'app',
      );

      final decoded = jsonDecode(await files.single.file.readAsString())
          as Map<String, Object?>;
      expect(decoded.containsKey('_meta'), isFalse);
    });
  });

  group('ExcelExporter', () {
    test('writes a single non-empty workbook', () async {
      final files = await const ExcelExporter().write(
        tables: [people, projects],
        stagingDirectory: staging,
        baseName: 'app',
      );

      expect(files, hasLength(1));
      expect(files.single.name, endsWith('.xlsx'));
      // xlsx is a zip archive; check the magic bytes rather than the contents.
      final bytes = await files.single.file.readAsBytes();
      expect(bytes.take(2), [0x50, 0x4B]);
    });
  });
}
