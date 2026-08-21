# db_exporter

[![pub package](https://img.shields.io/pub/v/db_exporter.svg)](https://pub.dev/packages/db_exporter)
[![pub points](https://img.shields.io/pub/points/db_exporter)](https://pub.dev/packages/db_exporter/score)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Export a Flutter app's local SQLite database — Drift, sqflite, raw `sqlite3` —
to a `.db` backup, CSV, JSON or Excel, and get the file out of the sandbox and
into the user's hands.

```dart
final exporter = DbExporter(
  SqlSource(databasePath: db.path, query: db.rawQuery, execute: db.execute),
);

await exporter.exportExcel(
  destination: const ExportDestination.share(subject: 'My data'),
);
```

That is the whole integration. No code generation, no schema declarations, and
**no dependency on your database package** — `db_exporter` depends on neither
`drift` nor `sqflite`.

---

## Why this exists

Writing "export my data" by hand looks like three lines of `File.copy`. It
isn't, and the gap is where the bugs live:

- **Copying a live SQLite file loses data.** Drift and sqflite both run in WAL
  mode, so recent writes sit in a `-wal` sidecar. Copy only the `.db` and you
  ship a backup silently missing them. `db_exporter` uses SQLite's own
  [`VACUUM INTO`][vacuum] snapshot, falling back to a `wal_checkpoint(TRUNCATE)`
  before copying.
- **Android 10+ killed the easy path.** `getExternalStorageDirectory()` plus a
  write to `/Downloads` no longer works. `db_exporter` routes through the
  Storage Access Framework, so exports land outside the sandbox with **no
  storage permission at all**.
- **A CSV of user data is an attack surface.** A row containing
  `=cmd|'/c calc'!A1` executes when the file is opened in Excel — this is
  [CSV injection][csvinj]. `db_exporter` neutralises formula triggers by
  default, while leaving negative numbers numeric.

[vacuum]: https://www.sqlite.org/lang_vacuum.html#vacuuminto
[csvinj]: https://owasp.org/www-community/attacks/CSV_Injection

## Install

```sh
flutter pub add db_exporter
```

```yaml
dependencies:
  db_exporter: ^0.1.0
```

## Connecting your database

`SqlSource` is the whole adapter layer. It takes two callbacks — one that runs
a query, one that runs a statement — so any SQLite-backed store fits.

<details open>
<summary><b>sqflite</b></summary>

```dart
final source = SqlSource(
  databasePath: db.path,
  query: db.rawQuery,
  execute: db.execute,
);
```
</details>

<details>
<summary><b>Drift</b></summary>

```dart
final source = SqlSource(
  databasePath: (await databaseFile()).path,
  query: (sql) async =>
      (await db.customSelect(sql).get()).map((row) => row.data).toList(),
  // Required: customSelect rejects VACUUM, so raw backups need this.
  execute: db.customStatement,
);
```
</details>

<details>
<summary><b>sqlite3 / sqlite3_flutter_libs</b></summary>

```dart
final source = SqlSource(
  databasePath: path,
  query: (sql) async => db.select(sql).map((row) => {...row}).toList(),
  execute: (sql) async => db.execute(sql),
);
```
</details>

`databasePath` is required only for raw `.db` exports. `execute` is optional,
but without it `VACUUM INTO` is unavailable and raw exports quietly fall back
to checkpoint-and-copy.

## Formats

| Format | Files out | Round-trips? | Good for |
| --- | --- | --- | --- |
| `exportDatabaseFile()` | one `.db` | **Yes** — reopen it with Drift/sqflite | backups, support bundles, device migration |
| `exportCsv()` | one `.csv` **per table** | No | spreadsheets, analysts, one-off inspection |
| `exportJson()` | one `.json` | No | uploads, APIs, debugging |
| `exportExcel()` | one `.xlsx`, a sheet per table | No | handing data to a non-developer |

```dart
// Everything, to the sandbox.
final result = await exporter.exportJson();

// Two tables only, capped, with progress.
await exporter.exportCsv(
  tables: ['orders', 'customers'],
  maxRowsPerTable: 50000,
  onProgress: (done, total, table) => print('$done/$total  $table'),
);

// Everything except the noisy ones.
await exporter.exportExcel(excludeTables: ['cache', 'sync_log']);
```

## Destinations

Format and destination are independent — any format goes to any destination.

| Destination | What happens | Permissions |
| --- | --- | --- |
| `ExportDestination.appDirectory()` | Writes into the app sandbox, returns the path | none |
| `ExportDestination.share()` | Hands the file to the OS share sheet | none |
| `ExportDestination.saveAs()` | Native save dialog; SAF on Android | none |

```dart
// Silent — for scheduled backups or an upload you drive yourself.
await exporter.exportDatabaseFile(
  destination: const ExportDestination.appDirectory(temporary: true),
);

// Let the user pick a folder. Android uses SAF; iOS falls back to the
// share sheet, where "Save to Files" is the platform-idiomatic equivalent.
await exporter.exportExcel(
  destination: const ExportDestination.saveAs(dialogTitle: 'Save report'),
);
```

> **iPad:** always pass `sharePositionOrigin` to `ExportDestination.share()`.
> UIKit anchors the popover to it and throws without one.

> **Multi-file CSV:** `saveAs` handles a single file. A multi-table CSV export
> must use `share()` or `appDirectory()`.

## Reading the result

```dart
final result = await exporter.exportCsv();

result.files;            // every file produced
result.single;           // the only file, for single-file formats
result.tables;           // tables actually included
result.totalRows;        // rows written
result.duration;         // wall clock
result.deliveredPath;    // null for the share sheet — it never tells us
result.userCancelled;    // user dismissed the dialog
```

Failures throw `DbExportException` with an actionable message:

```dart
try {
  await exporter.exportDatabaseFile();
} on DbExportException catch (e) {
  debugPrint(e.message);
}
```

## Platform support

| | Android | iOS | macOS | Windows | Linux | Web |
| --- | :-: | :-: | :-: | :-: | :-: | :-: |
| `appDirectory` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| `share` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| `saveAs` | ✅ (SAF) | ↩︎ share | ✅ | ✅ | ✅ | ❌ |

Web is out of scope: it has no `dart:io` filesystem, and browser-backed SQLite
lives in IndexedDB rather than a file. Raw `.db` export would be meaningless
there.

## How the raw backup stays consistent

`exportDatabaseFile()` defaults to `RawCopyStrategy.vacuumInto`:

```sql
VACUUM INTO '/path/to/export.db'
```

SQLite runs this inside a read transaction, so the copy is transactionally
consistent **even while your app keeps writing**, and it arrives defragmented —
usually smaller than the original. It needs SQLite 3.27+ (Android 11+, iOS 14+,
or any app bundling `sqlite3_flutter_libs`).

Where that is unavailable, the fallback is:

```sql
PRAGMA wal_checkpoint(TRUNCATE)   -- fold the -wal file back in
```

…followed by a byte copy. Force it with
`exportDatabaseFile(strategy: RawCopyStrategy.fileCopy)`, and make sure nothing
writes during the copy.

## Things worth knowing

- **Memory.** CSV, JSON and Excel materialise rows in memory. Use
  `maxRowsPerTable`, or export the raw `.db` for large datasets — it streams
  through SQLite and never touches the Dart heap.
- **BLOBs** become base64 in CSV, JSON and Excel. Only the raw `.db` keeps
  them as bytes.
- **CSV filenames** are `<base>_<timestamp>_<table>.csv`, so every file from a
  single export sorts together.
- **Encryption is not included.** Exporting an SQLCipher database via
  `VACUUM INTO` produces a *plaintext* copy. Encrypt the output yourself before
  it leaves the device.
- **Nothing is redacted.** Anything in the tables you select ends up in the
  file. Use `excludeTables` for token and session tables.

## Extending it

`TabularExporter` is public — implement it for a SQL dump, Parquet, or a zipped
bundle, and hand it the same `TableData` list the built-in formats receive.

## Roadmap

- SQL dump (`CREATE TABLE` + `INSERT`)
- Zipped and AES-encrypted bundles
- Hive / Isar / ObjectBox adapters
- Import and restore

## Contributing

Issues and PRs welcome at
[github.com/Azeem-dev14/db_exporter](https://github.com/Azeem-dev14/db_exporter).

```sh
flutter pub get
flutter test
dart analyze
```

## License

MIT — see [LICENSE](LICENSE).
