import 'dart:io';

import 'package:db_exporter/db_exporter.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../demo_database.dart';
import 'drift_support.dart';

/// Drift on a native executor, holding a **Music** dataset.
class DriftMusic extends DemoDatabase {
  NoCodegenDatabase? _db;
  String? _path;

  @override
  String get package => 'drift';

  @override
  String get dataset => 'Music';

  @override
  String get wiring => 'customSelect().get() + customStatement';

  @override
  List<String> get tables => const ['artists', 'albums', 'tracks'];

  @override
  Future<void> open() async {
    if (_db != null) return;
    final directory = await getApplicationDocumentsDirectory();
    _path = p.join(directory.path, 'music.sqlite');
    final database = NoCodegenDatabase(NativeDatabase(File(_path!)));

    await database.createAndSeed(
      probeTable: 'artists',
      statements: const [
        '''
        CREATE TABLE IF NOT EXISTS artists (
          id INTEGER PRIMARY KEY, name TEXT NOT NULL,
          genre TEXT NOT NULL, country TEXT NOT NULL)
        ''',
        '''
        CREATE TABLE IF NOT EXISTS albums (
          id INTEGER PRIMARY KEY, title TEXT NOT NULL,
          artist_id INTEGER NOT NULL, released INTEGER NOT NULL)
        ''',
        '''
        CREATE TABLE IF NOT EXISTS tracks (
          id INTEGER PRIMARY KEY, title TEXT NOT NULL,
          album_id INTEGER NOT NULL, duration_sec INTEGER NOT NULL,
          rating REAL NOT NULL)
        ''',
      ],
      seed: () async {
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
            'INSERT INTO albums (title, artist_id, released) '
            'VALUES (?, ?, ?)',
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
      },
    );
    _db = database;
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
