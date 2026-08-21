import 'dart:io';

import 'package:path/path.dart' as p;

import 'delivery/export_delivery.dart';
import 'exporters/csv_exporter.dart';
import 'exporters/excel_exporter.dart';
import 'exporters/json_exporter.dart';
import 'exporters/raw_database_exporter.dart';
import 'exporters/tabular_exporter.dart';
import 'model/export_destination.dart';
import 'model/export_exception.dart';
import 'model/export_format.dart';
import 'model/export_result.dart';
import 'model/table_data.dart';
import 'source/sql_source.dart';
import 'util/file_naming.dart';

/// Progress callback, emitted once per table plus once when writing finishes.
typedef ExportProgress = void Function(int completed, int total, String? table);

/// Exports a SQLite-backed database to a file and delivers it somewhere.
///
/// ```dart
/// final exporter = DbExporter(
///   SqlSource(databasePath: db.path, query: db.rawQuery),
/// );
///
/// final result = await exporter.exportExcel(
///   destination: const ExportDestination.share(subject: 'My data'),
/// );
/// ```
class DbExporter {
  const DbExporter(
    this.source, {
    this.defaultBaseName,
  });

  final SqlSource source;

  /// Base filename for exports; defaults to the database filename, then to
  /// `export`.
  final String? defaultBaseName;

  /// Copies the database file itself. Best for backups and support bundles.
  Future<ExportResult> exportDatabaseFile({
    ExportDestination destination = const ExportDestination.appDirectory(),
    RawCopyStrategy strategy = RawCopyStrategy.vacuumInto,
    bool includeWalFiles = false,
    String? fileName,
    bool timestampFileNames = true,
  }) =>
      export(
        format: ExportFormat.rawDatabase,
        destination: destination,
        fileName: fileName,
        rawStrategy: strategy,
        includeWalFiles: includeWalFiles,
        timestampFileNames: timestampFileNames,
      );

  /// One CSV per table. Produces multiple files — see [ExportResult.files].
  Future<ExportResult> exportCsv({
    ExportDestination destination = const ExportDestination.appDirectory(),
    List<String>? tables,
    List<String>? excludeTables,
    String? fileName,
    int? maxRowsPerTable,
    String delimiter = ',',
    bool sanitizeFormulas = true,
    ExportProgress? onProgress,
  }) =>
      export(
        format: ExportFormat.csv,
        destination: destination,
        tables: tables,
        excludeTables: excludeTables,
        fileName: fileName,
        maxRowsPerTable: maxRowsPerTable,
        csvDelimiter: delimiter,
        csvSanitizeFormulas: sanitizeFormulas,
        onProgress: onProgress,
      );

  /// A single JSON document keyed by table name.
  Future<ExportResult> exportJson({
    ExportDestination destination = const ExportDestination.appDirectory(),
    List<String>? tables,
    List<String>? excludeTables,
    String? fileName,
    int? maxRowsPerTable,
    bool pretty = true,
    ExportProgress? onProgress,
  }) =>
      export(
        format: ExportFormat.json,
        destination: destination,
        tables: tables,
        excludeTables: excludeTables,
        fileName: fileName,
        maxRowsPerTable: maxRowsPerTable,
        prettyJson: pretty,
        onProgress: onProgress,
      );

  /// A single `.xlsx` workbook, one sheet per table.
  Future<ExportResult> exportExcel({
    ExportDestination destination = const ExportDestination.appDirectory(),
    List<String>? tables,
    List<String>? excludeTables,
    String? fileName,
    int? maxRowsPerTable,
    ExportProgress? onProgress,
  }) =>
      export(
        format: ExportFormat.excel,
        destination: destination,
        tables: tables,
        excludeTables: excludeTables,
        fileName: fileName,
        maxRowsPerTable: maxRowsPerTable,
        onProgress: onProgress,
      );

