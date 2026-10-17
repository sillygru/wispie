import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debug-build write isolation.
///
/// In debug builds, everything the app would persist (databases, JSON state,
/// caches, SharedPreferences) goes to a throwaway copy of the real data, so the
/// real library and settings are only ever read. The debug flags themselves
/// live in a plain file outside the sandbox so they survive restarts.
class DebugSandbox {
  DebugSandbox._();

  static const _flagsFile = 'wispie_debug_flags.json';

  static bool _active = false;
  static Directory? _root;
  static Map<String, Object?> _flags = {};

  /// True when writes are redirected to the sandbox copy.
  static bool get active => _active;

  static bool get persistWrites => _flags['persist_writes'] == true;

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _flagsFile));
  }

  /// Must run before anything touches storage.
  static Future<void> init() async {
    if (!kDebugMode) return;
    try {
      final f = await _file();
      if (f.existsSync()) {
        _flags = Map<String, Object?>.from(jsonDecode(await f.readAsString()));
      }
    } catch (_) {
      _flags = {};
    }
    if (persistWrites) return;

    _active = true;
    final real = await SharedPreferences.getInstance();
    final snapshot = <String, Object>{};
    for (final key in real.getKeys()) {
      final v = real.get(key);
      if (v != null) snapshot[key] = v;
    }
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(snapshot);

    final root = Directory(p.join(
      (await getTemporaryDirectory()).path,
      'wispie_debug_sandbox',
    ));
    if (root.existsSync()) root.deleteSync(recursive: true);
    root.createSync(recursive: true);
    _root = root;
  }

  static Future<void> setFlag(String key, bool value) async {
    _flags[key] = value;
    if (!kDebugMode) return;
    await (await _file()).writeAsString(jsonEncode(_flags));
  }

  /// Returns [real] itself when not sandboxed, otherwise a lazily created copy.
  static Directory redirect(String name, Directory real) {
    final root = _root;
    if (!_active || root == null) return real;
    final copy = Directory(p.join(root.path, name));
    if (!copy.existsSync()) {
      copy.createSync(recursive: true);
      if (real.existsSync()) _copyInto(real, copy);
    }
    return copy;
  }

  static void _copyInto(Directory from, Directory to) {
    for (final e in from.listSync(followLinks: false)) {
      final name = p.basename(e.path);
      if (e is Directory) {
        final sub = Directory(p.join(to.path, name))..createSync();
        _copyInto(e, sub);
      } else if (e is File) {
        try {
          e.copySync(p.join(to.path, name));
        } catch (_) {}
      }
    }
  }
}

/// Drop-in for `getApplicationSupportDirectory` that honours the sandbox.
Future<Directory> getSupportDirectory() async {
  final real = await getApplicationSupportDirectory();
  return DebugSandbox.redirect('support', real);
}
