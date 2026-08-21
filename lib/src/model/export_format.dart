/// The on-disk shape an export is written in.
enum ExportFormat {
  /// A byte-for-byte copy of the SQLite file itself.
  ///
  /// This is the only format that round-trips: the result can be handed back to
  /// Drift/sqflite as-is. Requires `SqlSource.databasePath` to be known.
  rawDatabase,

  /// One `.csv` file per table, RFC 4180 quoted, UTF-8 with BOM.
  ///
  /// Produces N files for N tables — see `ExportResult.files`.
  csv,

  /// A single `.json` file: `{"table": [{"col": value}, ...], ...}`.
  json,

  /// A single `.xlsx` workbook with one sheet per table.
  excel;

  String get fileExtension => switch (this) {
        ExportFormat.rawDatabase => 'db',
        ExportFormat.csv => 'csv',
        ExportFormat.json => 'json',
        ExportFormat.excel => 'xlsx',
      };

  String get mimeType => switch (this) {
        ExportFormat.rawDatabase => 'application/vnd.sqlite3',
        ExportFormat.csv => 'text/csv',
        ExportFormat.json => 'application/json',
        ExportFormat.excel =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      };

  /// Whether this format can emit more than one file for a multi-table export.
  bool get isMultiFile => this == ExportFormat.csv;
}
