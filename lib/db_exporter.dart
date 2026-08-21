/// WAL-safe export of SQLite-backed Flutter databases.
///
/// Point a [SqlSource] at any SQLite connection — Drift, sqflite or raw
/// `sqlite3` — pick a format, pick a destination:
///
/// ```dart
/// final exporter = DbExporter(
///   SqlSource(databasePath: db.path, query: db.rawQuery),
/// );
///
/// await exporter.exportDatabaseFile(
///   destination: const ExportDestination.share(subject: 'Backup'),
/// );
/// ```
library;

export 'src/db_exporter_base.dart' show DbExporter, ExportProgress;
export 'src/exporters/csv_exporter.dart' show CsvExporter;
export 'src/exporters/excel_exporter.dart' show ExcelExporter;
export 'src/exporters/json_exporter.dart' show JsonExporter;
export 'src/exporters/raw_database_exporter.dart'
    show RawCopyStrategy, RawDatabaseExporter;
export 'src/exporters/tabular_exporter.dart' show TabularExporter;
export 'src/model/export_destination.dart';
export 'src/model/export_exception.dart' show DbExportException;
export 'src/model/export_format.dart' show ExportFormat;
export 'src/model/export_result.dart' show ExportResult, ExportedFile;
export 'src/model/table_data.dart' show TableData;
export 'src/source/sql_source.dart' show RawExecute, RawQuery, SqlSource;
export 'src/util/csv_writer.dart' show CsvWriter;
export 'src/util/value_codec.dart' show ValueCodec;
