import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'debug_sandbox.dart';

@visibleForTesting
String? testWispiePath;

Future<Directory> getWispieDirectory() async {
  if (testWispiePath != null) {
    final dir = Directory(testWispiePath!);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
  final docDir = await getApplicationDocumentsDirectory();
  if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
    return DebugSandbox.redirect('documents', docDir);
  }
  final dir = Directory('${docDir.path}/wispie');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return DebugSandbox.redirect('wispie', dir);
}

/// Where user-owned files live (backups, music the user drops in).
///
/// Android uses the public `wispie` folder in shared storage so backups survive
/// an uninstall; every other platform keeps its existing app-private folder.
Future<Directory> getWispieHomeDirectory() async {
  if (testWispiePath != null) return getWispieDirectory();
  if (Platform.isAndroid) {
    final public = await _androidPublicWispieDirectory();
    if (public != null) return public;
  }
  return getWispieDirectory();
}

/// The `songs` folder inside [getWispieHomeDirectory], Android only.
///
/// Created empty so a user has somewhere to drop music that the scanner can
/// then pick up; null elsewhere, where music folders are chosen by the user.
Future<Directory?> ensureWispieSongsDirectory() async {
  if (testWispiePath != null || !Platform.isAndroid) return null;
  final home = await getWispieHomeDirectory();
  final dir = Directory(p.join(home.path, 'songs'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<Directory?> _androidPublicWispieDirectory() async {
  try {
    final external = await getExternalStorageDirectory();
    if (external == null) return null;
    final marker = external.path.indexOf('/Android/');
    if (marker <= 0) return null;
    final dir = Directory(p.join(external.path.substring(0, marker), 'wispie'));
    if (!await dir.exists()) await dir.create(recursive: true);

    // Without all-files access the folder is not writable; fall back rather
    // than failing every backup write later.
    final probe = File(p.join(dir.path, '.wispie_probe'));
    await probe.writeAsString('ok', flush: true);
    await probe.delete();
    return dir;
  } catch (_) {
    return null;
  }
}
