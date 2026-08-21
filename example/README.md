# db_exporter example

One screen that exports **seven different databases**, each backed by a
different storage package and holding a different dataset — so the file you
open afterwards makes it obvious which one produced it.

| Dataset | Package | Tables | `DbSource` wiring |
| --- | --- | --- | --- |
| Schools | `sqflite` | `schools`, `teachers` | `rawQuery` + `execute` |
| Airports | `sqflite_common_ffi` | `airports`, `flights` | same as sqflite |
| Music | `drift` | `artists`, `albums`, `tracks` | `customSelect().get()` + `customStatement` |
| Recipes | `drift_sqflite` | `recipes`, `ingredients` | same as drift |
| Bookstore | `sqlite3` | `books`, `orders` | `select()` + `execute` |
| Weather | `sqlite_async` | `stations`, `readings` | `getAll()` + `execute` |
| Notes | `sembast_sqflite` | internal store | read the file with sqflite |

Pick a database, pick a format, pick a destination, hit **Export**. The result
card shows the row count, file size, elapsed time and the final path.

## Running it

```sh
cd example
flutter run
```

## Deliberately absent

Two supported packages are not in the example, for reasons that would obscure
the point rather than demonstrate it:

- **floor** needs `build_runner` to generate its database class. Wiring:
  `query: db.database.rawQuery, execute: db.database.execute`.
- **sqflite_sqlcipher** bundles its own native SQLite, which clashes with the
  plain `sqflite` plugin when both are in one app. Wiring is identical to
  sqflite — and exports come out **plaintext**, so encrypt them yourself.

**powersync** is covered by the `sqlite_async` demo; it is built on that
package and wires up the same way.

## Notes

- Both **drift** demos subclass `GeneratedDatabase` directly so the example
  needs no `build_runner` step. A real app uses `@DriftDatabase(tables: [...])`
  and generated code — the db_exporter wiring is identical either way, since it
  only calls `customSelect` and `customStatement`.
- The **sembast** demo is there to show a caveat, not a happy path: sembast
  keeps every record as a JSON blob in one internal table, so you get
  `key`/`value` rows rather than `title`/`body` columns. The app shows this as
  a warning banner.
- The **Device folder** destination needs All files access on Android 11+:

  ```xml
  <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
  ```

  Without it the export fails with a `DbExportException` explaining exactly
  that — which is itself worth seeing once.
- **CSV + system save dialog** is rejected in the UI: CSV writes one file per
  table and the dialog accepts one file.
