import '../../domain/models/listening_insights.dart';
import '../../services/database_service.dart';

/// Reads the play-event log as [PlayEventSample]s.
///
/// Deliberately narrow: it selects only the four columns the insights need and
/// leaves every decision about *what those numbers mean* to
/// `buildInsights`. The full `playevent` row carries session ids, device ids
/// and foreground/background splits that no stats screen reads.
class InsightsRepository {
  static const List<String> _columns = [
    'song_filename',
    'timestamp',
    'duration_played',
    'total_length',
    'play_ratio',
  ];

  /// Every recorded play, oldest first.
  ///
  /// Loads the whole log rather than pushing a window down into SQL: streaks,
  /// first-play dates and the previous-period comparison all reach outside the
  /// selected range, so any windowing here would have to be redone in Dart
  /// anyway. Narrow columns keep that affordable.
  Future<List<PlayEventSample>> loadPlayEvents() async {
    final database = DatabaseService.instance;
    await database.init();
    final handle = database.getStatsDatabase();
    if (handle == null) return const [];

    final rows = await handle.query(
      'playevent',
      columns: _columns,
      orderBy: 'timestamp ASC',
    );
    return rows.map(PlayEventSample.fromRow).toList(growable: false);
  }

  /// Timestamps of the most recent play, for the "last played" line.
  Future<DateTime?> loadLastPlayAt() async {
    final database = DatabaseService.instance;
    await database.init();
    final handle = database.getStatsDatabase();
    if (handle == null) return null;

    final rows = await handle.query(
      'playevent',
      columns: const ['timestamp'],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final seconds = (rows.first['timestamp'] as num?)?.toDouble() ?? 0;
    return DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
  }

  /// Favourites as a set — the log stores filenames, so this is a membership
  /// test rather than a join.
  Future<Set<String>> loadFavorites() async {
    final database = DatabaseService.instance;
    await database.init();
    return (await database.getFavorites()).toSet();
  }
}
