# db_exporter example

Exports three databases side by side, each with its own dataset so the file you
open makes it obvious which one produced it.

| Package | Dataset | Tables |
| --- | --- | --- |
| `sqflite` | Schools | `schools`, `teachers` |
| `sqlite3` | Bookstore | `books`, `orders` |
| `drift` | Music | `artists`, `albums`, `tracks` |

Pick a database, a format and a destination, then hit Export. The result card
shows rows, size, time and the final path.

```sh
flutter run
```

## Notes

- These three cover every wiring style. `sqflite_common_ffi`,
  `sqflite_sqlcipher` and `floor` wire like sqflite; `drift_sqflite` like
  drift; `sqlite_async` and `powersync` like sqlite3.
- The drift demo subclasses `GeneratedDatabase` directly so the example needs
  no `build_runner`. A real app uses `@DriftDatabase` — the db_exporter wiring
  is identical.
- The **Device folder** destination needs All files access on Android 11+:

  ```xml
  <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
  ```
