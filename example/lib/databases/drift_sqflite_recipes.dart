import 'package:db_exporter/db_exporter.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import '../demo_database.dart';
import 'drift_support.dart';

/// Drift running on a sqflite executor, holding a **Recipes** dataset.
///
/// The wiring is byte-for-byte the same as plain drift — only the executor
/// differs, which is the point of this demo.
class DriftSqfliteRecipes implements DemoDatabase {
  NoCodegenDatabase? _db;
  String? _path;

  @override
  String get package => 'drift_sqflite';

  @override
  String get dataset => 'Recipes';

  @override
  String get wiring => 'same as drift — only the executor differs';

  @override
  List<String> get tables => const ['recipes', 'ingredients'];

  @override
  Future<void> open() async {
    if (_db != null) return;
    _path = p.join(await getDatabasesPath(), 'recipes.db');
    final database = NoCodegenDatabase(
      SqfliteQueryExecutor(path: _path!, singleInstance: true),
    );

    await database.createAndSeed(
      probeTable: 'recipes',
      statements: const [
        '''
        CREATE TABLE IF NOT EXISTS recipes (
          id INTEGER PRIMARY KEY, name TEXT NOT NULL,
          cuisine TEXT NOT NULL, minutes INTEGER NOT NULL,
          servings INTEGER NOT NULL)
        ''',
        '''
        CREATE TABLE IF NOT EXISTS ingredients (
          id INTEGER PRIMARY KEY, recipe_id INTEGER NOT NULL,
          item TEXT NOT NULL, quantity TEXT NOT NULL)
        ''',
      ],
      seed: () async {
        const recipes = [
          ['Masala Dosa', 'South Indian', 45, 4],
          ['Ramen Shoyu', 'Japanese', 180, 2],
          ['Ratatouille', 'French', 60, 6],
          ['Shakshuka', 'North African', 30, 3],
        ];
        for (final recipe in recipes) {
          await database.customStatement(
            'INSERT INTO recipes (name, cuisine, minutes, servings) '
            'VALUES (?, ?, ?, ?)',
            recipe,
          );
        }
        const ingredients = [
          [1, 'Rice', '2 cups'],
          [1, 'Urad dal', '1/2 cup'],
          [2, 'Pork belly', '400 g'],
          [2, 'Soy sauce', '80 ml'],
          [3, 'Aubergine', '2 medium'],
          [3, 'Courgette', '2 medium'],
          [4, 'Eggs', '6'],
          [4, 'Tomatoes', '5 large'],
        ];
        for (final ingredient in ingredients) {
          await database.customStatement(
            'INSERT INTO ingredients (recipe_id, item, quantity) '
            'VALUES (?, ?, ?)',
            ingredient,
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
