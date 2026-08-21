# db_exporter example

One screen that exports **three different databases**, each backed by a
different storage package and holding a different dataset — so the file you
open afterwards makes it obvious which one produced it.

| Database | Package | Tables | `DbSource` wiring |
| --- | --- | --- | --- |
| Schools | `sqflite` | `schools`, `teachers` | `query: db.rawQuery, execute: db.execute` |
| Music | `drift` | `artists`, `albums`, `tracks` | `query: customSelect().get(), execute: customStatement` |
| Bookstore | `sqlite3` | `books`, `orders` | `query: db.select(), execute: db.execute` |

Pick a database, pick a format, pick a destination, hit **Export**. The result
card shows the row count, file size, elapsed time and the final path.

## Running it

```sh
cd example
flutter run
```

## Notes

- The **drift** demo subclasses `GeneratedDatabase` directly so the example
  needs no `build_runner` step. A real app uses `@DriftDatabase(tables: [...])`
  and generated code — the db_exporter wiring is identical either way, since it
  only calls `customSelect` and `customStatement`.
- The **Device folder** destination needs All files access on Android 11+:

  ```xml
  <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
  ```

  Without it the export fails with a `DbExportException` explaining exactly
  that — which is itself worth seeing once.
- **CSV + system save dialog** is rejected in the UI: CSV writes one file per
  table and the dialog accepts one file.
