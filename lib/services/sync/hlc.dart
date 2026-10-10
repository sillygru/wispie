import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hybrid logical clock.
///
/// A 64-bit value `(unix_millis << 16) | counter`. [now] returns a strictly
/// monotonic stamp even when the wall clock stands still or jumps backwards;
/// [observe] folds a remote clock in so this device never issues a stamp that
/// looks older than data it has already seen. The last value is persisted so
/// monotonicity survives restarts.
class Hlc {
  Hlc._();
  static final Hlc instance = Hlc._();

  static const String _prefsKey = 'sync_hlc_last';

  int _last = 0;
  bool _loaded = false;

  int get last => _last;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _last = prefs.getInt(_prefsKey) ?? 0;
    _loaded = true;
  }

  /// A fresh, strictly increasing stamp for a local write.
  int now() {
    final wall = DateTime.now().millisecondsSinceEpoch << 16;
    final next = wall > _last ? wall : _last + 1;
    _last = next;
    _persist();
    return next;
  }

  /// Fold in a clock seen on an incoming record so later local stamps dominate.
  void observe(int remote) {
    if (remote > _last) {
      _last = remote;
      _persist();
    }
  }

  void _persist() {
    final value = _last;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setInt(_prefsKey, value));
  }

  @visibleForTesting
  void resetForTest([int value = 0]) {
    _last = value;
    _loaded = true;
  }
}
