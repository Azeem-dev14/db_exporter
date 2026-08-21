## 0.1.0

Initial release.

### Added

- `SqlSource` — adapts any SQLite-backed store (Drift, sqflite, `sqlite3`) via
  two callbacks, so the package depends on no database library itself.
- `DbExporter` with `exportDatabaseFile()`, `exportCsv()`, `exportJson()` and
  `exportExcel()`, plus a general `export()` for full control.
- Raw `.db` export via SQLite's `VACUUM INTO`, which snapshots a live database
  consistently, with a `wal_checkpoint(TRUNCATE)` + byte-copy fallback for
  SQLite builds older than 3.27.
- Three pluggable destinations: the app sandbox, the OS share sheet, and a
  native save dialog backed by the Storage Access Framework on Android.
- Table filtering (`tables`, `excludeTables`), row caps (`maxRowsPerTable`)
  and per-table progress reporting.
- `TabularExporter` as a public extension point for custom formats.

### Security

- CSV exports neutralise leading `=`, `+`, `-`, `@`, tab and CR so spreadsheet
  applications render cell contents as text rather than evaluating them
  ([CSV injection](https://owasp.org/www-community/attacks/CSV_Injection)).
  Negative numbers are exempted so numeric columns stay numeric. Disable with
  `sanitizeFormulas: false`.
