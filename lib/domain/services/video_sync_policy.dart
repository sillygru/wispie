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
  if (!audioPlaying || videoBuffering || seekInFlight) {
    return VideoSyncAction.none;
  }

  final driftMs =
      (videoPosition.inMilliseconds - audioPosition.inMilliseconds).abs();
  if (driftMs <= 250) return VideoSyncAction.none;
  if (driftMs > 1500 || msSinceLastSeek >= 5000) {
    return VideoSyncAction.seek;
  }
  return VideoSyncAction.none;
}

/// The aspect ratio the video actually occupies on screen.
double videoDisplayAspectRatio(double rawAspect, int rotationCorrection) {
  if (!rawAspect.isFinite || rawAspect <= 0) return 1;
  return (rotationCorrection ~/ 90).isOdd ? 1 / rawAspect : rawAspect;
}
