import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/export_format.dart';
import '../model/export_result.dart';
import '../model/table_data.dart';
import '../util/csv_writer.dart';
import '../util/file_naming.dart';
import '../util/value_codec.dart';
import 'tabular_exporter.dart';

/// One `.csv` per table.
class CsvExporter implements TabularExporter {
  const CsvExporter({
    this.delimiter = ',',
    this.includeBom = true,
    this.includeHeader = true,
    this.sanitizeFormulas = true,
  });

  /// Use `;` for locales where Excel expects a semicolon.
  final String delimiter;

  /// Prepend a UTF-8 BOM so Excel does not mangle non-ASCII text.
  final bool includeBom;

  /// Write the column names as the first row.
  final bool includeHeader;

  /// Neutralise leading `=`, `+`, `-` and `@` so spreadsheets do not execute
  /// cell contents as formulas. See [CsvWriter.neutralizeFormula].
  final bool sanitizeFormulas;

  @override
  ExportFormat get format => ExportFormat.csv;

  @override
  Future<List<ExportedFile>> write({
    required List<TableData> tables,
    required Directory stagingDirectory,
    required String baseName,
  }) async {
    final files = <ExportedFile>[];
    for (final table in tables) {
      final rows = <List<String>>[
        if (includeHeader) table.columns,
        for (final row in table.rows)
          [
            for (final column in table.columns)
              ValueCodec.asText(row[column]),
          ],
      ];

      final name = FileNaming.build(
        base: baseName,
        suffix: table.name,
        extension: format.fileExtension,
        withTimestamp: false,
      );
      final file = File(p.join(stagingDirectory.path, name));
      await file.writeAsString(
        CsvWriter.encode(
          rows,
          delimiter: delimiter,
          includeBom: includeBom,
          sanitizeFormulas: sanitizeFormulas,
        ),
        encoding: utf8,
        flush: true,
      );
      files.add(await ExportedFile.fromFile(file, table: table.name));
    }
    return files;
  }
}
