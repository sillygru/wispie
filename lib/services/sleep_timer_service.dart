import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_player_manager.dart';

/// Enum representing the different sleep timer modes
enum SleepTimerMode {
  loopCurrent,
  playForTime,
  stopAfterCurrent,
  stopAfterTracks,
}

/// Decides when listening should end; [AudioPlayerManager] performs the ending.
///
/// The manager owns the playhead and the track boundary, so it can play the
/// current song out and leave the queue parked on the next track. Doing that
/// here, from a position stream, is what used to cut the last song off a second
/// early.
class SleepTimerService extends ChangeNotifier {
  static final SleepTimerService instance = SleepTimerService._internal();
  SleepTimerService._internal();

  Timer? _timer;
  StreamSubscription<int?>? _indexSub;
  StreamSubscription<PlayerState>? _stateSub;
  Stopwatch? _elapsedTimeStopwatch;

  bool _isActive = false;
  bool _isShuttingDown = false;
  SleepTimerMode? _currentMode;
  VoidCallback? _onComplete;
  AudioPlayerManager? _audioManager;

  /// Bumped on every start and cancel, so a session that is waiting for its
  /// last song cannot stop the playback of a newer one.
  int _generation = 0;

  /// Track boundaries heard since a stopAfterTracks timer started.
  int _tracksHeard = 0;

  LoopMode? _originalLoopMode;

  DateTime? _startTime;
  int? _durationMinutes;

  /// Whether a sleep timer is currently active
  bool get isActive => _isActive;

  /// The current timer mode, or null if not active
  SleepTimerMode? get currentMode => _currentMode;

  /// Remaining minutes for time-based modes
  int? get remainingMinutes {
    if (_startTime == null || _durationMinutes == null) return null;
    final elapsed = DateTime.now().difference(_startTime!).inMinutes;
    return max(0, _durationMinutes! - elapsed);
  }

  /// Starts a sleep timer with the specified configuration
  void start({
    required SleepTimerMode mode,
    required int minutes,
    required int tracks,
    required bool letCurrentFinish,
    required AudioPlayerManager audioManager,
    required VoidCallback onComplete,
  }) {
    cancel();

    _isActive = true;
    _isShuttingDown = false;
    _currentMode = mode;
    _onComplete = onComplete;
    _audioManager = audioManager;
    _durationMinutes = minutes;
    _startTime = DateTime.now();
    _tracksHeard = 0;
    _originalLoopMode = audioManager.player.loopMode;

    switch (mode) {
      case SleepTimerMode.loopCurrent:
        audioManager.player.setLoopMode(LoopMode.one);
        _startCountdown(minutes, audioManager, finishCurrent: false);
        break;
      case SleepTimerMode.playForTime:
        _startCountdown(minutes, audioManager, finishCurrent: letCurrentFinish);
        break;
      case SleepTimerMode.stopAfterCurrent:
        unawaited(_end(audioManager, finishCurrent: true));
        break;
      case SleepTimerMode.stopAfterTracks:
        // A repeated track never reaches a boundary, so the count would stall.
        if (audioManager.player.loopMode == LoopMode.one) {
          audioManager.player.setLoopMode(LoopMode.off);
        }
        _startTrackCountdown(tracks, audioManager);
        break;
    }

    notifyListeners();
  }

  void _startCountdown(
    int minutes,
    AudioPlayerManager audioManager, {
    required bool finishCurrent,
  }) {
    _elapsedTimeStopwatch = Stopwatch()..start();
    final targetDuration = Duration(minutes: minutes);

    // One timer for the whole countdown rather than a tick a second.
    //
    // A one-second periodic timer woke the CPU 3,600 times for an hour-long
    // sleep timer, every one of them only to compare two durations — with the
    // screen off, on a device the user has deliberately left playing overnight.
    // Nothing watches the intermediate values: `remainingMinutes` is computed
    // from `_startTime` on demand.
    //
    // The stopwatch stays as the source of truth. A timer can fire late (the
    // process was suspended, the device dozed), never early, but re-arming on
    // the remainder if it somehow does is a cheap guarantee that the timer
    // never ends listening ahead of time.
    void arm(Duration delay) {
      _timer = Timer(delay, () {
        _timer = null;
        final stopwatch = _elapsedTimeStopwatch;
        if (stopwatch == null) return;

        final remaining = targetDuration - stopwatch.elapsed;
        if (remaining > Duration.zero) {
          arm(remaining);
          return;
        }

        unawaited(_end(audioManager, finishCurrent: finishCurrent));
      });
    }

    arm(targetDuration);
  }

