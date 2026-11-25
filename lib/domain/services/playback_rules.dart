import 'dart:math' as math;

import '../../data/rust/wispie_core.dart';

typedef PlaybackVariantItem = ({
  String filename,
  bool favorite,
  bool suggestLess
});

typedef PlaybackVariantGroup = ({
  List<PlaybackVariantItem> items,
  int? priorityIndex,
  double roll,
});

class PlaybackRules {
  PlaybackRules._();

  static double fadeVolume({
    required bool fadeIn,
    required double progress,
    required double userVolume,
  }) {
    final curved = math.pow(progress.clamp(0.0, 1.0), fadeIn ? 1.5 : 2);
    return curved * userVolume.clamp(0.0, 1.0);
  }

  static ({bool gap, bool fadeOut, bool cancelFade}) tick({
    required double positionMs,
    required double durationMs,
    required bool playing,
    required bool isFadingOut,
    required bool parkPending,
    required bool isInGap,
    required bool gapTimerActive,
    required double delayDuration,
    required double fadeOutDuration,
  }) {
    if (durationMs < 30000) {
      return (gap: false, fadeOut: false, cancelFade: false);
    }

    final remainingMs = durationMs - positionMs;
    final fadeMs = fadeOutDuration * 1000;
    return (
      gap: delayDuration > 0 &&
          playing &&
          !parkPending &&
          !isInGap &&
          !gapTimerActive,
      fadeOut: fadeMs > 0 &&
          playing &&
          !isFadingOut &&
          remainingMs <= fadeMs &&
          remainingMs > 0,
      cancelFade: isFadingOut && fadeMs > 0 && remainingMs > fadeMs + 500,
    );
  }

  static ({
    bool emit,
    bool completed,
    double durationPlayed,
    double foreground,
    double background,
    double totalLength,
  }) statsRecord({
    required String filename,
    required bool isExternal,
    required double totalLength,
    required double foreground,
    required double background,
    String? firstSongFilename,
    double? firstSongStartSec,
  }) {
    final reply = WispieCore.helper({
      'action': 'playback_stats',
      'filename': filename,
      'isExternal': isExternal,
      'totalLength': totalLength,
      'foreground': foreground,
      'background': background,
      'firstSongFilename': firstSongFilename,
      'firstSongStartSec': firstSongStartSec,
    });
    return (
      emit: reply['emit'] as bool,
      completed: reply['completed'] as bool,
      durationPlayed: (reply['durationPlayed'] as num).toDouble(),
      foreground: (reply['foreground'] as num).toDouble(),
      background: (reply['background'] as num).toDouble(),
      totalLength: (reply['totalLength'] as num).toDouble(),
    );
  }

  /// Index into [items] of the version to play, or null when there are none.
  static int? variantIndex({
    required List<PlaybackVariantItem> items,
    int? priorityIndex,
    required double roll,
  }) {
    final reply = WispieCore.helper({
      'action': 'playback_variant',
      'items': [
        for (final item in items)
          {
            'filename': item.filename,
            'favorite': item.favorite,
            'suggestLess': item.suggestLess,
          },
      ],
      'priorityIndex': priorityIndex,
      'roll': roll,
    });
    return reply['index'] as int?;
  }

  /// One pick per group in a single crossing. Used when a shuffle chooses a
  /// version for every merged group at once.
  static List<int?> variantIndices(List<PlaybackVariantGroup> groups) {
    final reply = WispieCore.helper({
      'action': 'playback_variant_batch',
      'groups': [
        for (final group in groups)
          {
            'items': [
              for (final item in group.items)
                {
                  'filename': item.filename,
                  'favorite': item.favorite,
                  'suggestLess': item.suggestLess,
                },
            ],
            'priorityIndex': group.priorityIndex,
            'roll': group.roll,
          },
      ],
    });
    return (reply['indices'] as List<dynamic>).cast<int?>();
  }

  static List<int> originalOrder({
    required List<({String queueId, String filename})> upcoming,
    required List<({String queueId, String filename})> original,
    required ({String queueId, String filename}) current,
  }) {
    final reply = WispieCore.helper({
      'action': 'playback_original_order',
      'upcoming': [
        for (final item in upcoming)
          {'queueId': item.queueId, 'filename': item.filename},
      ],
      'original': [
        for (final item in original)
          {'queueId': item.queueId, 'filename': item.filename},
      ],
      'current': {'queueId': current.queueId, 'filename': current.filename},
    });
    return (reply['order'] as List<dynamic>).cast<int>();
  }

  static ({bool end, bool finishCurrent, double remainingMs}) sleepDecision({
    required String mode,
    double elapsedMs = 0,
    double durationMs = 0,
    int tracksHeard = 0,
    int targetTracks = 1,
    bool completed = false,
    bool finishCurrent = false,
  }) {
    final remaining = math.max(0.0, durationMs - elapsedMs);
    final reachedTrackCount = tracksHeard >= math.max(1, targetTracks);
    return switch (mode) {
      'stopAfterTracks' => (
          end: reachedTrackCount || completed,
          finishCurrent: reachedTrackCount,
          remainingMs: 0.0,
        ),
      'loopCurrent' || 'playForTime' => (
          end: elapsedMs >= durationMs,
          finishCurrent: mode == 'playForTime' && finishCurrent,
          remainingMs: remaining,
        ),
      'stopAfterCurrent' => (end: true, finishCurrent: true, remainingMs: 0.0),
      _ => (end: false, finishCurrent: false, remainingMs: 0.0),
    };
  }

  /// The `original` list to persist, or null when it adds nothing.
  static List<String>? originalForSync({
    required List<String> effective,
    required List<String> original,
  }) {
    final reply = WispieCore.helper({
      'action': 'playback_queue_original',
      'effective': effective,
      'original': original,
    });
    final value = reply['original'];
    return value == null ? null : (value as List<dynamic>).cast<String>();
  }
}
