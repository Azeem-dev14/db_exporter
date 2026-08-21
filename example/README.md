# db_exporter example

One screen that exports the **five most-used SQL packages** in the Flutter
ecosystem, each holding a different dataset — so the file you open afterwards
makes it obvious which one produced it.

| Dataset | Package | Downloads/30d | Tables | `DbSource` wiring |
| --- | --- | ---: | --- | --- |
| Schools | `sqflite` | 2.75M | `schools`, `teachers` | `rawQuery` + `execute` |
| Bookstore | `sqlite3` | 2.22M | `books`, `orders` | `select()` + `execute` |
| Music | `drift` | 1.14M | `artists`, `albums`, `tracks` | `customSelect().get()` + `customStatement` |
| Weather | `sqlite_async` | 418k | `stations`, `readings` | `getAll()` + `execute` |
| Airports | `sqflite_common_ffi` | 246k | `airports`, `flights` | same as sqflite |

Pick a database, pick a format, pick a destination, hit **Export**. The result
card shows the row count, file size, elapsed time and the final path.

## Running it

```sh
cd example
flutter run
```

## Supported but not demonstrated

These work — the README's support matrix has their wiring — but they earn no
slot here:

| Package | Why not | Wiring |
| --- | --- | --- |
| `powersync` | built on `sqlite_async`, identical wiring | see Weather |
| `drift_sqflite` | 13k downloads, a migration path | see Music |
| `floor` | 22k downloads and needs `build_runner` | `db.database.rawQuery` / `.execute` |
| `sqflite_sqlcipher` | bundles a native SQLite that clashes with the `sqflite` plugin in one app | same as sqflite — exports are **plaintext** |
| `sembast_sqflite` | stores JSON blobs in one table, so you get `key`/`value` rows, not columns | read the file with sqflite |

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
