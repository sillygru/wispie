/// Decides when a muted video surface should be pulled back into line with the
/// audio player, which is the single source of playback truth.
///
/// The thresholds and the correction rules live in the native core; this is the
/// typed adapter the player calls.
library;

import '../../data/rust/wispie_core.dart';

enum VideoSyncAction {
  /// Leave the video alone.
  none,

  /// Seek the video to the audio position.
  seek,
}

/// What to do with a video sitting at [videoPosition] while the audio is at
/// [audioPosition].
///
/// [msSinceLastSeek] is the time since the last correction; pass a large value
/// (or [double.infinity]) when there has not been one.
VideoSyncAction resolveVideoSync({
  required Duration audioPosition,
  required Duration videoPosition,
  required bool audioPlaying,
  required bool videoBuffering,
  required bool seekInFlight,
  required double msSinceLastSeek,
}) {
  final decision = WispieCore.videoSync(
    audioMs: audioPosition.inMilliseconds.toDouble(),
    videoMs: videoPosition.inMilliseconds.toDouble(),
    playing: audioPlaying,
    buffering: videoBuffering,
    seekInFlight: seekInFlight,
    sinceLastSeekMs: msSinceLastSeek,
  );
  return decision == 1 ? VideoSyncAction.seek : VideoSyncAction.none;
}

/// The aspect ratio the video actually occupies on screen.
double videoDisplayAspectRatio(double rawAspect, int rotationCorrection) =>
    WispieCore.videoAspect(rawAspect, rotationCorrection);
