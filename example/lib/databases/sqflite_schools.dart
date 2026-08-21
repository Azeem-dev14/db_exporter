import 'package:db_exporter/db_exporter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../demo_database.dart';

/// sqflite holding a **Schools** dataset.
///
/// The same wiring works for `sqflite_common_ffi`, `sqflite_sqlcipher`,
/// `drift_sqflite` and `floor` — they all expose the sqflite `Database` API.
class SqfliteSchools implements DemoDatabase {
  Database? _db;

  @override
  String get package => 'sqflite';

  @override
  String get dataset => 'Schools';

  @override
  String get wiring => 'query: db.rawQuery, execute: db.execute';

  @override
  List<String> get tables => const ['schools', 'teachers'];

  @override
  Future<void> open() async {
    if (_db != null) return;
    final directory = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      p.join(directory.path, 'schools.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE schools (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            city TEXT NOT NULL,
            students INTEGER NOT NULL,
            founded INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE teachers (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            subject TEXT NOT NULL,
            school_id INTEGER NOT NULL REFERENCES schools(id)
          )
        ''');

        const schools = [
          ['Kendriya Vidyalaya', 'Bengaluru', 1240, 1963],
          ['St. Xavier\'s High', 'Mumbai', 980, 1869],
          ['Delhi Public School', 'New Delhi', 2100, 1949],
          ['Sacred Heart Convent', 'Chennai', 760, 1908],
        ];
        for (final school in schools) {
          await db.insert('schools', {
            'name': school[0],
            'city': school[1],
            'students': school[2],
            'founded': school[3],
          });
        }

        const teachers = [
          ['Meera Iyer', 'Mathematics', 1],
          ['Rahul Menon', 'Physics', 1],
          ['Anita Desai', 'Literature', 2],
          ['Joseph Fernandes', 'Chemistry', 2],
          ['Sunil Kapoor', 'History', 3],
          ['Fatima Sheikh', 'Biology', 4],
        ];
        for (final teacher in teachers) {
          await db.insert('teachers', {
            'name': teacher[0],
            'subject': teacher[1],
            'school_id': teacher[2],
          });
        }
      },
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
