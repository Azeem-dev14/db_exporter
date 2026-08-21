import 'dart:io';

import 'package:db_exporter/db_exporter.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../demo_database.dart';

/// Drift holding a **Music** dataset.
///
/// This demo subclasses [GeneratedDatabase] directly so the example needs no
/// build_runner step. A real app declares `@DriftDatabase(tables: [...])` and
/// lets drift generate the class — **the db_exporter wiring is identical
/// either way**, because it only ever calls `customSelect` and
/// `customStatement`.
class _MusicDatabase extends GeneratedDatabase {
  _MusicDatabase(super.executor);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

class DriftMusic implements DemoDatabase {
  _MusicDatabase? _db;
  String? _path;

  @override
  String get package => 'drift';

  @override
  String get dataset => 'Music';

  @override
  String get wiring => 'query: customSelect().get(), execute: customStatement';

  @override
  List<String> get tables => const ['artists', 'albums', 'tracks'];

  @override
  Future<void> open() async {
    if (_db != null) return;
    final directory = await getApplicationDocumentsDirectory();
    _path = p.join(directory.path, 'music.sqlite');
    final database = _MusicDatabase(NativeDatabase(File(_path!)));

    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS artists (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        genre TEXT NOT NULL,
        country TEXT NOT NULL
      )
    ''');
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS albums (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        artist_id INTEGER NOT NULL REFERENCES artists(id),
        released INTEGER NOT NULL
      )
    ''');
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS tracks (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        album_id INTEGER NOT NULL REFERENCES albums(id),
        duration_sec INTEGER NOT NULL,
        rating REAL NOT NULL
      )
    ''');

    final seeded = await database.customSelect(
      'SELECT COUNT(*) AS total FROM artists',
    ).getSingle();
    if ((seeded.data['total']! as int) == 0) {
      await _seed(database);
    }
    _db = database;
  }

  Future<void> _seed(_MusicDatabase database) async {
    const artists = [
      ['Miles Davis', 'Jazz', 'United States'],
      ['Nina Simone', 'Soul', 'United States'],
      ['Fela Kuti', 'Afrobeat', 'Nigeria'],
      ['Zakir Hussain', 'Hindustani Classical', 'India'],
    ];
    for (final artist in artists) {
      await database.customStatement(
        'INSERT INTO artists (name, genre, country) VALUES (?, ?, ?)',
        artist,
      );
    }

    const albums = [
      ['Kind of Blue', 1, 1959],
      ['Bitches Brew', 1, 1970],
      ['I Put a Spell on You', 2, 1965],
      ['Zombie', 3, 1976],
      ['Making Music', 4, 1987],
    ];
    for (final album in albums) {
      await database.customStatement(
        'INSERT INTO albums (title, artist_id, released) VALUES (?, ?, ?)',
        album,
      );
    }

    const tracks = [
      ['So What', 1, 545, 4.9],
      ['Blue in Green', 1, 337, 4.7],
      ['Pharaoh\'s Dance', 2, 1200, 4.4],
      ['Feeling Good', 3, 175, 5.0],
      ['Zombie', 4, 727, 4.8],
      ['Water Girl', 5, 512, 4.6],
    ];
    for (final track in tracks) {
      await database.customStatement(
        'INSERT INTO tracks (title, album_id, duration_sec, rating) '
        'VALUES (?, ?, ?, ?)',
        track,
      );
    }
  }

  @override
  DbSource get source => DbSource(
        databasePath: _path,
        query: (sql) async =>
            (await _db!.customSelect(sql).get()).map((r) => r.data).toList(),
        execute: _db!.customStatement,
      );

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  @override
  String get label => '$package — $dataset';
}
