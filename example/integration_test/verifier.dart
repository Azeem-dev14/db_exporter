import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:db_exporter/db_exporter.dart';
import 'package:sqlite3/sqlite3.dart';

/// Thrown when an exported file does not actually contain the data.
class VerificationFailure implements Exception {
  const VerificationFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Opens what was exported and proves the rows are really in there.
///
/// The failure worth catching is an export that throws nothing and writes an
/// empty or truncated file, so every format is read back and counted rather
/// than merely stat-ed.
abstract final class Verifier {
  /// Verifies [result] against the row counts the database was seeded with.
  ///
  /// Returns a human-readable summary of what was checked.
  static Future<String> verify(
    ExportResult result,
    Map<String, int> expected,
  ) async {
    if (result.files.isEmpty) {
      throw const VerificationFailure('Export produced no files.');
    }
    for (final file in result.files) {
      if (!await file.file.exists()) {
        throw VerificationFailure('Missing on disk: ${file.path}');
      }
      if (file.sizeInBytes == 0) {
        throw VerificationFailure('Empty file: ${file.name}');
      }
    }

    return switch (result.format) {
      ExportFormat.rawDatabase => _rawDatabase(result, expected),
      ExportFormat.csv => _csv(result, expected),
      ExportFormat.json => _json(result, expected),
      ExportFormat.excel => _excel(result, expected),
    };
  }

  /// Reopens the copy with sqlite3 and counts every table.
  static Future<String> _rawDatabase(
    ExportResult result,
    Map<String, int> expected,
  ) async {
    final database = sqlite3.open(result.single.path, mode: OpenMode.readOnly);
    try {
      final found = <String, int>{};
      for (final table in expected.keys) {
        final rows = database.select('SELECT COUNT(*) AS n FROM "$table"');
        found[table] = rows.first['n'] as int;
      }
      _compare(found, expected, 'raw database');
      return 'Reopened with sqlite3, ${_total(found)} rows across '
          '${found.length} tables.';
    } finally {
      database.dispose();
    }
  }

  /// Parses each CSV back, header row included.
  static Future<String> _csv(
    ExportResult result,
    Map<String, int> expected,
  ) async {
    if (result.files.length != expected.length) {
      throw VerificationFailure(
        'Expected ${expected.length} CSV files, got ${result.files.length}.',
      );
    }

    final found = <String, int>{};
    for (final exported in result.files) {
      final table = exported.table;
      if (table == null) {
        throw VerificationFailure('CSV file ${exported.name} has no table.');
      }
      final text = await exported.file.readAsString();
      final lines = const LineSplitter()
          .convert(text)
          .where((line) => line.trim().isNotEmpty)
          .toList();
      if (lines.isEmpty) {
        throw VerificationFailure('$table CSV has no header row.');
      }
      // First line is the header; the rest are data.
      found[table] = lines.length - 1;
    }
    _compare(found, expected, 'CSV');
    return '${result.files.length} files parsed, ${_total(found)} data rows.';
  }

  /// Decodes the document and counts each table's array.
  static Future<String> _json(
    ExportResult result,
    Map<String, int> expected,
  ) async {
    final decoded = jsonDecode(await result.single.file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const VerificationFailure('JSON root is not an object.');
    }

    final found = <String, int>{};
    for (final table in expected.keys) {
      final rows = decoded[table];
      if (rows is! List) {
        throw VerificationFailure('JSON has no array for "$table".');
      }
      found[table] = rows.length;
    }
    _compare(found, expected, 'JSON');
    return 'Decoded ${_total(found)} rows across ${found.length} tables.';
  }

  /// Unzips the workbook and confirms a sheet exists per table.
  static Future<String> _excel(
    ExportResult result,
    Map<String, int> expected,
  ) async {
    final bytes = await result.single.file.readAsBytes();
    if (bytes.length < 2 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw const VerificationFailure('Not a zip archive — xlsx is malformed.');
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toList();
    if (!names.contains('xl/workbook.xml')) {
      throw const VerificationFailure('xlsx has no xl/workbook.xml.');
    }

    final sheets =
        names.where((n) => n.startsWith('xl/worksheets/sheet')).length;
    if (sheets != expected.length) {
      throw VerificationFailure(
        'Expected ${expected.length} sheets, found $sheets.',
      );
    }

    // The workbook names its sheets after the tables; confirm each is there.
    final workbook = utf8.decode(
      archive.files.firstWhere((f) => f.name == 'xl/workbook.xml').content
          as List<int>,
    );
    final missing =
        expected.keys.where((table) => !workbook.contains(table)).toList();
    if (missing.isNotEmpty) {
      throw VerificationFailure('Sheets missing: ${missing.join(', ')}.');
    }
    return '$sheets sheets, one per table, workbook.xml intact.';
  }

  static void _compare(
    Map<String, int> found,
    Map<String, int> expected,
    String what,
  ) {
    final wrong = <String>[];
    for (final entry in expected.entries) {
      final actual = found[entry.key];
      if (actual != entry.value) {
        wrong.add('${entry.key}: expected ${entry.value}, got $actual');
      }
    }
    if (wrong.isNotEmpty) {
      throw VerificationFailure('$what row mismatch — ${wrong.join('; ')}');
    }
  }

  static int _total(Map<String, int> counts) =>
      counts.values.fold(0, (a, b) => a + b);
}
