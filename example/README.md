# db_exporter example

One screen that exports the **three most-used SQL packages** in the Flutter
ecosystem, each holding a different dataset — so the file you open afterwards
makes it obvious which one produced it.

| Dataset | Package | Downloads/30d | Tables | `DbSource` wiring |
| --- | --- | ---: | --- | --- |
| Schools | `sqflite` | 2.75M | `schools`, `teachers` | `rawQuery` + `execute` |
| Bookstore | `sqlite3` | 2.22M | `books`, `orders` | `select()` + `execute` |
| Music | `drift` | 1.14M | `artists`, `albums`, `tracks` | `customSelect().get()` + `customStatement` |

Between them these are the only three wiring styles that exist. Every other
supported package matches one of them:

| Package | Wires like |
| --- | --- |
| `sqflite_common_ffi`, `sqflite_sqlcipher`, `floor` | sqflite |
| `drift_sqflite` | drift |
| `sqlite_async`, `powersync` | sqlite3, with `getAll` for `select` |

Pick a database, pick one of the four formats, pick a destination, hit
**Export**. The result card shows the row count, file size, elapsed time and
the final path.

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
