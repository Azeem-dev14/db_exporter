# db_exporter example

A one-screen Flutter app that seeds a small sqflite database and exports it
four ways:

| Button | Format | Destination |
| --- | --- | --- |
| Share raw `.db` backup | `rawDatabase` | share sheet |
| Save `.xlsx` | `excel` | native save dialog |
| Share CSV per table | `csv` | share sheet |
| Write JSON | `json` | app documents directory |

The only db_exporter-specific code is the `DbSource` in `_ExportDemoPageState`:

```dart
DbExporter(
  DbSource(
    databasePath: db.path,
    query: db.rawQuery,
    execute: db.execute,
  ),
);
```

Run it with:

```sh
cd example
flutter run
```
