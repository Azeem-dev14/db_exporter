import 'package:db_exporter/db_exporter.dart';

/// One demo database backed by a specific storage package.
///
/// Each implementation seeds a **different** dataset, so it is obvious in the
/// exported file which package produced it.
abstract class DemoDatabase {
  /// The storage package being demonstrated, e.g. `sqflite`.
  String get package;

  /// The dataset it holds, e.g. `Schools`.
  String get dataset;

  /// One line describing how `DbSource` is wired for this package.
  String get wiring;

  /// Tables the demo creates, for display.
  List<String> get tables;

  /// Opens and seeds the database. Safe to call more than once.
  Future<void> open();

  /// The adapter handed to [DbExporter].
  DbSource get source;

  Future<void> close();

  String get label => '$package — $dataset';
}
