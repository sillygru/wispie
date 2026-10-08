import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class VolumeMonitorService {
  static const MethodChannel _channel = MethodChannel('wispie/volume');
  static const EventChannel _eventChannel =
      EventChannel('wispie/volume_events');

  StreamSubscription<double>? _volumeSubscription;
  double _currentVolume = 1.0;
  bool _isAutoPauseEnabled = false;
  Timer? _volumeZeroDebounceTimer;

  final VoidCallback? onVolumeZero;
  final VoidCallback? onVolumeRestored;

  VolumeMonitorService({
    this.onVolumeZero,
    this.onVolumeRestored,
  });

  Future<void> initialize() async {
    // The wispie/volume channels have native implementations only on mobile;
    // auto-pause-on-mute stays off elsewhere.
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    try {
      _currentVolume =
          await _channel.invokeMethod<double>('getCurrentVolume') ?? 1.0;
      _startVolumeMonitoring();
    } catch (e) {
      debugPrint('Failed to initialize volume monitoring: $e');
    }
  }

  void _startVolumeMonitoring() {
    _volumeSubscription = _eventChannel
        .receiveBroadcastStream()
        .map((event) => event as double)
        .listen(onVolumeChanged);
  }

  void onVolumeChanged(double volume) {
    final previousVolume = _currentVolume;
    _currentVolume = volume;

    if (!_isAutoPauseEnabled) return;

    // Use a small epsilon for floating point comparison
    const epsilon = 1e-6;

    // Check if volume changed to 0 (muted)
    if (previousVolume > epsilon && volume <= epsilon) {
      // Start debounce timer - only pause if volume stays at 0 for 500ms
      _volumeZeroDebounceTimer?.cancel();
      _volumeZeroDebounceTimer = Timer(
        const Duration(milliseconds: 500),
        () {
          _volumeZeroDebounceTimer = null;
          onVolumeZero?.call();
        },
      );
    }
    // Volume restored from 0: cancel any pending pause. Whether to resume is
    // decided by the owner, which knows if the pause actually came from mute.
    else if (previousVolume <= epsilon && volume > epsilon) {
      final hadPendingPause = _volumeZeroDebounceTimer != null;
      _volumeZeroDebounceTimer?.cancel();
      _volumeZeroDebounceTimer = null;
      if (!hadPendingPause) onVolumeRestored?.call();
    }
  }

  void setAutoPauseEnabled(bool enabled) {
    _isAutoPauseEnabled = enabled;
    if (!enabled) {
      _volumeZeroDebounceTimer?.cancel();
      _volumeZeroDebounceTimer = null;
    }
  }

  bool get isAutoPauseEnabled => _isAutoPauseEnabled;

  double get currentVolume => _currentVolume;

  void dispose() {
    _volumeSubscription?.cancel();
    _volumeSubscription = null;
    _volumeZeroDebounceTimer?.cancel();
    _volumeZeroDebounceTimer = null;
  }
}
