import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controls the display refresh rate hint for the player screen.
///
/// Panels come in two classes, and the difference is the whole point:
///
/// * Discrete (LTPS) — every rate is its own `Display.Mode`, so a rate the panel
///   does not have is never invented: 60/90/120 lands on 60, 90 or 120, and
///   nothing ever hints below 60. A sub-60 mode switch flickers the panel for no
///   visible win.
/// * Variable (LTPO) — the panel interpolates, so at rest the hint is released
///   and the system runs its own 1-120 range. Only an interaction pins a rate.
///
/// Policy: 120 while scrolling/dragging (boost window 2s); otherwise 60 on a
/// discrete panel and no pin at all on a variable one.
///
/// The native side may not be implemented (desktop, tests, old builds) — in that
/// case all calls are no-ops and the service still tracks state for tests.
class DisplayRefreshService {
  static const MethodChannel _channel = MethodChannel('wispie/display_refresh');

  static final DisplayRefreshService instance = DisplayRefreshService._();

  DisplayRefreshService._();

  /// Lowest rate hinted on a discrete panel: every panel we support has to
  /// switch modes below it, which is a flicker and not a saving.
  static const double _discreteFloor = 60;

  /// What an interaction asks for. The native side lands on the closest mode the
  /// panel actually has, so a 90Hz panel gets 90.
  static const double _interactionRate = 120;

  bool _initialized = false;
  double? _currentHint;
  Timer? _boostTimer;
  bool _inPlayer = false;
  bool _powerSave = false;

  /// True when the panel interpolates between rates (LTPO) instead of switching
  /// modes (LTPS).
  bool _variable = false;

  // Cached supported modes for diagnostics (filled lazily, never required).
  List<Map<String, dynamic>>? _supportedModes;

  bool get isVariableRefreshPanel => _variable;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final modes =
          await _channel.invokeMethod<List<dynamic>>('getSupportedModes');
      if (modes != null) {
        _supportedModes = modes.cast<Map<String, dynamic>>();
      }
      final info =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getPanelInfo');
      _variable = info?['kind'] == 'variable';
    } on MissingPluginException {
      // No native side — ignore.
    } catch (_) {}
  }

  List<Map<String, dynamic>>? get debugSupportedModes => _supportedModes;

  void enterPlayer({required bool powerSave}) {
    _inPlayer = true;
    _powerSave = powerSave;
    if (!_initialized) unawaited(initialize());
    _applyForState();
  }

  void leavePlayer() {
    _inPlayer = false;
    _boostTimer?.cancel();
    _boostTimer = null;
    _clear();
  }

  void onPlayingChanged(bool playing) {
    if (!_inPlayer) return;
    // Cancel boost if pausing — drop back to the floor immediately.
    if (!playing) {
      _boostTimer?.cancel();
      _boostTimer = null;
    }
    _applyForState();
  }

  void onPowerSaveChanged(bool powerSave) {
    _powerSave = powerSave;
    if (!_inPlayer) return;
    _applyForState();
  }

  /// Call on any scroll/drag/fling that deserves 120Hz.
  void boost120() {
    if (!_inPlayer) return;
    if (_powerSave) return; // Never boost in power save.
    _setHint(_interactionRate);
    _boostTimer?.cancel();
    _boostTimer = Timer(const Duration(seconds: 2), () {
      if (!_inPlayer) return;
      _applyForState();
    });
  }

  void _applyForState() {
    // A variable panel is never pinned at rest: the driver's own 1-120 ladder is
    // both cheaper and smoother than any hint from here.
    if (_variable) {
      _clearHint();
      return;
    }
    // Discrete panels hold their floor whether playing, paused or power-saving.
    // The old 30Hz idle hint was a mode switch, which is exactly what a panel
    // that can do 60 should not do.
    _setHint(_discreteFloor);
  }

  void _setHint(double hz) {
    if (_currentHint == hz) return;
    _currentHint = hz;
    _invokeSet(hz);
  }

  void _clearHint() {
    if (_currentHint == null) return;
    _currentHint = null;
    _invokeClear();
  }

  void _clear() {
    _boostTimer?.cancel();
    _boostTimer = null;
    _clearHint();
  }

  Future<void> _invokeSet(double hz) async {
    try {
      await _channel.invokeMethod('setPreferredRefreshRate', {'hz': hz});
    } on MissingPluginException {
      // No native implementation — ignore (tests, desktop, iOS handled via
      // CADisplayLink range which is set via Info.plist, not this channel).
    } catch (e) {
      debugPrint('DisplayRefreshService: set $hz failed: $e');
    }
  }

  Future<void> _invokeClear() async {
    try {
      await _channel.invokeMethod('clearPreferredRefreshRate');
    } on MissingPluginException {
      // Ignore.
    } catch (e) {
      debugPrint('DisplayRefreshService: clear failed: $e');
    }
  }

  @visibleForTesting
  double? get debugCurrentHint => _currentHint;

  @visibleForTesting
  void debugReset() {
    _inPlayer = false;
    _powerSave = false;
    _currentHint = null;
    _boostTimer?.cancel();
    _boostTimer = null;
    _initialized = false;
    _variable = false;
  }
}
