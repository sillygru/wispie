import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controls the display refresh rate hint for the player screen.
///
/// Requests 120 Hz during interaction and 60 Hz after two seconds of inactivity.
/// Android chooses an available rate; power saving disables the interaction boost.
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

  Future<void>? _initialization;
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

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
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
    if (_initialization == null) unawaited(initialize());
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
    _setHint(!_powerSave && (_boostTimer?.isActive ?? false)
        ? _interactionRate
        : _discreteFloor);
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
    _initialization = null;
    _variable = false;
  }
}
