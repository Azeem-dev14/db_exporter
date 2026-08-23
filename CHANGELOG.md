## 0.2.0

### Changed

- Raised the floors on `file_picker` (^12.0.0), `share_plus` (^13.3.0) and
  `package_info_plus` (^10.2.1) so the package resolves against the current
  releases rather than holding consumers back a major version.
- **Breaking, Android only.** `ExportDestination.saveAs()` now reports the
  Storage Access Framework `content://` URI that `file_picker` 12 returns,
  where it previously reported a filesystem path. `ExportResult.path` is still
  a `String`, but on Android it is no longer openable with `File(path)` —
  hand it to a content resolver instead. iOS still reports a `file:` path.
  Every other destination is unaffected.
- The save dialog now receives the export's MIME type, so Android files apps
  suggest the right handler for a `.db`, `.csv`, `.json` or `.xlsx`.

### Fixed

- Shortened the package description to fit pub.dev's 180-character limit.

## 0.1.0

Initial release. Android and iOS.

### Added

- `DbSource` — adapts any SQLite-backed store to `db_exporter` through two
  callbacks, so the package depends on no database library itself. Covers
  sqflite, sqlite3, drift and everything built on them.
- `DbExporter` with `exportDatabaseFile()`, `exportCsv()`, `exportJson()` and
  `exportExcel()`, plus `export(format:)` for choosing a format at runtime.
  The database and destination are fixed on the constructor and per-format
  settings live on the exporter objects, so all five methods share one
  signature.
- Raw `.db` export via SQLite's `VACUUM INTO`, which snapshots a live database
  consistently, with a `wal_checkpoint(TRUNCATE)` and byte-copy fallback for
  SQLite builds older than 3.27.
- Five destinations. The default, `deviceFolder()`, writes to
  `dbexports-<packageName>` in the device's main directory and creates it on
  first use; the rest are the app sandbox, a directory you name, the OS share
  sheet, and a native save dialog backed by the Storage Access Framework.
- Table filtering (`tables`, `excludeTables`), row caps (`maxRowsPerTable`)
  and per-table progress reporting.
- `TabularExporter` as a public extension point for custom formats.

### Security

- CSV exports neutralise leading `=`, `+`, `-`, `@`, tab and CR so spreadsheet
  applications render cell contents as text rather than evaluating them
  ([CSV injection](https://owasp.org/www-community/attacks/CSV_Injection)).
  Negative numbers are exempted so numeric columns stay numeric. Disable with
  `CsvExporter(sanitizeFormulas: false)`.
- A denied write to the device folder throws `DbExportException` naming the
  required manifest entry and the alternatives, rather than a bare
  permission-denied.
