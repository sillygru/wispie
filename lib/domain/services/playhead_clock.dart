import '../../data/rust/wispie_core.dart';

/// A smoothed, latency-compensated estimate of where the listener currently is
/// in the track.
///
/// `player.position` jitters enough between platform updates to make anything
/// beat-locked visibly stutter, and it describes what the *decoder* has reached
/// rather than what has come out of the speaker. Both problems are solved once,
/// here, so every beat-reactive surface in the app agrees on where "now" is.
///
/// The arithmetic (snap threshold, easing factor, latency subtraction) lives in
/// the native core; this holds the anchor and feeds it wall time.
class PlayheadClock {
  Duration _anchorPosition = Duration.zero;
  int _anchorWallMs = DateTime.now().millisecondsSinceEpoch;
  bool _playing = false;

  PlayheadClock({Duration position = Duration.zero, bool playing = false}) {
    _anchorPosition = position;
    _playing = playing;
  }

  bool get playing => _playing;

  set playing(bool value) {
    if (_playing == value) return;
    // Re-anchor across the transition so the clock does not jump by however
    // long the player sat paused.
    _anchorPosition = predicted;
    _anchorWallMs = DateTime.now().millisecondsSinceEpoch;
    _playing = value;
  }

  /// Visual offset in milliseconds, compensating audio output latency.
  ///
  /// Wired to a user setting because the correct value is not a property of the
  /// app: wired headphones need ~50 ms while Bluetooth routinely needs 150-250.
  int latencyMs = 0;

  void onPosition(Duration position) {
    final current = predicted;
    final anchored = WispieCore.playheadEase(
      current.inMilliseconds.toDouble(),
      position.inMilliseconds.toDouble(),
    );
    _anchorPosition = Duration(milliseconds: anchored.round());
    _anchorWallMs = DateTime.now().millisecondsSinceEpoch;
  }

  /// Re-anchors to [position] without easing, and marks the clock stopped.
  void reset(Duration position) {
    _anchorPosition = position;
    _anchorWallMs = DateTime.now().millisecondsSinceEpoch;
    _playing = false;
  }

  /// Re-anchors to [position] without easing, optionally updating [playing].
  void reanchor(Duration position, {bool? playing}) {
    _anchorPosition = position;
    _anchorWallMs = DateTime.now().millisecondsSinceEpoch;
    if (playing != null) {
      _playing = playing;
    }
  }

  Duration get predicted =>
      Duration(milliseconds: _visualMs(latencyMs: 0).round());

  /// The position the listener is currently *hearing*, which trails the decoder
  /// by the output latency.
  double get visualPositionMs => _visualMs(latencyMs: latencyMs);

  double _visualMs({required int latencyMs}) => WispieCore.playheadVisual(
        anchorMs: _anchorPosition.inMilliseconds.toDouble(),
        wallMs: _anchorWallMs.toDouble(),
        playing: _playing,
        nowMs: DateTime.now().millisecondsSinceEpoch.toDouble(),
        latencyMs: latencyMs.toDouble(),
      );
}
