# db_exporter

[![pub package](https://img.shields.io/pub/v/db_exporter.svg)](https://pub.dev/packages/db_exporter)
[![pub points](https://img.shields.io/pub/points/db_exporter)](https://pub.dev/packages/db_exporter/score)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Export a Flutter app's SQLite database — sqflite, sqlite3 or Drift — to a
`.db` backup, CSV, JSON or Excel, and get the file out of the sandbox and into
the user's hands. Android and iOS.

```dart
final exporter = DbExporter(
  DbSource(databasePath: db.path, query: db.rawQuery, execute: db.execute),
);

await exporter.exportExcel();
```

No code generation, no schema declarations, and **no dependency on your
database package** — `db_exporter` imports neither `drift` nor `sqflite`.

## Contents

- [Why this exists](#why-this-exists)
- [Install](#install)
- [Supported databases](#supported-databases)
- [Export formats](#export-formats)
- [Destinations](#destinations)
- [Settings](#settings)
- [Reading the result](#reading-the-result)
- [Handling errors](#handling-errors)
- [How the raw backup stays consistent](#how-the-raw-backup-stays-consistent)
- [Limitations](#limitations)
- [Extending it](#extending-it)

## Why this exists

Writing "export my data" by hand looks like three lines of `File.copy`. It
isn't, and the gap is where the bugs live.

**Copying a live SQLite file loses data.** Drift and sqflite both run in WAL
mode, so recent writes sit in a `-wal` sidecar. Copy only the `.db` and you
ship a backup silently missing them. `db_exporter` uses SQLite's own
[`VACUUM INTO`][vacuum] snapshot, falling back to `wal_checkpoint(TRUNCATE)`
before copying.

**Android 10+ killed the easy path.** `getExternalStorageDirectory()` plus a
write to `/Downloads` no longer works. `db_exporter` routes through the Storage
Access Framework, so exports land outside the sandbox with **no storage
permission**.

**A CSV of user data is an attack surface.** A row containing
`=cmd|'/c calc'!A1` executes when the file is opened in Excel — this is
[CSV injection][csvinj]. `db_exporter` neutralises formula triggers by default,
while leaving negative numbers numeric.

[vacuum]: https://www.sqlite.org/lang_vacuum.html#vacuuminto
[csvinj]: https://owasp.org/www-community/attacks/CSV_Injection

## Install

```sh
flutter pub add db_exporter
```

## Supported databases

Anything backed by a real SQLite file. `DbSource` takes two callbacks, so
nothing is special-cased and packages not listed here work as long as they can
run SQL.

| Package | Downloads/30d | Supported | Wires like |
| --- | ---: | :-: | --- |
| [`sqflite`](https://pub.dev/packages/sqflite) | 2.75M | ✅ | *sqflite* |
| [`sqlite3`](https://pub.dev/packages/sqlite3) | 2.22M | ✅ | *sqlite3* |
| [`drift`](https://pub.dev/packages/drift) | 1.14M | ✅ | *drift* |
| [`sqlite_async`](https://pub.dev/packages/sqlite_async) | 418k | ✅ | sqlite3, `getAll` for `select` |
| [`sqflite_common_ffi`](https://pub.dev/packages/sqflite_common_ffi) | 246k | ✅ | sqflite |
| [`sqflite_sqlcipher`](https://pub.dev/packages/sqflite_sqlcipher) | 72k | ⚠️ | sqflite — **exports are plaintext** |
| [`powersync`](https://pub.dev/packages/powersync) | 31k | ✅ | sqlite_async |
| [`floor`](https://pub.dev/packages/floor) | 22k | ✅ | sqflite, via `db.database` |
| [`drift_sqflite`](https://pub.dev/packages/drift_sqflite) | 13k | ✅ | drift |
| [`sembast_sqflite`](https://pub.dev/packages/sembast_sqflite) | 4k | ⚠️ | stores JSON blobs in one table — you get serialized records, not columns |
| `hive` · `isar` · `objectbox` · `shared_preferences` · `sembast` · `get_storage` | — | ❌ | key-value and document stores, no tables |

Figures are pub.dev 30-day counts, August 2026. Adapters for the ❌ row are on
the roadmap.

There are only three wiring styles. Every supported package is one of them:

<details open>
<summary><b>sqflite</b> — also sqflite_common_ffi, sqflite_sqlcipher, floor</summary>

```dart
final source = DbSource(
  databasePath: db.path,
  query: db.rawQuery,
  execute: db.execute,
);
```

For `floor`, reach through the generated class: `db.database.rawQuery`.
</details>

<details>
<summary><b>sqlite3</b> — also sqlite_async, powersync</summary>

```dart
final source = DbSource(
  databasePath: path,
  query: (sql) async =>
      db.select(sql).map<Map<String, Object?>>((r) => {...r}).toList(),
  execute: (sql) async => db.execute(sql),
);
```

`sqlite_async` and `powersync` are the same with `await db.getAll(sql)` in
place of `db.select(sql)`.
</details>

<details>
<summary><b>drift</b> — also drift_sqflite</summary>

```dart
final source = DbSource(
  databasePath: dbFile.path,
  query: (sql) async =>
      (await db.customSelect(sql).get()).map((row) => row.data).toList(),
  // Required: customSelect rejects VACUUM, so raw backups need this.
  execute: db.customStatement,
);
```
</details>

`databasePath` is required only for raw `.db` exports. `execute` is optional,
but without it `VACUUM INTO` is unavailable and raw exports quietly fall back
to checkpoint-and-copy.

The [example app](example/) runs the top three side by side, one dataset per
package.

## Export formats

| Method | `ExportFormat` | Files out | Round-trips? | Best for |
| --- | --- | --- | :-: | --- |
| `exportDatabaseFile()` | `.rawDatabase` | one `.db` | **Yes** | backups, support bundles, device migration |
| `exportCsv()` | `.csv` | one **per table** | No | spreadsheets, analysts, quick inspection |
| `exportJson()` | `.json` | one file | No | uploads, APIs, debugging |
| `exportExcel()` | `.excel` | one `.xlsx`, a sheet per table | No | handing data to a non-developer |

Every method takes the **same** six arguments:

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
await exporter.exportJson(excludeTables: ['cache', 'sync_log']);
await exporter.exportDatabaseFile(fileName: 'backup');
```

So the format can be chosen at runtime:

```dart
await exporter.export(format: userChoice);
```

`ExportFormat` carries what a UI needs — `name`, `fileExtension`, `mimeType`
and `isMultiFile`. Use the last one to stop a CSV export being sent to the
single-file save dialog.

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
| `deviceFolder()` | `dbexports-<packageName>` in the device's main directory — **the default** | Android 11+: All files access |
| `appDirectory()` | Writes into the app sandbox, returns the path | none |
| `directory(path)` | Writes to a path you name, creating it if missing | depends on the path |
| `share()` | Hands the file to the OS share sheet | none |
| `saveAs()` | Native save dialog; SAF on Android | none |

```dart
// Set once, for every export this exporter performs.
final exporter = DbExporter(
  source,
  destination: const ExportDestination.share(),
);

// Override for a single call.
await exporter.exportExcel(
  destination: const ExportDestination.saveAs(dialogTitle: 'Save report'),
);
```

> [!IMPORTANT]
> **The default destination needs a permission on Android 11+.** Writing to the
> external storage root requires `MANAGE_EXTERNAL_STORAGE`, and Google Play
> restricts that to file managers and backup apps:
>
> ```xml
> <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
> ```
>
> Then send the user to *Settings → Apps → your app → All files access*. If
> Play will not approve it, set a different default:
> `DbExporter(source, destination: const ExportDestination.saveAs())`.

> [!NOTE]
> **iOS has no device-wide directory**, and no permission grants one, so
> `deviceFolder()` creates `dbexports-<bundleId>` under app documents instead.
> `saveAs()` likewise falls back to the share sheet, where "Save to Files" is
> the platform-idiomatic equivalent.

> [!TIP]
> On **iPad**, pass `sharePositionOrigin` to `share()` — UIKit anchors the
> popover to it and throws without one. **Multi-file CSV** cannot use
> `saveAs()`; use `share()` or a folder destination.

## Settings

Per-format options live on the exporter objects, which is what keeps every
export method's signature identical.

```dart
final exporter = DbExporter(
  source,
  destination: const ExportDestination.share(),
  fileName: 'orders',
  timestampFileNames: true,
  csv: const CsvExporter(delimiter: ';', sanitizeFormulas: false),
  json: const JsonExporter(pretty: false, includeMetadata: false),
  excel: const ExcelExporter(boldHeader: true, autoFitColumns: false),
  rawDatabase: const RawDatabaseExporter(
    strategy: RawCopyStrategy.fileCopy,
    includeWalFiles: true,
  ),
);
```

## Reading the result

```dart
final result = await exporter.exportCsv();

result.files;             // every file produced
result.single;            // the only file, for single-file formats
result.tables;            // tables actually included
result.totalRows;         // rows written
result.totalSizeInBytes;
result.duration;
result.deliveredPath;     // null for the share sheet — it never tells us
result.userCancelled;     // user dismissed the dialog
```

## Handling errors

Everything recoverable throws `DbExportException` with a message written to be
shown or logged as-is.

```dart
try {
  await exporter.exportDatabaseFile();
} on DbExportException catch (e) {
  debugPrint(e.message);
}
```

| Thrown when | Message tells you |
| --- | --- |
| Raw export without `databasePath` | which constructor argument is missing |
| Unknown name in `tables:` | the names available |
| Device folder denied | the manifest entry and the alternatives |
| `saveAs` given several files | to use `share()` instead |

## How the raw backup stays consistent

`exportDatabaseFile()` defaults to `RawCopyStrategy.vacuumInto`:

```sql
VACUUM INTO '/path/to/export.db'
```

SQLite runs this inside a read transaction, so the copy is transactionally
consistent **even while your app keeps writing**, and it arrives defragmented —
usually smaller than the original. It needs SQLite 3.27+ (Android 11+, iOS 14+,
or any app bundling `sqlite3_flutter_libs`).

Where that is unavailable, the fallback is `PRAGMA wal_checkpoint(TRUNCATE)` —
folding the `-wal` file back in — followed by a byte copy. Force it with
`RawDatabaseExporter(strategy: RawCopyStrategy.fileCopy)`, and make sure
nothing writes during the copy.

## Limitations

- **Memory.** CSV, JSON and Excel materialise rows in memory. Use
  `maxRowsPerTable`, or export the raw `.db` for large datasets — it streams
  through SQLite and never touches the Dart heap.
- **Encryption is not included.** Exporting an SQLCipher database via
  `VACUUM INTO` produces a *plaintext* copy. Encrypt the output yourself before
  it leaves the device.
- **Nothing is redacted.** Anything in the tables you select ends up in the
  file. Use `excludeTables` for token and session tables.
- **No web support.** Web has no `dart:io` filesystem, and browser-backed
  SQLite lives in IndexedDB rather than a file.
- **CSV filenames** are `<base>_<timestamp>_<table>.csv`, so every file from a
  single export sorts together.

## Extending it

`TabularExporter` is public — implement it for a SQL dump, Parquet, or a zipped
bundle, and hand it the same `TableData` list the built-in formats receive.

```dart
class MarkdownExporter implements TabularExporter {
  @override
  ExportFormat get format => ExportFormat.csv;

  @override
  Future<List<ExportedFile>> write({
    required List<TableData> tables,
    required Directory stagingDirectory,
    required String baseName,
  }) async {
    // …write files into stagingDirectory, return them.
  }
}
```

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
