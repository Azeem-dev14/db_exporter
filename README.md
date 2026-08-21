# db_exporter

[![pub package](https://img.shields.io/pub/v/db_exporter.svg)](https://pub.dev/packages/db_exporter)
[![pub points](https://img.shields.io/pub/points/db_exporter)](https://pub.dev/packages/db_exporter/score)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Export a Flutter app's local SQLite database — Drift, sqflite, raw `sqlite3` —
to a `.db` backup, CSV, JSON or Excel, and get the file out of the sandbox and
into the user's hands. **Android and iOS.**

```dart
final exporter = DbExporter(
  DbSource(databasePath: db.path, query: db.rawQuery, execute: db.execute),
);

await exporter.exportExcel();
// -> /storage/emulated/0/dbexports-com.example.myapp/app_20260822_143001.xlsx
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

## Supported databases

Anything backed by a real SQLite file. `db_exporter` never imports your
database package — `DbSource` takes two callbacks, so nothing is special-cased
and packages not listed here work as long as they can run SQL.

| Package | Downloads/30d | Supported | Wiring |
| --- | ---: | :-: | --- |
| [`sqflite`](https://pub.dev/packages/sqflite) | 2.75M | ✅ | `query: db.rawQuery, execute: db.execute` |
| [`sqlite3`](https://pub.dev/packages/sqlite3) | 2.22M | ✅ | `db.select` + `db.execute` |
| [`drift`](https://pub.dev/packages/drift) | 1.14M | ✅ | `customSelect` + `customStatement` |
| [`sqlite_async`](https://pub.dev/packages/sqlite_async) | 418k | ✅ | `db.getAll` + `db.execute` |
| [`sqflite_common_ffi`](https://pub.dev/packages/sqflite_common_ffi) | 246k | ✅ | same as sqflite |
| [`sqflite_sqlcipher`](https://pub.dev/packages/sqflite_sqlcipher) | 72k | ⚠️ | same as sqflite — **exports are plaintext** |
| [`powersync`](https://pub.dev/packages/powersync) | 31k | ✅ | same as sqlite_async |
| [`floor`](https://pub.dev/packages/floor) | 22k | ✅ | `db.database.rawQuery` / `.execute` |
| [`drift_sqflite`](https://pub.dev/packages/drift_sqflite) | 13k | ✅ | same as drift |
| [`sembast_sqflite`](https://pub.dev/packages/sembast_sqflite) | 4k | ⚠️ | runs, but sembast stores JSON blobs in one table — you get serialized records, not your fields |
| [`hive`](https://pub.dev/packages/hive) / `hive_ce` | — | ❌ | key-value boxes, no tables |
| [`isar`](https://pub.dev/packages/isar) | — | ❌ | NoSQL collections |
| [`objectbox`](https://pub.dev/packages/objectbox) | — | ❌ | NoSQL, own file format |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | — | ❌ | flat key-value |
| [`sembast`](https://pub.dev/packages/sembast) / `get_storage` | — | ❌ | document / JSON stores |

Download figures are pub.dev's 30-day counts as of August 2026.

Adapters for the ❌ rows are on the roadmap.

The [example app](example/) runs the top five side by side — one dataset per
package, so an export makes it obvious which wiring produced it.

### Wiring each one

<details open>
<summary><b>sqflite</b> — also sqflite_common_ffi, sqflite_sqlcipher, drift_sqflite</summary>

```dart
final source = DbSource(
  databasePath: db.path,
  query: db.rawQuery,
  execute: db.execute,
);
```
</details>

<details>
<summary><b>drift</b></summary>

```dart
final source = DbSource(
  databasePath: dbFile.path,   // only needed for raw .db exports
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
final source = DbSource(
  databasePath: path,
  query: (sql) async =>
      db.select(sql).map<Map<String, Object?>>((r) => {...r}).toList(),
  execute: (sql) async => db.execute(sql),
);
```
</details>

<details>
<summary><b>sqlite_async / powersync</b></summary>

```dart
final source = DbSource(
  databasePath: path,
  query: (sql) async =>
      (await db.getAll(sql)).map<Map<String, Object?>>((r) => {...r}).toList(),
  execute: (sql) async => db.execute(sql),
);
```
</details>

<details>
<summary><b>floor</b></summary>

```dart
final source = DbSource(
  databasePath: path,          // where you called $FloorAppDatabase…build()
  query: db.database.rawQuery,
  execute: db.database.execute,
);
```
</details>

`databasePath` is required only for raw `.db` exports. `execute` is optional,
but without it `VACUUM INTO` is unavailable and raw exports quietly fall back
to checkpoint-and-copy.

## Export formats

| Method | `ExportFormat` | Files out | Round-trips? | Best for |
| --- | --- | --- | :-: | --- |
| `exportDatabaseFile()` | `.rawDatabase` | one `.db` | **Yes** | backups, support bundles, device migration |
| `exportCsv()` | `.csv` | one **per table** | No | spreadsheets, analysts, quick inspection |
| `exportJson()` | `.json` | one file | No | uploads, APIs, debugging |
| `exportExcel()` | `.excel` | one `.xlsx`, a sheet per table | No | handing data to a non-developer |

Every method takes the **same** six arguments, so the format can be chosen at
runtime:

```dart
tables:           List<String>?        // default: every user table
excludeTables:    List<String>?        // default: none
fileName:         String?              // default: the database filename
maxRowsPerTable:  int?                 // default: unlimited
destination:      ExportDestination?   // default: the constructor's
onProgress:       ExportProgress?
```

```dart
await exporter.exportExcel();
await exporter.exportCsv(tables: ['orders', 'customers']);
await exporter.export(format: userChoice);   // runtime pick
```

`ExportFormat` carries what you need to drive a UI: `name`, `fileExtension`,
`mimeType` and `isMultiFile` — use the last one to stop a CSV export being sent
to the single-file save dialog.

### How values are converted

| SQLite type | `.db` | CSV | JSON | Excel |
| --- | --- | --- | --- | --- |
| `INTEGER` | as-is | text | number | numeric cell |
| `REAL` | as-is | text | number | numeric cell |
| `TEXT` | as-is | quoted per RFC 4180 | string | text cell |
| `BLOB` | as-is | base64 | base64 | base64 text |
| `NULL` | as-is | empty field | `null` | empty cell |

Only the raw `.db` keeps BLOBs as bytes.

## Destinations

Format and destination are independent — any format goes to any destination.

| Destination | What happens | Permissions |
| --- | --- | --- |
| `ExportDestination.deviceFolder()` | `dbexports-<packageName>` in the device's main directory — **the default** | Android 11+: All files access |
| `ExportDestination.appDirectory()` | Writes into the app sandbox, returns the path | none |
| `ExportDestination.directory(path)` | Writes to a path you name, creating it if missing | depends on the path |
| `ExportDestination.share()` | Hands the file to the OS share sheet | none |
| `ExportDestination.saveAs()` | Native save dialog; SAF on Android | none |

```dart
// The default — dbexports-com.example.myapp in the device's main directory,
// created on first use.
await exporter.exportExcel();

// Set once, for every export this exporter performs.
final exporter = DbExporter(source, destination: const ExportDestination.share());

// Override for a single call.
await exporter.exportExcel(
  destination: const ExportDestination.saveAs(dialogTitle: 'Save report'),
);
```

> **iPad:** always pass `sharePositionOrigin` to `ExportDestination.share()`.
> UIKit anchors the popover to it and throws without one.

> **The default destination needs a permission on Android 11+.** Writing to
> the external storage root requires `MANAGE_EXTERNAL_STORAGE`, and Google Play
> restricts that to file managers and backup apps. Add it to your manifest and
> send the user to *Settings → Apps → your app → All files access*:
>
> ```xml
> <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
> ```
>
> If Play will not approve it for your app, set a different default:
> `DbExporter(source, destination: const ExportDestination.saveAs())`. When the
> write is denied, `db_exporter` throws `DbExportException` naming the manifest
> entry and the alternatives rather than a bare permission-denied.

> **iOS has no device-wide directory.** No permission grants one, so
> `deviceFolder()` creates `dbexports-<bundleId>` under app documents instead.
> Use `share()` to put the file into the Files app.

> **Multi-file CSV:** `saveAs` handles a single file. A multi-table CSV export
> must use `share()` or `appDirectory()`.

## Per-format settings

Format-specific options live on the exporter objects, not on the call sites —
which is what keeps every export method's signature identical.

```dart
final exporter = DbExporter(
  source,
  destination: const ExportDestination.share(),
  fileName: 'orders',
  csv: const CsvExporter(delimiter: ';', sanitizeFormulas: false),
  json: const JsonExporter(pretty: false, includeMetadata: false),
  excel: const ExcelExporter(autoFitColumns: false),
  rawDatabase: const RawDatabaseExporter(
    strategy: RawCopyStrategy.fileCopy,
  ),
);
```

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

Android and iOS. Desktop and web are out of scope for this release — web has
no `dart:io` filesystem, and browser-backed SQLite lives in IndexedDB rather
than a file, so a raw `.db` export would be meaningless there.

| Destination | Android | iOS |
| --- | :-: | :-: |
| `deviceFolder()` *(default)* | ⚠️ needs All files access on 11+ | folder under app documents |
| `appDirectory()` | ✅ | ✅ |
| `directory(path)` | ✅ for app-specific paths | ✅ inside the sandbox |
| `share()` | ✅ | ✅ |
| `saveAs()` | ✅ via SAF | ↩︎ falls back to share |

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

…followed by a byte copy. Force it with `DbExporter(source, rawDatabase: const
RawDatabaseExporter(strategy: RawCopyStrategy.fileCopy))`, and make sure
nothing writes during the copy.

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
