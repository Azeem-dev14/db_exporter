import 'package:db_exporter/db_exporter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../demo_database.dart';

/// sembast_sqflite holding a **Notes** dataset.
///
/// Included to show the caveat rather than a happy path. sembast is a document
/// store: it keeps every record as a JSON blob in one internal table, so the
/// export contains a `key`/`value` pair per note, not `title` and `body`
/// columns. Export it if you want the raw records; do not expect a schema.
class SembastNotes implements DemoDatabase {
  sqflite.Database? _db;
  String? _path;

  @override
  String get package => 'sembast_sqflite';

  @override
  String get dataset => 'Notes';

  @override
  String get wiring => 'read the underlying file with sqflite';

  @override
  List<String> get tables => const ['(sembast internal store)'];

  @override
  String get caveat =>
      'sembast stores each record as a JSON blob in one table. The export '
      'gives you key/value rows, not title/body columns.';

  @override
  Future<void> open() async {
    if (_db != null) return;
    final directory = await getApplicationDocumentsDirectory();
    _path = p.join(directory.path, 'notes.db');

    // Seed through sembast, then close it — the export reads the same file
    // through sqflite, since sembast exposes no SQL handle of its own.
    final factory = getDatabaseFactorySqflite(sqflite.databaseFactory);
    final sembastDb = await factory.openDatabase(_path!);
    final store = intMapStoreFactory.store('notes');
    if (await store.count(sembastDb) == 0) {
      await store.addAll(sembastDb, [
        {'title': 'Groceries', 'body': 'Coffee, rice, cinnamon', 'pinned': 1},
        {'title': 'Standup', 'body': 'Export flow demo at 10:30', 'pinned': 0},
        {'title': 'Reading', 'body': 'Finish the Le Guin chapter', 'pinned': 0},
      ]);
    }
    await sembastDb.close();

    _db = await sqflite.openDatabase(_path!);
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
