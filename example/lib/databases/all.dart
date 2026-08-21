import '../demo_database.dart';
import 'drift_music.dart';
import 'sqflite_ffi_airports.dart';
import 'sqflite_schools.dart';
import 'sqlite3_bookstore.dart';
import 'sqlite_async_weather.dart';

/// The five most-used SQL packages in the Flutter ecosystem, each with its own
/// dataset. Monthly downloads on pub.dev as of August 2026:
///
/// | Package              | Downloads/30d |
/// | -------------------- | ------------- |
/// | `sqflite`            | 2.75M         |
/// | `sqlite3`            | 2.22M         |
/// | `drift`              | 1.14M         |
/// | `sqlite_async`       | 418k          |
/// | `sqflite_common_ffi` | 246k          |
///
/// Other supported packages are documented in the README but left out here:
/// `drift_sqflite` and `floor` are declining, `powersync` is `sqlite_async`
/// underneath, `sembast_sqflite` stores JSON blobs rather than columns, and
/// `sqflite_sqlcipher` bundles a native SQLite that clashes with the `sqflite`
/// plugin inside one app.
List<DemoDatabase> buildDemoDatabases() => [
      SqfliteSchools(),
      Sqlite3Bookstore(),
      DriftMusic(),
      SqliteAsyncWeather(),
      SqfliteFfiAirports(),
    ];