  /// The general form the convenience methods delegate to.
  ///
  /// [tables] restricts the export to a whitelist; [excludeTables] removes
  /// tables from whatever remains. Passing neither exports every user table.
  Future<ExportResult> export({
    required ExportFormat format,
    ExportDestination destination = const ExportDestination.appDirectory(),
    List<String>? tables,
    List<String>? excludeTables,
    String? fileName,
    int? maxRowsPerTable,
    String csvDelimiter = ',',
    bool csvSanitizeFormulas = true,
    bool prettyJson = true,
    RawCopyStrategy rawStrategy = RawCopyStrategy.vacuumInto,
    bool includeWalFiles = false,
    bool timestampFileNames = true,
    ExportProgress? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final staging = await Directory.systemTemp.createTemp('db_exporter_');
    final baseName = _resolveBaseName(
      fileName,
      timestamped: timestampFileNames,
    );

    try {
      if (format == ExportFormat.rawDatabase) {
        final files = await RawDatabaseExporter(
          strategy: rawStrategy,
          includeWalFiles: includeWalFiles,
        ).write(
          source: source,
          stagingDirectory: staging,
          baseName: baseName,
        );
        onProgress?.call(1, 1, null);
        // Explicit await: the finally block below deletes the staging
        // directory, and delivery still needs to read from it.
        return await _finish(
          format: format,
          files: files,
          tables: const [],
          totalRows: 0,
          destination: destination,
          stopwatch: stopwatch,
        );
      }

      final selected = await _selectTables(tables, excludeTables);
      if (selected.isEmpty) {
        throw const DbExportException(
          'No tables to export. The database is empty, or the tables/'
          'excludeTables filters removed everything.',
        );
      }

      final data = <TableData>[];
      var totalRows = 0;
      for (var index = 0; index < selected.length; index++) {
        final table = selected[index];
        onProgress?.call(index, selected.length, table);
        final read = await source.readTable(table, maxRows: maxRowsPerTable);
        totalRows += read.rowCount;
        data.add(read);
      }

      final files = await _exporterFor(
        format,
        csvDelimiter: csvDelimiter,
        csvSanitizeFormulas: csvSanitizeFormulas,
        prettyJson: prettyJson,
      ).write(
        tables: data,
        stagingDirectory: staging,
        baseName: baseName,
      );
      onProgress?.call(selected.length, selected.length, null);

      // Explicit await — see the note above.
      return await _finish(
        format: format,
        files: files,
        tables: selected,
        totalRows: totalRows,
        destination: destination,
        stopwatch: stopwatch,
      );
    } finally {
      // Delivery has either moved the files out or copied their bytes by now,
      // so whatever remains in staging is disposable. Best-effort: a failure
      // here must not mask the export result, and the OS reclaims temp anyway.
      try {
        await staging.delete(recursive: true);
      } on FileSystemException {
        // Ignored deliberately.
      }
    }
  }

  Future<ExportResult> _finish({
    required ExportFormat format,
    required List<ExportedFile> files,
    required List<String> tables,
    required int totalRows,
    required ExportDestination destination,
    required Stopwatch stopwatch,
  }) async {
    final outcome = await ExportDelivery.deliver(
      files: files,
      destination: destination,
      format: format,
    );
    stopwatch.stop();
    return ExportResult(
      format: format,
      files: outcome.files,
      tables: tables,
      totalRows: totalRows,
      duration: stopwatch.elapsed,
      deliveredPath: outcome.path,
      userCancelled: outcome.cancelled,
    );
  }

  TabularExporter _exporterFor(
    ExportFormat format, {
    required String csvDelimiter,
    required bool csvSanitizeFormulas,
    required bool prettyJson,
  }) =>
      switch (format) {
        ExportFormat.csv => CsvExporter(
            delimiter: csvDelimiter,
            sanitizeFormulas: csvSanitizeFormulas,
          ),
        ExportFormat.json => JsonExporter(pretty: prettyJson),
        ExportFormat.excel => const ExcelExporter(),
        ExportFormat.rawDatabase => throw StateError(
            'rawDatabase is handled by RawDatabaseExporter, not here.',
          ),
      };

  Future<List<String>> _selectTables(
    List<String>? include,
    List<String>? exclude,
  ) async {
    final available = await source.tableNames();
    final excluded = exclude?.toSet() ?? const <String>{};

    if (include == null) {
      return available.where((t) => !excluded.contains(t)).toList();
    }

    final missing = include.where((t) => !available.contains(t)).toList();
    if (missing.isNotEmpty) {
      throw DbExportException(
        'Unknown table(s): ${missing.join(', ')}. '
        'Available: ${available.join(', ')}.',
      );
    }
    return include.where((t) => !excluded.contains(t)).toList();
  }

  /// Resolves the filename stem: explicit argument, then [defaultBaseName],
  /// then the database filename, then a literal `export`.
  String _resolveBaseName(String? explicit, {required bool timestamped}) {
    final stem = _stem(explicit);
    return timestamped ? '${stem}_${FileNaming.timestamp()}' : stem;
  }

  String _stem(String? explicit) {
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final fallback = defaultBaseName;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    final path = source.databasePath;
    if (path == null) return 'export';
    final name = p.basenameWithoutExtension(path);
    return name.isEmpty ? 'export' : name;
  }
}
