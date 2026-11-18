import '../../data/rust/wispie_core.dart';
import '../models/listening_insights.dart';

/// The `final_stats.json` payload that backups carry.
///
/// A flat, stringly-typed shape that predates the stats screen. It is kept
/// verbatim because it is part of the backup format: an archive written by an
/// older build has to stay readable, and the phrasing is what those files
/// contain. The figures come from [buildInsights]; the assembly lives in the
/// native core with the rest of the format.
Map<String, dynamic> buildFunStatsPayload(
  ListeningInsights insights, {
  required int librarySize,
}) =>
    WispieCore.helper({
      'action': 'fun_stats',
      'insights': {
        'listenedMs': insights.listened.inMilliseconds,
        'topArtists': [
          for (final row in insights.topArtists)
            {'name': row.name, 'plays': row.plays},
        ],
        'topSongs': [
          for (final row in insights.topSongs)
            {'name': row.name, 'plays': row.plays},
        ],
        'longestStreak': insights.longestStreak,
        'currentStreak': insights.currentStreak,
        'peakHour': insights.peakHour,
        'peakWeekday': insights.peakWeekday,
        'skips': insights.skips,
        'uniqueSongs': insights.uniqueSongs,
        'plays': insights.plays,
        'favoriteShare': insights.favoriteShare,
      },
      'librarySize': librarySize,
    });
