import 'package:db_exporter/db_exporter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../demo_database.dart';

/// `package:sqlite3` holding a **Bookstore** dataset.
///
/// This is the synchronous, no-plugin path — `sqlite3_flutter_libs` supplies
/// the native library. `sqlite_async` and `powersync` wire up the same way,
/// with `getAll` in place of `select`.
class Sqlite3Bookstore extends DemoDatabase {
  Database? _db;
  String? _path;

  @override
  String get package => 'sqlite3';

  @override
  String get dataset => 'Bookstore';

  @override
  String get wiring => 'query: db.select(), execute: db.execute';

  @override
  List<String> get tables => const ['books', 'orders'];

  @override
  Future<void> open() async {
    if (_db != null) return;
    final directory = await getApplicationDocumentsDirectory();
    _path = p.join(directory.path, 'bookstore.db');
    final database = sqlite3.open(_path!);

    database.execute('''
      CREATE TABLE IF NOT EXISTS books (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        isbn TEXT NOT NULL,
        price REAL NOT NULL,
        in_stock INTEGER NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY,
        book_id INTEGER NOT NULL REFERENCES books(id),
        quantity INTEGER NOT NULL,
        customer TEXT NOT NULL,
        ordered_on TEXT NOT NULL
      )
    ''');

    final count = database.select('SELECT COUNT(*) AS total FROM books');
    if ((count.first['total']! as int) == 0) {
      const books = [
        ['The Hobbit', 'J.R.R. Tolkien', '9780261102217', 12.99, 34],
        ['Midnight\'s Children', 'Salman Rushdie', '9780099578512', 15.50, 12],
        ['Things Fall Apart', 'Chinua Achebe', '9780385474542', 10.25, 47],
        ['The Left Hand of Darkness', 'Ursula K. Le Guin', '9780441478125',
          13.75, 21],
        ['Norwegian Wood', 'Haruki Murakami', '9780099448822', 11.40, 8],
      ];
      for (final book in books) {
        database.execute(
          'INSERT INTO books (title, author, isbn, price, in_stock) '
          'VALUES (?, ?, ?, ?, ?)',
          book,
        );
      }

      const orders = [
        [1, 2, 'A. Sharma', '2026-08-01'],
        [3, 1, 'L. Okonkwo', '2026-08-04'],
        [2, 5, 'R. Patel', '2026-08-09'],
        [5, 1, 'M. Tanaka', '2026-08-15'],
      ];
      for (final order in orders) {
        database.execute(
          'INSERT INTO orders (book_id, quantity, customer, ordered_on) '
          'VALUES (?, ?, ?, ?)',
          order,
        );
      }
    }
    _db = database;
  }

  @override
  DbSource get source => DbSource(
        databasePath: _path,
        query: (sql) async =>
            _db!.select(sql).map<Map<String, Object?>>((r) => {...r}).toList(),
        execute: (sql) async => _db!.execute(sql),
      );

  @override
  Future<void> close() async {
    _db?.dispose();
    _db = null;
  }
}
