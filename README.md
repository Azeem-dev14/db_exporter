# db_exporter

[![pub package](https://img.shields.io/pub/v/db_exporter.svg)](https://pub.dev/packages/db_exporter)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Let your users export their data. Turn your app's SQLite database into a
backup file, a spreadsheet, or a share-sheet attachment in one line.

## Features

What you can offer your users:

- 💾 **Back up their data** — a real `.db` file they can keep, and you can
  restore from later.
- 📊 **Send their data to a spreadsheet** — Excel or CSV, ready to open.
- 📤 **Share it anywhere** — WhatsApp, email, Google Drive, Files.
- 📁 **Save it where they choose** — system file picker, no permissions.
- 📱 **Move to a new phone** — export, transfer, reopen.

Works with **sqflite**, **sqlite3** and **drift**. Android and iOS.

## Getting started

```sh
flutter pub add db_exporter
```

Connect your database once:

```dart
final exporter = DbExporter(
  DbSource(
    databasePath: db.path,
    query: db.rawQuery,
    execute: db.execute,
  ),
);
```

<details>
<summary>Using drift or sqlite3 instead?</summary>

```dart
// drift — also drift_sqflite
DbSource(
  databasePath: dbFile.path,
  query: (sql) async =>
      (await db.customSelect(sql).get()).map((row) => row.data).toList(),
  execute: db.customStatement,
);

// sqlite3 — also sqlite_async and powersync, with getAll() for select()
DbSource(
  databasePath: path,
  query: (sql) async =>
      db.select(sql).map<Map<String, Object?>>((r) => {...r}).toList(),
  execute: (sql) async => db.execute(sql),
);
```
</details>

## Usage

### Export a file

```dart
await exporter.exportExcel();         // .xlsx  a sheet per table
await exporter.exportCsv();           // .csv   a file per table
await exporter.exportJson();          // .json
await exporter.exportDatabaseFile();  // .db    reopens in your app
```

Put it on a button:

```dart
ElevatedButton(
  onPressed: () => exporter.exportExcel(),
  child: const Text('Export my data'),
)
```

### Choose where it goes

```dart
DbExporter(source, destination: const ExportDestination.share());
```

| Destination | What the user sees |
| --- | --- |
| `share()` | The share sheet — pick WhatsApp, email, Drive |
| `saveAs()` | A file picker — they choose the folder |
| `deviceFolder()` | Saved to `dbexports-<yourapp>` on the device *(default)* |
| `appDirectory()` | Nothing — stays inside the app |

### Export only what you want

```dart
await exporter.exportExcel(
  tables: ['orders'],          // just these
  excludeTables: ['cache'],    // everything but these
  maxRowsPerTable: 50000,
  fileName: 'my_report',
);
```

### Show the outcome

```dart
final result = await exporter.exportCsv();

if (result.userCancelled) return;
showSnackBar('Exported ${result.totalRows} rows');
```

Failures throw `DbExportException`, with a message you can show as-is:

```dart
try {
  await exporter.exportExcel();
} on DbExportException catch (e) {
  showSnackBar(e.message);
}
```

## Additional information

**Backups are safe.** `.db` exports use SQLite's `VACUUM INTO`, so the copy is
consistent even while your app is writing — a plain `File.copy` loses whatever
is still in the WAL.

**CSV is injection-safe.** Cells starting with `=`, `+`, `-` or `@` are
neutralised so spreadsheets don't execute them.

**Android 11+:** the default `deviceFolder()` destination needs All files
access, which Google Play only grants file managers and backup apps. Use
`saveAs()` instead — it reaches the same places with no permission.

**Large tables:** Excel, CSV and JSON build rows in memory. Use
`maxRowsPerTable`, or export the `.db`.

**Not included:** encryption, redaction, and support for Hive, Isar or
ObjectBox — those have no tables to export.

See [`example/`](example/) for a runnable app exporting three databases.

## License

MIT
