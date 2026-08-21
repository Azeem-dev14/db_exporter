import 'package:db_exporter/db_exporter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite_async/sqlite_async.dart';

import '../demo_database.dart';

/// sqlite_async holding a **Weather** dataset.
///
/// `powersync` wires up identically — it is built on this package.
class SqliteAsyncWeather implements DemoDatabase {
  SqliteDatabase? _db;
  String? _path;

  @override
  String get package => 'sqlite_async';

  @override
  String get dataset => 'Weather';

  @override
  String get wiring => 'query: db.getAll(), execute: db.execute';

  @override
  List<String> get tables => const ['stations', 'readings'];

  @override
  Future<void> open() async {
    if (_db != null) return;
    final directory = await getApplicationDocumentsDirectory();
    _path = p.join(directory.path, 'weather.db');
    final database = SqliteDatabase(path: _path!);

    await database.execute('''
      CREATE TABLE IF NOT EXISTS stations (
        id INTEGER PRIMARY KEY, code TEXT NOT NULL, name TEXT NOT NULL,
        latitude REAL NOT NULL, longitude REAL NOT NULL)
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS readings (
        id INTEGER PRIMARY KEY, station_id INTEGER NOT NULL,
        recorded_on TEXT NOT NULL, temp_c REAL NOT NULL,
        humidity INTEGER NOT NULL)
    ''');

    final existing = await database.getAll(
      'SELECT COUNT(*) AS total FROM stations',
    );
    if ((existing.first['total']! as int) == 0) {
      const stations = [
        ['VOBG', 'Bengaluru City', 12.97, 77.59],
        ['EGLL', 'Heathrow', 51.47, -0.45],
        ['NZSP', 'Amundsen-Scott', -90.0, 0.0],
        ['SBGL', 'Galeão', -22.81, -43.25],
      ];
      for (final station in stations) {
        await database.execute(
          'INSERT INTO stations (code, name, latitude, longitude) '
          'VALUES (?, ?, ?, ?)',
          station,
        );
      }
      const readings = [
        [1, '2026-08-20', 27.4, 68],
        [1, '2026-08-21', 26.1, 74],
        [2, '2026-08-20', 18.9, 61],
        [3, '2026-08-20', -58.3, 41],
        [4, '2026-08-21', 24.7, 79],
      ];
      for (final reading in readings) {
        await database.execute(
          'INSERT INTO readings (station_id, recorded_on, temp_c, humidity) '
          'VALUES (?, ?, ?, ?)',
          reading,
        );
      }
    }
    _db = database;
  }

  @override
  DbSource get source => DbSource(
        databasePath: _path,
        query: (sql) async => (await _db!.getAll(sql))
            .map<Map<String, Object?>>((r) => {...r})
            .toList(),
        execute: (sql) async => _db!.execute(sql),
      );

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  @override
  String get label => '$package — $dataset';
}
