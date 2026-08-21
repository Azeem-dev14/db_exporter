import 'package:drift/drift.dart';

/// A drift database with no generated code.
///
/// The example avoids a `build_runner` step, so both drift demos subclass
/// [GeneratedDatabase] directly and define their schema with
/// `customStatement`. A real app declares `@DriftDatabase(tables: [...])` —
/// **the db_exporter wiring is identical either way**, because it only ever
/// calls `customSelect` and `customStatement`.
class NoCodegenDatabase extends GeneratedDatabase {
  NoCodegenDatabase(super.executor);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  /// Runs [statements], then [seed] if [probeTable] is still empty.
  Future<void> createAndSeed({
    required List<String> statements,
    required String probeTable,
    required Future<void> Function() seed,
  }) async {
    for (final statement in statements) {
      await customStatement(statement);
    }
    final existing = await customSelect(
      'SELECT COUNT(*) AS total FROM $probeTable',
    ).getSingle();
    if ((existing.data['total']! as int) == 0) await seed();
  }
}
