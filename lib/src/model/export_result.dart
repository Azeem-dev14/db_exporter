import 'dart:io';

import 'package:path/path.dart' as p;

import 'export_format.dart';

/// A single file produced by an export.
class ExportedFile {
  const ExportedFile({
    required this.file,
    required this.name,
    required this.sizeInBytes,
    this.table,
  });

  final File file;
  final String name;
  final int sizeInBytes;

  /// The source table, for formats that emit one file per table.
  final String? table;

  /// Describes a file an exporter just wrote, reading its size once.
  ///
  /// Custom `TabularExporter` implementations use this to build their return
  /// value without duplicating the size and basename bookkeeping.
  static Future<ExportedFile> fromFile(File file, {String? table}) async =>
      ExportedFile(
        file: file,
        name: p.basename(file.path),
        sizeInBytes: await file.length(),
        table: table,
      );

  String get path => file.path;
}

/// The outcome of an export.
class ExportResult {
  const ExportResult({
    required this.format,
    required this.files,
    required this.tables,
    required this.totalRows,
    required this.duration,
    this.deliveredPath,
    this.userCancelled = false,
  });

  final ExportFormat format;
  final List<ExportedFile> files;

  /// Tables actually included, after filtering.
  final List<String> tables;
  final int totalRows;
  final Duration duration;

  /// Where the file finally landed, when the destination reports a path.
  ///
  /// Null for the share sheet, which does not tell us what the user picked.
  final String? deliveredPath;

  /// True when the user dismissed a save-as dialog without choosing.
  final bool userCancelled;

  ExportedFile get single {
    if (files.length != 1) {
      throw StateError(
        'Expected exactly one file but got ${files.length}. '
        'Use `files` for multi-file formats such as CSV.',
      );
    }
    return files.first;
  }

  int get totalSizeInBytes =>
      files.fold(0, (sum, file) => sum + file.sizeInBytes);
}
