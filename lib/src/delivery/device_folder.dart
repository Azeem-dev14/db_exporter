import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../model/export_exception.dart';

/// Resolves the shared `dbexports-<packageName>` folder used by
/// `ExportDestination.deviceFolder`.
abstract final class DeviceFolder {
  /// Prefix every export folder carries, so exports from different apps sit
  /// side by side and are obvious in a file manager.
  static const String prefix = 'dbexports';

  static String? _cachedPackageName;

  /// The app's package name (Android) or bundle identifier (iOS).
  static Future<String> packageName() async =>
      _cachedPackageName ??= (await PackageInfo.fromPlatform()).packageName;

  /// `dbexports-com.example.app`.
  static Future<String> folderName({String? package}) async =>
      '$prefix-${package ?? await packageName()}';

  /// The directory the export folder is created inside.
  ///
  /// - **Android:** the external storage root, `/storage/emulated/0`, derived
  ///   from the app-specific external path rather than hardcoded, so it stays
  ///   correct on devices that mount storage elsewhere.
  /// - **iOS:** the app documents directory. iOS has no device-wide directory
  ///   and no permission grants one; documents is the closest equivalent and
  ///   is visible in the Files app when the app opts in.
  /// - **Desktop:** the user's home directory.
  static Future<Directory> root() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external == null) {
        throw const DbExportException(
          'No external storage available on this device.',
        );
      }
      // /storage/emulated/0/Android/data/<pkg>/files -> /storage/emulated/0
      final marker = '${p.separator}Android${p.separator}';
      final index = external.path.indexOf(marker);
      return index == -1
          ? external
          : Directory(external.path.substring(0, index));
    }

    if (Platform.isIOS) return getApplicationDocumentsDirectory();

    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) return Directory(home);
    return getApplicationDocumentsDirectory();
  }

  /// Full path of the export folder, without creating it.
  static Future<Directory> resolve({String? package, String? name}) async {
    final base = await root();
    return Directory(
      p.join(base.path, name ?? await folderName(package: package)),
    );
  }

  /// Creates the export folder, translating a denied write into an error that
  /// says what to do about it.
  static Future<Directory> create({String? package, String? name}) async {
    final target = await resolve(package: package, name: name);
    if (await target.exists()) return target;
    try {
      return await target.create(recursive: true);
    } on FileSystemException catch (error) {
      throw DbExportException(_permissionMessage(target.path), cause: error);
    }
  }

  static String _permissionMessage(String path) {
    if (Platform.isAndroid) {
      return 'Cannot create $path — storage permission was not granted.\n\n'
          'Writing to the device root needs All files access on Android 11+:\n'
          '  1. AndroidManifest.xml:\n'
          '     <uses-permission android:name='
          '"android.permission.MANAGE_EXTERNAL_STORAGE" />\n'
          '  2. Send the user to Settings > Apps > your app > '
          'All files access and have them enable it.\n\n'
          'Google Play restricts that permission to file managers and backup '
          'apps. If your app is not one, use '
          'ExportDestination.saveAs() (Storage Access Framework, no '
          'permission) or ExportDestination.appDirectory().';
    }
    if (Platform.isIOS) {
      return 'Cannot create $path. iOS sandboxes every app and grants no '
          'device-wide directory, so exports must stay in the app documents '
          'directory. Use ExportDestination.share() to hand the file to the '
          'Files app instead.';
    }
    return 'Cannot create $path — the directory could not be written. '
        'Check that the path exists and is writable.';
  }
}
