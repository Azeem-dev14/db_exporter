import 'package:db_exporter/db_exporter.dart';

/// One demo database backed by a specific storage package.
///
/// Every implementation seeds a **different** dataset, so the exported file
/// makes it obvious which package produced it.
abstract class DemoDatabase {
  /// The storage package being demonstrated, e.g. `sqflite`.
  String get package;

  /// The dataset it holds, e.g. `Schools`.
  String get dataset;

  /// How `DbSource` is wired for this package.
  String get wiring;

  /// Tables the demo creates, for display.
  List<String> get tables;

  /// Anything the reader should know before exporting this one.
  String? get caveat => null;

  /// Opens and seeds the database. Safe to call more than once.
  Future<void> open();

  /// The adapter handed to [DbExporter].
  DbSource get source;

  Future<void> close();

  String get label => '$package — $dataset';
}
