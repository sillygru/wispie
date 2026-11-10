import '../../models/song.dart';
import '../models/listening_insights.dart';
import 'native_accel.dart';

/// Folds the complete listening history in the native core and maps its result
/// into the presentation model.
ListeningInsights buildInsights({
  required List<PlayEventSample> events,
  required Map<String, Song> library,
  required Set<String> favorites,
  required StatsRange range,
  required DateTime now,
  int topCount = 10,
}) {
  final result = NativeAccel.insights(
    events: [
      for (final event in events)
        (
          filename: event.filename,
          timestampMs: event.at.millisecondsSinceEpoch,
          playedMs: event.played.inMilliseconds,
          playRatio: event.playRatio,
          year: event.at.year,
          month: event.at.month,
          day: event.at.day,
          hour: event.at.hour,
          weekday: event.at.weekday - 1,
        ),
    ],
    songs: [
      for (final song in library.values)
        {
          'filename': song.filename,
          'title': song.title,
          'artist': song.artist,
          'album': song.album,
          'coverUrl': song.coverUrl,
        },
    ],
    favorites: favorites,
    range: range.name,
    now: now,
    topCount: topCount,
  );

  int intValue(Object? value) => (value as num).toInt();
  Duration duration(Object? value) => Duration(milliseconds: intValue(value));
  DateTime date(Object? value) {
    final parts = value as Map<String, dynamic>;
    return DateTime(
      intValue(parts['year']),
      intValue(parts['month']),
      intValue(parts['day']),
    );
  }

  List<HistogramBucket> buckets(Object? value) => [
        for (final row in value as List<dynamic>)
          HistogramBucket(
            index: intValue((row as Map<String, dynamic>)['index']),
            plays: intValue(row['plays']),
            listened: duration(row['listenedMs']),
          ),
      ];

  List<TrendPoint> trendPoints(Object? value) => [
        for (final row in value as List<dynamic>)
          TrendPoint(
            start: date((row as Map<String, dynamic>)['start']),
            label: row['label'] as String,
            caption: row['caption'] as String,
            plays: intValue(row['plays']),
            listened: duration(row['listenedMs']),
          ),
      ];

  List<RankedName> ranked(Object? value) => [
        for (final row in value as List<dynamic>)
          RankedName(
            name: (row as Map<String, dynamic>)['name'] as String,
            detail: row['detail'] as String?,
            filename: row['filename'] as String?,
            coverUrl: row['coverUrl'] as String?,
            plays: intValue(row['plays']),
            listened: duration(row['listenedMs']),
            isFavorite: row['isFavorite'] as bool? ?? false,
          ),
      ];

  final listenedTrend = result['listenedTrend'] as Map<String, dynamic>;
  final playsTrend = result['playsTrend'] as Map<String, dynamic>;
  final firstPlayMs = result['firstPlayMs'] as num?;
  final lastPlayMs = result['lastPlayMs'] as num?;
  return ListeningInsights(
    range: range,
    from: range == StatsRange.allTime
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : date(result['from']),
    to: date(result['to']),
    plays: intValue(result['plays']),
    skips: intValue(result['skips']),
    listened: duration(result['listenedMs']),
    uniqueSongs: intValue(result['uniqueSongs']),
    discoveredInLibrary: intValue(result['discoveredInLibrary']),
    librarySize: intValue(result['librarySize']),
    activeDays: intValue(result['activeDays']),
    currentStreak: intValue(result['currentStreak']),
    longestStreak: intValue(result['longestStreak']),
    favoritePlays: intValue(result['favoritePlays']),
    firstPlayAt: firstPlayMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(firstPlayMs.toInt()),
    lastPlayAt: lastPlayMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastPlayMs.toInt()),
    byHour: buckets(result['byHour']),
    byWeekday: buckets(result['byWeekday']),
    trend: trendPoints(result['trend']),
    topArtists: ranked(result['topArtists']),
    topSongs: ranked(result['topSongs']),
    topAlbums: ranked(result['topAlbums']),
    listenedTrend: TrendChange(
      current: intValue(listenedTrend['current']),
      previous: intValue(listenedTrend['previous']),
    ),
    playsTrend: TrendChange(
      current: intValue(playsTrend['current']),
      previous: intValue(playsTrend['previous']),
    ),
  );
}
