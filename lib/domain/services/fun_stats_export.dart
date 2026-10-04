import '../models/listening_insights.dart';

/// The `final_stats.json` payload that backups carry.
///
/// A flat, stringly-typed shape that predates the stats screen. It is kept
/// verbatim because it is part of the backup format: an archive written by an
/// older build has to stay readable, and the phrasing is what those files
/// contain. The numbers behind it now come from [buildInsights] instead of a
/// second, hand-rolled aggregation pass.
Map<String, dynamic> buildFunStatsPayload(
  ListeningInsights insights, {
  required int librarySize,
}) {
  final stats = <Map<String, dynamic>>[];

  final totalSeconds = insights.listened.inMilliseconds / 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;

  stats.add({
    'id': 'total_time',
    'label': 'Total Listening Time',
    'value': '${hours}h ${minutes}m',
    'subtitle':
        "You've listened for ${(totalSeconds / 86400).toStringAsFixed(1)} days total!",
  });

  final topArtist = insights.topArtists.firstOrNull;
  if (topArtist != null) {
    stats.add({
      'id': 'top_artist',
      'label': 'Most Played Artist',
      'value': topArtist.name,
      'subtitle': '${topArtist.plays} plays. You clearly love them.',
    });
  }

  final topSong = insights.topSongs.firstOrNull;
  if (topSong != null) {
    stats.add({
      'id': 'top_song',
      'label': 'Most Played Song',
      'value': topSong.name,
      'subtitle': 'Played ${topSong.plays} times.',
    });
  }

  stats.add({
    'id': 'streak',
    'label': 'Longest Streak',
    'value': '${insights.longestStreak} Days',
    'subtitle': insights.currentStreak > 0
        ? 'Current streak: ${insights.currentStreak} days'
        : 'Start a new streak today!',
  });

  final peakHour = insights.peakHour;
  if (peakHour != null) {
    stats.add({
      'id': 'active_hour',
      'label': 'Most Active Hour',
      'value': hourLabel(peakHour),
      'subtitle': 'You listen most at this time.',
    });
  }

  final peakWeekday = insights.peakWeekday;
  if (peakWeekday != null) {
    stats.add({
      'id': 'active_day',
      'label': 'Most Active Day',
      'value': weekdayName(peakWeekday),
      'subtitle': 'Your favorite day to jam.',
    });
  }

  stats.add({
    'id': 'skips',
    'label': 'Quick Skips',
    'value': '${insights.skips}',
    'subtitle': 'Songs skipped quickly.',
  });

  stats.add({
    'id': 'unique_songs',
    'label': 'Unique Songs Played',
    'value': '${insights.uniqueSongs}',
    'subtitle': "Distinct tracks you've heard.",
  });

  stats.add({
    'id': 'total_songs_played',
    'label': 'Total Songs Played',
    'value': '${insights.plays}',
    'subtitle': "Total times you've jammed out.",
  });

  if (librarySize > 0) {
    final explored = (insights.uniqueSongs / librarySize * 100).toInt();
    stats.add({
      'id': 'explorer_score',
      'label': 'Explorer Score',
      'value': '$explored%',
      'subtitle': 'Of your library explored.',
    });
  }

  if (insights.plays > 0) {
    final consistency = (insights.favoriteShare * 100).toInt();
    stats.add({
      'id': 'consistency',
      'label': 'Consistency Score',
      'value': '$consistency%',
      'subtitle': 'Plays that were Favorites.',
    });
  }

  return {'stats': stats};
}
