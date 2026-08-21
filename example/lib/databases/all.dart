import '../demo_database.dart';
import 'drift_music.dart';
import 'drift_sqflite_recipes.dart';
import 'sembast_notes.dart';
import 'sqflite_ffi_airports.dart';
import 'sqflite_schools.dart';
import 'sqlite3_bookstore.dart';
import 'sqlite_async_weather.dart';

/// Every storage package the example demonstrates, each with its own dataset.
///
/// Two supported packages are deliberately absent:
///
/// - **floor** needs `build_runner` to generate its database class, which the
///   example avoids. Its wiring is `db.database.rawQuery` / `.execute`.
/// - **sqflite_sqlcipher** ships its own native SQLite, which clashes with the
///   plain `sqflite` plugin when both are in one app. Its wiring is identical
///   to sqflite — and note that exports come out **plaintext**.
List<DemoDatabase> buildDemoDatabases() => [
      SqfliteSchools(),
      SqfliteFfiAirports(),
      DriftMusic(),
      DriftSqfliteRecipes(),
      Sqlite3Bookstore(),
      SqliteAsyncWeather(),
      SembastNotes(),
    ];
