import '../../data/rust/wispie_core.dart';

/// Playback decisions owned by the native core.
///
/// The player, its lifecycle and the platform quirks stay in the host; these are
/// the rules a second front end has to share: fade envelopes and transition
/// triggers, the play-event maths, merged-version choice, original ordering and
/// the sleep timer's stop condition.
class PlaybackRules {
  PlaybackRules._();

  static double fadeVolume({
    required bool fadeIn,
    required double progress,
    required double userVolume,
  }) =>
      (WispieCore.helper({
        'action': 'playback_fade',
        'kind': fadeIn ? 'in' : 'out',
        'progress': progress,
        'userVolume': userVolume,
      })['volume'] as num)
          .toDouble();

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
    final reply = WispieCore.helper({
      'action': 'playback_tick',
      'positionMs': positionMs,
      'durationMs': durationMs,
      'playing': playing,
      'isFadingOut': isFadingOut,
      'parkPending': parkPending,
      'isInGap': isInGap,
      'gapTimerActive': gapTimerActive,
      'delayDuration': delayDuration,
      'fadeOutDuration': fadeOutDuration,
    });
    return (
      gap: reply['gap'] as bool,
      fadeOut: reply['fadeOut'] as bool,
      cancelFade: reply['cancelFade'] as bool,
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
    required List<({String filename, bool favorite, bool suggestLess})> items,
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
    final reply = WispieCore.helper({
      'action': 'playback_sleep',
      'mode': mode,
      'elapsedMs': elapsedMs,
      'durationMs': durationMs,
      'tracksHeard': tracksHeard,
      'targetTracks': targetTracks,
      'completed': completed,
      'finishCurrent': finishCurrent,
    });
    return (
      end: reply['end'] as bool,
      finishCurrent: reply['finishCurrent'] as bool,
      remainingMs: (reply['remainingMs'] as num).toDouble(),
    );
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
