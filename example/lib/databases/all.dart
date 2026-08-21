import '../demo_database.dart';
import 'drift_music.dart';
import 'sqflite_schools.dart';
import 'sqlite3_bookstore.dart';

/// The three most-used SQL packages in the Flutter ecosystem, each with its
/// own dataset. Monthly downloads on pub.dev as of August 2026:
///
/// | Package   | Downloads/30d | Dataset   |
/// | --------- | ------------- | --------- |
/// | `sqflite` | 2.75M         | Schools   |
/// | `sqlite3` | 2.22M         | Bookstore |
/// | `drift`   | 1.14M         | Music     |
///
/// Between them these cover all three wiring styles, so every other supported
/// package matches one of them: `sqflite_common_ffi`, `sqflite_sqlcipher`,
/// `drift_sqflite` and `floor` wire like sqflite or drift, and `sqlite_async`
/// and `powersync` wire like sqlite3 with `getAll` in place of `select`.
List<DemoDatabase> buildDemoDatabases() => [
      SqfliteSchools(),
      Sqlite3Bookstore(),
      DriftMusic(),
    ];
