import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/export_exception.dart';
import '../model/export_format.dart';
import '../model/export_result.dart';
import '../source/db_source.dart';
import '../util/file_naming.dart';

/// How to obtain a consistent copy of a live SQLite file.
enum RawCopyStrategy {
  /// `VACUUM INTO '<target>'` — SQLite's own snapshot mechanism (3.27+).
  ///
  /// It runs inside a read transaction, so the result is guaranteed
  /// transactionally consistent even while the app keeps writing, and the copy
  /// comes out defragmented and usually smaller. This is the correct way to
  /// back up an open database, and it is what almost every hand-rolled
  /// `File.copy` backup gets wrong.
  ///
  /// Requires `DbSource.execute`; without it, and on SQLite builds older than
  /// 3.27, this silently falls back to [fileCopy].
  vacuumInto,

  /// Checkpoint the WAL, then copy the file bytes.
  ///
  /// Use when `VACUUM INTO` is unavailable or when you need the copy to be
  /// byte-identical rather than vacuumed. The caller is responsible for making
  /// sure nothing writes during the copy.
  fileCopy,
}

/// Exports the SQLite file itself — the only format that round-trips back into
/// Drift or sqflite unchanged.
class RawDatabaseExporter {
  const RawDatabaseExporter({
    this.strategy = RawCopyStrategy.vacuumInto,
    this.includeWalFiles = false,
  });

  final RawCopyStrategy strategy;

  /// Also copy the `-wal` and `-shm` sidecars, when they exist.
  ///
  /// Rarely needed: both strategies fold the log into the main file first, so
  /// the sidecars should be empty by the time we copy. Kept for forensic
  /// exports where you want the on-disk state verbatim.
  final bool includeWalFiles;

  ExportFormat get format => ExportFormat.rawDatabase;

  Future<List<ExportedFile>> write({
    required DbSource source,
    required Directory stagingDirectory,
    required String baseName,
  }) async {
    final sourcePath = source.databasePath;
    if (sourcePath == null) {
      throw const DbExportException(
        'ExportFormat.rawDatabase needs DbSource.databasePath. '
        'Pass the path of the .db file when constructing DbSource.',
      );
    }
    if (!await File(sourcePath).exists()) {
      throw DbExportException('Database file not found at $sourcePath.');
    }

    final targetPath = p.join(
      stagingDirectory.path,
      FileNaming.build(
        base: baseName,
        extension: format.fileExtension,
        withTimestamp: false,
      ),
    );

    var copied = false;
    if (strategy == RawCopyStrategy.vacuumInto) {
      copied = await _vacuumInto(source, targetPath);
    }
    if (!copied) {
      copied = await _copyBytes(source, sourcePath, targetPath);
    }
    if (!copied) {
      throw const DbExportException('Could not produce a database copy.');
    }

    final files = <ExportedFile>[await ExportedFile.fromFile(File(targetPath))];
    if (includeWalFiles) {
      for (final suffix in const ['-wal', '-shm']) {
        final sidecar = File('$sourcePath$suffix');
        if (!await sidecar.exists()) continue;
        final copy = await sidecar.copy('$targetPath$suffix');
        files.add(await ExportedFile.fromFile(copy));
      }
    }
    return files;
  }

  /// Returns false (rather than throwing) so the caller can fall back.
  Future<bool> _vacuumInto(DbSource source, String targetPath) async {
    // VACUUM INTO refuses to overwrite, and cannot run inside a transaction.
    final target = File(targetPath);
    if (await target.exists()) await target.delete();
    try {
      await source.run("VACUUM INTO '${targetPath.replaceAll("'", "''")}'");
      return await target.exists();
    } on Object {
      return false;
    }
  }

  Future<bool> _copyBytes(
    DbSource source,
    String sourcePath,
    String targetPath,
  ) async {
    await source.checkpointWal();
    await File(sourcePath).copy(targetPath);
    return true;
  }
}
