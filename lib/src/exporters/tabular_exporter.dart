import 'dart:io';

import '../model/export_format.dart';
import '../model/export_result.dart';
import '../model/table_data.dart';

/// Writes already-read tables into a concrete file format.
///
/// Implementations write into a staging directory and never touch the final
/// destination — delivery is a separate concern, so formats and destinations
/// compose freely.
///
/// Implement this to add a format of your own (a SQL dump, Parquet, a zipped
/// bundle) and pass it wherever a [TabularExporter] is accepted.
abstract interface class TabularExporter {
  /// The format this exporter produces.
  ExportFormat get format;

  /// Writes [tables] into [stagingDirectory], returning the files created.
  Future<List<ExportedFile>> write({
    required List<TableData> tables,
    required Directory stagingDirectory,
    required String baseName,
  });
}
