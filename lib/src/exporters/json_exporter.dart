import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/export_format.dart';
import '../model/export_result.dart';
import '../model/table_data.dart';
import '../util/file_naming.dart';
import '../util/value_codec.dart';
import 'tabular_exporter.dart';

/// A single JSON document keyed by table name.
///
/// ```json
/// {
///   "_meta": { "exportedAt": "...", "tables": ["users"] },
///   "users": [ { "id": 1, "name": "Ada" } ]
/// }
/// ```
class JsonExporter implements TabularExporter {
  const JsonExporter({this.pretty = true, this.includeMetadata = true});

  final bool pretty;

  /// Adds a `_meta` block with the export time and row counts.
  final bool includeMetadata;

  @override
  ExportFormat get format => ExportFormat.json;

  @override
  Future<List<ExportedFile>> write({
    required List<TableData> tables,
    required Directory stagingDirectory,
    required String baseName,
  }) async {
    final document = <String, Object?>{
      if (includeMetadata)
        '_meta': <String, Object?>{
          'exportedAt': DateTime.now().toIso8601String(),
          'tables': <String, Object?>{
            for (final table in tables)
              table.name: <String, Object?>{
                'rows': table.rowCount,
                'columns': table.columns,
                if (table.truncated) 'truncated': true,
              },
          },
        },
      for (final table in tables)
        table.name: [
          for (final row in table.rows)
            <String, Object?>{
              for (final column in table.columns)
                column: ValueCodec.asJson(row[column]),
            },
        ],
    };

    final encoder = pretty
        ? const JsonEncoder.withIndent('  ')
        : const JsonEncoder();

    final file = File(
      p.join(
        stagingDirectory.path,
        FileNaming.build(
          base: baseName,
          extension: format.fileExtension,
          withTimestamp: false,
        ),
      ),
    );
    await file.writeAsString(
      encoder.convert(document),
      encoding: utf8,
      flush: true,
    );
    return [await ExportedFile.fromFile(file)];
  }
}
