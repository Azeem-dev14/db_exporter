# db_exporter

[![pub package](https://img.shields.io/pub/v/db_exporter.svg)](https://pub.dev/packages/db_exporter)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Export your app's SQLite database to a `.db` backup, CSV, JSON or Excel — and
get the file out of the sandbox. Works with sqflite, sqlite3 and Drift.
Android and iOS.

```dart
final exporter = DbExporter(
  DbSource(databasePath: db.path, query: db.rawQuery, execute: db.execute),
);

await exporter.exportExcel();
```

That's the whole integration. No code generation, and no dependency on your
database package.

## Install

```sh
flutter pub add db_exporter
```

## Connect your database

There are three wirings. Pick the one matching your package.

```dart
// sqflite — also sqflite_common_ffi, sqflite_sqlcipher, floor
DbSource(
  databasePath: db.path,
  query: db.rawQuery,
  execute: db.execute,
);

// sqlite3 — also sqlite_async and powersync, with getAll() for select()
DbSource(
  databasePath: path,
  query: (sql) async =>
      db.select(sql).map<Map<String, Object?>>((r) => {...r}).toList(),
  execute: (sql) async => db.execute(sql),
);

// drift — also drift_sqflite
DbSource(
  databasePath: dbFile.path,
  query: (sql) async =>
      (await db.customSelect(sql).get()).map((row) => row.data).toList(),
  execute: db.customStatement,
);
```

`databasePath` is needed only for `.db` exports. `execute` is optional, but
without it raw backups fall back to a slower, less safe copy.

Not supported: Hive, Isar, ObjectBox, shared_preferences, sembast — they have
no tables to export.

## Export

Four formats. Every method takes the same arguments.

```dart
await exporter.exportDatabaseFile();  // .db    reopens in your app
await exporter.exportCsv();           // .csv   one file per table
await exporter.exportJson();          // .json  one file
await exporter.exportExcel();         // .xlsx  one sheet per table

await exporter.export(format: userChoice);   // pick at runtime
```

```dart
await exporter.exportExcel(
  tables: ['orders'],          // default: every table
  excludeTables: ['cache'],    // default: none
  maxRowsPerTable: 50000,      // default: unlimited
  fileName: 'report',          // default: the database filename
  onProgress: (done, total, table) {},
);
```

## Where the file goes

```dart
DbExporter(source, destination: const ExportDestination.share());
```

| Destination | Result |
| --- | --- |
| `deviceFolder()` | `dbexports-<packageName>` on the device — **default** |
| `appDirectory()` | Inside the app sandbox |
| `directory(path)` | A path you name, created if missing |
| `share()` | The OS share sheet |
| `saveAs()` | System save dialog |

Override per call with `exportExcel(destination: ...)`.

> [!IMPORTANT]
> The default destination writes to the device's main directory, which needs
> **All files access** on Android 11+:
>
> ```xml
> <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
> ```
>
> Google Play restricts that permission to file managers and backup apps. If
> yours isn't one, use `ExportDestination.saveAs()` instead — it reaches the
> same places through the system picker with no permission at all.

On iOS there is no device-wide folder, so `deviceFolder()` writes under app
documents and `saveAs()` opens the share sheet.

## The result

```dart
final result = await exporter.exportCsv();

result.files;           // every file produced
result.totalRows;
result.deliveredPath;   // null for the share sheet
result.userCancelled;
```

Errors throw `DbExportException`, with a message you can show as-is.

```dart
try {
  await exporter.exportDatabaseFile();
} on DbExportException catch (e) {
  debugPrint(e.message);
}
```

## Good to know

- **Backups are safe.** `.db` exports use SQLite's `VACUUM INTO`, so the copy
  is consistent even while your app is writing. A plain `File.copy` loses
  whatever is still in the WAL.
- **CSV is injection-safe.** Cells starting with `=`, `+`, `-` or `@` are
  neutralised so spreadsheets don't execute them. Negative numbers stay numeric.
- **Memory.** CSV, JSON and Excel build rows in memory — use `maxRowsPerTable`
  for big tables, or export the `.db`.
- **BLOBs** become base64 everywhere except the raw `.db`.
- **Nothing is redacted.** Use `excludeTables` for token and session tables.
- **SQLCipher exports come out plaintext.** Encrypt them yourself.
- **Multi-file CSV can't use `saveAs()`** — the dialog takes one file.

## Settings

```dart
DbExporter(
  source,
  csv: const CsvExporter(delimiter: ';'),
  json: const JsonExporter(pretty: false),
  excel: const ExcelExporter(autoFitColumns: false),
  rawDatabase: const RawDatabaseExporter(strategy: RawCopyStrategy.fileCopy),
);
```

## Example

[`example/`](example/) exports three databases side by side — sqflite/Schools,
sqlite3/Bookstore and drift/Music — with a format and destination picker.

```sh
cd example && flutter run
```

## License

MIT
