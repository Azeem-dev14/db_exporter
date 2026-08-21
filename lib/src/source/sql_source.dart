import '../model/export_exception.dart';
import '../model/table_data.dart';

/// Runs a SQL statement and returns the resulting rows as plain maps.
///
/// This callback is the entire contract between `db_exporter` and your storage
/// layer, which is why this package depends on neither drift nor sqflite.
typedef RawQuery = Future<List<Map<String, Object?>>> Function(String sql);

/// Runs a statement that returns no rows (`VACUUM`, `PRAGMA` writes).
///
/// Needed because drift's `customSelect` rejects non-SELECT statements, so the
/// query callback alone cannot run everything.
typedef RawExecute = Future<void> Function(String sql);

/// Tables SQLite and the common Flutter ORMs keep for themselves.
const _internalTables = <String>{
  'android_metadata',
  'sqlite_sequence',
  'sqlite_stat1',
  'sqlite_stat4',
};

/// A SQLite-backed database to read from.
///
/// Adapting an existing connection is a two-liner:
///
/// ```dart
/// // sqflite
/// SqlSource(
///   databasePath: db.path,
///   query: db.rawQuery,
///   execute: db.execute,
/// );
///
/// // drift
/// SqlSource(
///   databasePath: file.path,
///   query: (sql) async =>
///       (await db.customSelect(sql).get()).map((row) => row.data).toList(),
///   execute: db.customStatement,
/// );
/// ```
class SqlSource {
  SqlSource({
    required this.query,
    this.execute,
    this.databasePath,
    this.includeInternalTables = false,
  });

  final RawQuery query;

  /// Optional statement runner. Without it, `VACUUM INTO` cannot be used and
  /// raw database exports silently fall back to checkpoint-and-copy.
  final RawExecute? execute;

  /// Absolute path to the `.db` file.
  ///
  /// Required only for `ExportFormat.rawDatabase`.
  final String? databasePath;

  /// Include `sqlite_sequence`, `android_metadata` and friends.
  final bool includeInternalTables;

  /// Every user table in the database, alphabetically.
  Future<List<String>> tableNames() async {
    final rows = await query(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
      "ORDER BY name",
    );
    return rows
        .map((row) => row['name']! as String)
        .where((name) =>
            includeInternalTables || !_internalTables.contains(name))
        .toList(growable: false);
  }

  /// Column names for [table], in declaration order.
  Future<List<String>> columnNames(String table) async {
    final rows = await query('PRAGMA table_info(${quoteIdentifier(table)})');
    return rows.map((row) => row['name']! as String).toList(growable: false);
  }

  /// Reads a whole table, optionally capped at [maxRows].
  ///
  /// The cap exists because every text format here builds its rows in memory;
  /// a million-row table will exhaust the heap before it reaches the encoder.
  /// For datasets that large, export the raw database file instead.
  Future<TableData> readTable(String table, {int? maxRows}) async {
    final columns = await columnNames(table);
    if (columns.isEmpty) {
      throw DbExportException('Table "$table" does not exist.');
    }

    // Read one extra row so we can tell "exactly at the limit" from "cut off".
    final limit = maxRows == null ? '' : ' LIMIT ${maxRows + 1}';
    final rows = await query('SELECT * FROM ${quoteIdentifier(table)}$limit');

    final truncated = maxRows != null && rows.length > maxRows;
    return TableData(
      name: table,
      columns: columns,
      rows: truncated ? rows.sublist(0, maxRows) : rows,
      truncated: truncated,
    );
  }

  /// Flushes the write-ahead log back into the main database file.
  ///
  /// This is the step almost every hand-rolled "copy the .db file" backup
  /// misses. Drift and sqflite both run in WAL mode by default, so recent
  /// writes live in a sidecar `-wal` file; copying only the `.db` silently
  /// produces a backup missing them. `TRUNCATE` blocks until the log is fully
  /// applied and then empties it, which makes the `.db` file self-contained.
  ///
  /// Returns false when the database is not in WAL mode (nothing to do) or the
  /// checkpoint was blocked — never throws, because a failed checkpoint should
  /// degrade an export, not abort it.
  Future<bool> checkpointWal() async {
    try {
      final rows = await query('PRAGMA wal_checkpoint(TRUNCATE)');
      if (rows.isEmpty) return false;
      // Result columns are (busy, log, checkpointed); busy != 0 means readers
      // or writers prevented a full checkpoint.
      final row = rows.first;
      final busy = row['busy'] ?? row.values.first;
      return busy == 0;
    } on Object {
      return false;
    }
  }

  /// Runs a statement that produces no rows, using [execute] when available.
  Future<void> run(String sql) async {
    final runner = execute;
    if (runner != null) return runner(sql);
    await query(sql);
  }

  /// Double-quotes an identifier so table names with spaces, punctuation or
  /// reserved words survive interpolation.
  ///
  /// Table names come from `sqlite_master` or the caller, never from user
  /// input, but quoting is free and removes a whole class of surprise.
  static String quoteIdentifier(String identifier) =>
      '"${identifier.replaceAll('"', '""')}"';
}
