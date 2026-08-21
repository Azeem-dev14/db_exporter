import 'package:db_exporter/db_exporter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../demo_database.dart';

/// sqflite_common_ffi holding an **Airports** dataset.
///
/// Same `Database` API as sqflite, backed by the FFI implementation instead of
/// the platform plugin — so the `DbSource` wiring is unchanged.
class SqfliteFfiAirports implements DemoDatabase {
  Database? _db;

  @override
  String get package => 'sqflite_common_ffi';

  @override
  String get dataset => 'Airports';

  @override
  String get wiring => 'same as sqflite — rawQuery + execute';

  @override
  List<String> get tables => const ['airports', 'flights'];

  @override
  Future<void> open() async {
    if (_db != null) return;
    sqfliteFfiInit();
    final directory = await getApplicationDocumentsDirectory();
    _db = await databaseFactoryFfi.openDatabase(
      p.join(directory.path, 'airports.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE airports (
              id INTEGER PRIMARY KEY, iata TEXT NOT NULL, name TEXT NOT NULL,
              city TEXT NOT NULL, elevation_m INTEGER NOT NULL)
          ''');
          await db.execute('''
            CREATE TABLE flights (
              id INTEGER PRIMARY KEY, flight_no TEXT NOT NULL,
              origin_id INTEGER NOT NULL, destination_id INTEGER NOT NULL,
              minutes INTEGER NOT NULL)
          ''');

          const airports = [
            ['BLR', 'Kempegowda International', 'Bengaluru', 900],
            ['SIN', 'Changi', 'Singapore', 7],
            ['AMS', 'Schiphol', 'Amsterdam', -3],
            ['LIM', 'Jorge Chávez', 'Lima', 34],
            ['ADD', 'Bole International', 'Addis Ababa', 2334],
          ];
          for (final airport in airports) {
            await db.insert('airports', {
              'iata': airport[0],
              'name': airport[1],
              'city': airport[2],
              'elevation_m': airport[3],
            });
          }
          const flights = [
            ['AI2841', 1, 2, 265],
            ['KL836', 2, 3, 780],
            ['ET687', 3, 5, 435],
            ['LA2470', 5, 4, 1010],
          ];
          for (final flight in flights) {
            await db.insert('flights', {
              'flight_no': flight[0],
              'origin_id': flight[1],
              'destination_id': flight[2],
              'minutes': flight[3],
            });
          }
        },
      ),
    );
  }

  @override
  DbSource get source => DbSource(
        databasePath: _db!.path,
        query: _db!.rawQuery,
        execute: _db!.execute,
      );

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  @override
  String get label => '$package — $dataset';
}