  /// Counts track boundaries, then ends after the last track the listener asked
  /// for. Only one counter may watch this: the old pair of a playback-event
  /// listener and a completion fallback both decremented, so the timer could
  /// stop a track early.
  void _startTrackCountdown(int tracks, AudioPlayerManager audioManager) {
    final target = max(1, tracks);

    _indexSub = audioManager.settledCurrentIndexStream.listen((_) {
      if (_isShuttingDown) return;
      _tracksHeard++;
      if (_tracksHeard < target) return;
      _indexSub?.cancel();
      _indexSub = null;
      unawaited(_end(audioManager, finishCurrent: true));
    });

    // A queue shorter than the request still has to end the timer.
    _stateSub = audioManager.player.playerStateStream.listen((state) {
      if (_isShuttingDown) return;
      if (state.processingState == ProcessingState.completed) {
        unawaited(_end(audioManager, finishCurrent: false));
      }
    });
  }

  Future<void> _end(
    AudioPlayerManager audioManager, {
    required bool finishCurrent,
  }) async {
    if (!_isActive || _isShuttingDown) return;
    _isShuttingDown = true;
    final generation = _generation;
    _cancelPending();

    try {
      if (finishCurrent) {
        // The current song plays to its end. The next one is loaded, rewound
        // and left paused, so not a frame of it is heard. Armed while paused
        // too: the song still has to end before the session does.
        await audioManager.parkAfterCurrentTrack();
      }
      // Whatever resolved the wait — a track boundary, the end of the queue, a
      // pending replacement starting, a skip — nothing may still be audible.
      if (audioManager.player.playing) {
        await audioManager.player.pause();
      }
      if (!_isActive || generation != _generation) return;
      await audioManager.forceFlushCurrentStats();
    } catch (e) {
      debugPrint('Sleep timer: failed to end playback: $e');
    }
    if (!_isActive || generation != _generation) return;

    // Playback is already silent at this point; the rest is housekeeping, so
    // the UI reports the timer as finished as soon as it is.
    _isActive = false;
    _currentMode = null;
    _startTime = null;
    _durationMinutes = null;
    _isShuttingDown = false;
    notifyListeners();
    _onComplete?.call();

    // Give the message time to be read, then dismiss the notification and hand
    // the listener's own loop mode back.
    await Future<void>.delayed(const Duration(seconds: 3));
    if (generation != _generation) return;
    try {
      await audioManager.player.setLoopMode(_originalLoopMode ?? LoopMode.off);
      // Only the notification is left to dismiss. If the listener picked
      // playback back up in the meantime, leave it running.
      if (!audioManager.player.playing) {
        await audioManager.player.stop();
      }
    } catch (e) {
      debugPrint('Sleep timer: failed to stop the player: $e');
    }
    _audioManager = null;
    _onComplete = null;
    _originalLoopMode = null;
  }

  void _cancelPending() {
    _timer?.cancel();
    _timer = null;
    _indexSub?.cancel();
    _indexSub = null;
    _stateSub?.cancel();
    _stateSub = null;
    _elapsedTimeStopwatch?.stop();
    _elapsedTimeStopwatch = null;
  }

  void _cleanupState() {
    _cancelPending();
    _tracksHeard = 0;
    _isActive = false;
    _isShuttingDown = false;
    _currentMode = null;
    _audioManager = null;
    _onComplete = null;
    _startTime = null;
    _durationMinutes = null;
    _originalLoopMode = null;
  }

  void cancel() {
    final manager = _audioManager;
    if (manager != null) {
      // The queue must not be parked after the listener decided to stay up.
      manager.cancelParkAfterCurrentTrack();
      final loopMode = _originalLoopMode;
      if (loopMode != null) {
        try {
          manager.player.setLoopMode(loopMode);
        } catch (e) {
          debugPrint('Sleep timer: failed to restore loop mode: $e');
        }
      }
    }
    _generation++;
    _cleanupState();
    notifyListeners();
  }
}
