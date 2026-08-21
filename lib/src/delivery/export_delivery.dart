import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../model/export_destination.dart';
import 'device_folder.dart';
import '../model/export_exception.dart';
import '../model/export_format.dart';
import '../model/export_result.dart';

/// The outcome of moving staged files to their destination.
class DeliveryOutcome {
  const DeliveryOutcome({
    required this.files,
    this.path,
    this.cancelled = false,
  });

  /// Files as they exist after delivery — paths may have changed.
  final List<ExportedFile> files;

  /// Final location, when the destination can report one.
  final String? path;

  /// True when the user dismissed a save or share dialog.
  final bool cancelled;
}

/// Moves staged export files to wherever the caller asked for them.
///
/// Kept separate from the exporters so "what format" and "where does it go"
/// stay independent; otherwise the combinations multiply.
abstract final class ExportDelivery {
  static Future<DeliveryOutcome> deliver({
    required List<ExportedFile> files,
    required ExportDestination destination,
    required ExportFormat format,
  }) async {
    if (files.isEmpty) {
      throw const DbExportException('Nothing to deliver: no files produced.');
    }
    return switch (destination) {
      final DeviceFolderDestination d => _toDeviceFolder(files, d),
      final AppDirectoryDestination d => _toAppDirectory(files, d),
      final DirectoryDestination d => _toDirectory(files, d),
      final ShareDestination d => _toShareSheet(files, d, format),
      final SaveAsDestination d => _toSaveDialog(files, d, format),
    };
  }

  static Future<DeliveryOutcome> _toAppDirectory(
    List<ExportedFile> files,
    AppDirectoryDestination destination,
  ) async {
    final root = destination.temporary
        ? await getTemporaryDirectory()
        : await getApplicationDocumentsDirectory();
    final target = Directory(p.join(root.path, destination.subdirectory));
    await target.create(recursive: true);
    return _moveAll(files, target);
  }

  /// Moves every staged file into [target], preserving their names.
  static Future<DeliveryOutcome> _moveAll(
    List<ExportedFile> files,
    Directory target,
  ) async {
    final moved = <ExportedFile>[];
    for (final exported in files) {
      final file = await _move(
        exported.file,
        p.join(target.path, exported.name),
      );
      moved.add(ExportedFile(
        file: file,
        name: exported.name,
        sizeInBytes: exported.sizeInBytes,
        table: exported.table,
      ));
    }
    return DeliveryOutcome(files: moved, path: target.path);
  }

  static Future<DeliveryOutcome> _toDeviceFolder(
    List<ExportedFile> files,
    DeviceFolderDestination destination,
  ) async {
    final target = await DeviceFolder.create(
      package: destination.packageName,
      name: destination.folderName,
    );
    return _moveAll(files, target);
  }

  static Future<DeliveryOutcome> _toDirectory(
    List<ExportedFile> files,
    DirectoryDestination destination,
  ) async {
    final target = Directory(destination.path);
    if (!await target.exists()) {
      if (!destination.createIfMissing) {
        throw DbExportException(
          'Directory does not exist: ${destination.path}. '
          'Pass createIfMissing: true to create it.',
        );
      }
      try {
        await target.create(recursive: true);
      } on FileSystemException catch (error) {
        // The usual cause on Android 10+ is scoped storage refusing a public
        // path such as /storage/emulated/0/Download.
        throw DbExportException(
          'Could not create ${destination.path}. On Android 10+ the public '
          'Downloads folder is not writable directly — use '
          'ExportDestination.saveAs() instead.',
          cause: error,
        );
      }
    }
    return _moveAll(files, target);
  }

  static Future<DeliveryOutcome> _toShareSheet(
    List<ExportedFile> files,
    ShareDestination destination,
    ExportFormat format,
  ) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          for (final exported in files)
            XFile(exported.path, mimeType: format.mimeType),
        ],
        subject: destination.subject,
        text: destination.text,
        sharePositionOrigin: destination.sharePositionOrigin,
      ),
    );
    // The share sheet never reports where the file went, only whether the user
    // picked a target at all.
    return DeliveryOutcome(
      files: files,
      cancelled: result.status == ShareResultStatus.dismissed,
    );
  }

  static Future<DeliveryOutcome> _toSaveDialog(
    List<ExportedFile> files,
    SaveAsDestination destination,
    ExportFormat format,
  ) async {
    if (files.length > 1) {
      throw DbExportException(
        'ExportDestination.saveAs handles a single file, but a ${format.name} '
        'export produced ${files.length}. Use ExportDestination.share() or '
        'ExportDestination.appDirectory() for multi-table CSV exports.',
      );
    }

    final exported = files.single;
    try {
      final bytes = await exported.file.readAsBytes();
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: destination.dialogTitle ?? 'Save export',
        fileName: exported.name,
        bytes: bytes,
      );
      if (savedPath == null) {
        return DeliveryOutcome(files: files, cancelled: true);
      }
      // file_picker writes the bytes itself on Android and iOS; on desktop it
      // only returns the chosen path and leaves the writing to us.
      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(savedPath).writeAsBytes(bytes, flush: true);
      }
      return DeliveryOutcome(files: files, path: savedPath);
    } on Object catch (error, stackTrace) {
      if (Platform.isIOS && destination.iosFallbackToShare) {
        // iOS has no general-purpose save dialog; the share sheet's "Save to
        // Files" is the platform-idiomatic equivalent.
        return _toShareSheet(
          files,
          ShareDestination(
            sharePositionOrigin: destination.sharePositionOrigin,
          ),
          format,
        );
      }
      Error.throwWithStackTrace(
        DbExportException('Save dialog failed.', cause: error),
        stackTrace,
      );
    }
  }

  /// [File.rename] fails across filesystems — the temp directory and the app
  /// documents directory are not always on the same volume — so fall back to
  /// copy-then-delete.
  static Future<File> _move(File file, String targetPath) async {
    try {
      return await file.rename(targetPath);
    } on FileSystemException {
      final copy = await file.copy(targetPath);
      await file.delete();
      return copy;
    }
  }
}
