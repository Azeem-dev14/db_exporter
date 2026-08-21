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
import 'source/db_source.dart';
import 'util/file_naming.dart';

/// Progress callback, emitted once per table plus once when writing finishes.
typedef ExportProgress = void Function(int completed, int total, String? table);

/// Exports a SQLite-backed database to a file and delivers it somewhere.
///
/// The database and the destination are fixed when you build the exporter, so
/// every export method takes the same arguments and differs only in format:
///
/// ```dart
/// final exporter = DbExporter(
///   DbSource(databasePath: db.path, query: db.rawQuery, execute: db.execute),
///   destination: const ExportDestination.share(),
/// );
///
/// await exporter.exportExcel();
/// await exporter.exportCsv(tables: ['orders']);
/// await exporter.export(format: chosenFormat);
/// ```
///
/// Per-format settings — the CSV delimiter, JSON indentation, the raw-copy
/// strategy — live on the exporter objects passed here, keeping them out of
/// the call sites.
class DbExporter {
  const DbExporter(
    this.source, {
    this.destination = const ExportDestination.deviceFolder(),
    this.fileName,
    this.timestampFileNames = true,
    this.csv = const CsvExporter(),
    this.json = const JsonExporter(),
    this.excel = const ExcelExporter(),
    this.rawDatabase = const RawDatabaseExporter(),
  });

  /// The database to read from.
  final DbSource source;

  /// Where finished files are delivered, unless an export overrides it.
  final ExportDestination destination;

  /// Base filename; defaults to the database filename, then to `export`.
  final String? fileName;

  /// Append `_<yyyyMMdd_HHmmss>` to filenames.
  final bool timestampFileNames;

  /// CSV settings — delimiter, BOM, header row, formula sanitisation.
  final CsvExporter csv;

  /// JSON settings — indentation and the `_meta` block.
  final JsonExporter json;

  /// Excel settings — bold header and column auto-fit.
  final ExcelExporter excel;

  /// Raw `.db` settings — copy strategy and WAL sidecars.
  final RawDatabaseExporter rawDatabase;

  /// Copies the database file itself. Best for backups and support bundles.
  ///
  /// [tables], [excludeTables] and [maxRowsPerTable] do not apply to a file
  /// copy and are ignored; they are accepted so every export method shares one
  /// signature.
  Future<ExportResult> exportDatabaseFile({
    List<String>? tables,
    List<String>? excludeTables,
    String? fileName,
    int? maxRowsPerTable,
    ExportDestination? destination,
    ExportProgress? onProgress,
  }) =>
      export(
        format: ExportFormat.rawDatabase,
        tables: tables,
        excludeTables: excludeTables,
        fileName: fileName,
        maxRowsPerTable: maxRowsPerTable,
        destination: destination,
        onProgress: onProgress,
      );

  /// One CSV per table. Produces multiple files — see [ExportResult.files].
  Future<ExportResult> exportCsv({
    List<String>? tables,
    List<String>? excludeTables,
    String? fileName,
    int? maxRowsPerTable,
    ExportDestination? destination,
    ExportProgress? onProgress,
  }) =>
      export(
        format: ExportFormat.csv,
        tables: tables,
        excludeTables: excludeTables,
        fileName: fileName,
        maxRowsPerTable: maxRowsPerTable,
        destination: destination,
        onProgress: onProgress,
      );

  /// A single JSON document keyed by table name.
  Future<ExportResult> exportJson({
    List<String>? tables,
    List<String>? excludeTables,
    String? fileName,
    int? maxRowsPerTable,
    ExportDestination? destination,
    ExportProgress? onProgress,
  }) =>
      export(
        format: ExportFormat.json,
        tables: tables,
        excludeTables: excludeTables,
        fileName: fileName,
        maxRowsPerTable: maxRowsPerTable,
        destination: destination,
        onProgress: onProgress,
      );

  /// A single `.xlsx` workbook, one sheet per table.
  Future<ExportResult> exportExcel({
    List<String>? tables,
    List<String>? excludeTables,
    String? fileName,
    int? maxRowsPerTable,
    ExportDestination? destination,
    ExportProgress? onProgress,
  }) =>
      export(
        format: ExportFormat.excel,
        tables: tables,
        excludeTables: excludeTables,
        fileName: fileName,
        maxRowsPerTable: maxRowsPerTable,
        destination: destination,
        onProgress: onProgress,
      );

  /// The general form, for picking a format at runtime.
  ///
  /// [tables] restricts the export to a whitelist; [excludeTables] removes
  /// tables from whatever remains. Passing neither exports every user table.
  /// [destination] overrides the exporter's own for this call only.
  Future<ExportResult> export({
    required ExportFormat format,
    List<String>? tables,
    List<String>? excludeTables,
    String? fileName,
    int? maxRowsPerTable,
    ExportDestination? destination,
    ExportProgress? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final target = destination ?? this.destination;
    final staging = await Directory.systemTemp.createTemp('db_exporter_');
    final baseName = _resolveBaseName(fileName);

    try {
      if (format == ExportFormat.rawDatabase) {
        final files = await rawDatabase.write(
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
          destination: target,
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

      final files = await _exporterFor(format).write(
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
        destination: target,
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

  TabularExporter _exporterFor(ExportFormat format) => switch (format) {
        ExportFormat.csv => csv,
        ExportFormat.json => json,
        ExportFormat.excel => excel,
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

  /// Resolves the filename stem: call argument, then [fileName], then the
  /// database filename, then a literal `export`.
  String _resolveBaseName(String? explicit) {
    final stem = _stem(explicit);
    return timestampFileNames ? '${stem}_${FileNaming.timestamp()}' : stem;
  }

  String _stem(String? explicit) {
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final fallback = fileName;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    final path = source.databasePath;
    if (path == null) return 'export';
    final name = p.basenameWithoutExtension(path);
    return name.isEmpty ? 'export' : name;
  }
}
