import 'dart:ui' show Rect;

/// Where a finished export should end up.
///
/// Every export is staged in a private temp directory first; the destination
/// only decides what happens to those staged files afterwards.
sealed class ExportDestination {
  const ExportDestination();

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
