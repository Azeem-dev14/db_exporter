import 'dart:ui' show Rect;

/// Where a finished export should end up.
///
/// Every export is staged in a private temp directory first; the destination
/// only decides what happens to those staged files afterwards.
sealed class ExportDestination {
  const ExportDestination();

  /// Write to `dbexports-<packageName>` in the device's main directory.
  ///
  /// This is the default. The folder is created on first use, and the package
  /// name is read from the platform, so exports from different apps sit side
  /// by side and are obvious in a file manager:
  ///
  /// ```text
  /// /storage/emulated/0/dbexports-com.example.myapp/myapp_20260822_143001.xlsx
  /// ```
  ///
  /// Where the folder lands per platform:
  ///
  /// | Platform | Parent directory |
  /// | --- | --- |
  /// | Android | `/storage/emulated/0` (external storage root) |
  /// | iOS | app documents directory |
  /// | Desktop | the user's home directory |
  ///
  /// **Android 11+ needs `MANAGE_EXTERNAL_STORAGE` for this.** Scoped storage
  /// denies writes to the external storage root without it, and Google Play
  /// restricts that permission to file managers and backup apps. When the
  /// write is denied, this throws `DbExportException` with the manifest entry
  /// and the alternatives spelled out. If your app is not one Play will
  /// approve, prefer [ExportDestination.saveAs].
  ///
  /// **iOS has no device-wide directory** and no permission that grants one,
  /// so the folder is created under app documents instead.
  const factory ExportDestination.deviceFolder({
    String? packageName,
    String? folderName,
  }) = DeviceFolderDestination;

  /// Keep the file inside the app sandbox and just return the path.
  ///
  /// No permissions, no UI, works in tests and background jobs. Use this when
  /// the next step is your own code — an upload, a mail attachment, a
  /// scheduled backup — rather than the user.
  ///
  /// With [AppDirectoryDestination.temporary] the file lands in the cache
  /// directory, which the OS may reclaim at any time; otherwise it goes to the
  /// application documents directory.
  const factory ExportDestination.appDirectory({
    bool temporary,
    String subdirectory,
  }) = AppDirectoryDestination;

  /// Hand the file to the OS share sheet.
  ///
  /// This is also the idiomatic "save to Files" path on iOS — the system sheet
  /// already offers a Files destination, so a separate save dialog is not
  /// needed there.
  ///
  /// On iPad, always pass [ShareDestination.sharePositionOrigin]: UIKit
  /// anchors the popover to it, and omitting it throws at runtime on some iOS
  /// versions.
  const factory ExportDestination.share({
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
  }) = ShareDestination;

  /// Write to a directory you name, creating it if it does not exist.
  ///
  /// Use this for desktop, for Android's app-specific external directory, or
  /// for a subfolder of the sandbox you manage yourself.
  ///
  /// **This is not a way onto Android's public Downloads folder.** Since
  /// Android 10 (API 29), scoped storage denies writes to
  /// `/storage/emulated/0/Download` regardless of manifest permissions, unless
  /// the app holds `MANAGE_EXTERNAL_STORAGE` — which Play Store rejects for
  /// most apps. Use [ExportDestination.saveAs] instead: the Storage Access
  /// Framework writes there with no permission at all.
  ///
  /// Resolve the path with `path_provider` rather than hardcoding it:
  ///
  /// ```dart
  /// // Android: /storage/emulated/0/Android/data/<pkg>/files/exports
  /// //   — writable with no permission, visible over USB.
  /// final root = await getExternalStorageDirectory();
  ///
  /// // Desktop: the real Downloads folder. Null on Android and iOS.
  /// final downloads = await getDownloadsDirectory();
  ///
  /// destination: ExportDestination.directory('${root!.path}/exports');
  /// ```
  const factory ExportDestination.directory(
    String path, {
    bool createIfMissing,
  }) = DirectoryDestination;

  /// Show a native save dialog and let the user pick the location.
  ///
  /// On Android this goes through the Storage Access Framework, so it writes
  /// outside the sandbox with no storage permission at all. iOS has no
  /// general-purpose save dialog, so this falls back to the share sheet unless
  /// [SaveAsDestination.iosFallbackToShare] is false.
  ///
  /// Handles a single file only — CSV exports of several tables must use
  /// [ExportDestination.share] or [ExportDestination.appDirectory].
  const factory ExportDestination.saveAs({
    String? dialogTitle,
    bool iosFallbackToShare,
    Rect? sharePositionOrigin,
  }) = SaveAsDestination;
}

/// See [ExportDestination.appDirectory].
final class AppDirectoryDestination extends ExportDestination {
  const AppDirectoryDestination({
    this.temporary = false,
    this.subdirectory = 'exports',
  });

  /// Write to the cache directory instead of documents.
  final bool temporary;

  /// Folder created under the chosen root.
  final String subdirectory;
}

/// See [ExportDestination.deviceFolder].
final class DeviceFolderDestination extends ExportDestination {
  const DeviceFolderDestination({this.packageName, this.folderName});

  /// Override the detected package name, mostly for tests.
  final String? packageName;

  /// Replace the whole folder name, dropping the `dbexports-` convention.
  final String? folderName;
}

/// See [ExportDestination.directory].
final class DirectoryDestination extends ExportDestination {
  const DirectoryDestination(this.path, {this.createIfMissing = true});

  /// Absolute path of the directory to write into.
  final String path;

  /// Create the directory, and any missing parents, when it is absent.
  ///
  /// With this false, exporting to a missing directory throws
  /// `DbExportException` rather than creating it.
  final bool createIfMissing;
}

/// See [ExportDestination.share].
final class ShareDestination extends ExportDestination {
  const ShareDestination({
    this.subject,
    this.text,
    this.sharePositionOrigin,
  });

  /// Subject line, used by mail targets.
  final String? subject;

  /// Message body accompanying the attachment.
  final String? text;

  /// Anchor rect for the iPad popover. Required on iPad.
  final Rect? sharePositionOrigin;
}

/// See [ExportDestination.saveAs].
final class SaveAsDestination extends ExportDestination {
  const SaveAsDestination({
    this.dialogTitle,
    this.iosFallbackToShare = true,
    this.sharePositionOrigin,
  });

  /// Title shown on the system dialog.
  final String? dialogTitle;

  /// Use the share sheet on iOS, which has no save dialog of its own.
  final bool iosFallbackToShare;

  /// Anchor rect forwarded to the iOS share fallback.
  final Rect? sharePositionOrigin;
}
