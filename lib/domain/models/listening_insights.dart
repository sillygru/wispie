import 'package:equatable/equatable.dart';

/// Sentinel the scanner writes when a file carries no artist tag. Ranked lists
/// drop these rather than crowning "Unknown Artist" as someone's favourite.
const String kUnknownArtist = 'Unknown Artist';

/// Sentinel the scanner writes when a file carries no album tag.
const String kUnknownAlbum = 'Unknown Album';

/// An hour index as a clock label: 0 -> "12 AM", 13 -> "1 PM".
///
/// Defined once, in the domain layer, because both the stats screen and the
/// backup export render hour indexes, and a disagreement between them would
/// surface as a screen that contradicts its own backup.
String hourLabel(int hour) {
  if (hour == 0) return '12 AM';
  if (hour < 12) return '$hour AM';
  if (hour == 12) return '12 PM';
  return '${hour - 12} PM';
}

/// A month as its three-letter name: 3 -> "Mar".
String shortMonth(int month) => const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][month - 1];

/// A weekday index (0 = Monday) as a full weekday name.
String weekdayName(int index) => switch (index) {
      0 => 'Monday',
      1 => 'Tuesday',
      2 => 'Wednesday',
      3 => 'Thursday',
      4 => 'Friday',
      5 => 'Saturday',
      6 => 'Sunday',
      _ => '',
    };

/// How far back the stats screen looks.
///
/// A range is a UI choice, not a storage one — every window is folded out of
/// the same event list, so switching ranges never re-queries a different table.
enum StatsRange {
  week(days: 7, label: '7D'),
  month(days: 30, label: '30D'),
  quarter(days: 90, label: '3M'),
  year(days: 365, label: '1Y'),
  allTime(days: null, label: 'All');

  const StatsRange({required this.days, required this.label});

  /// Length of the window in days, or null when it reaches back to the first
  /// play ever recorded.
  final int? days;

  /// Chip label — short enough to sit four-across on a phone.
  final String label;

  /// Human name for the header and the trend comparison line.
  String get title => switch (this) {
        StatsRange.week => 'Last 7 days',
        StatsRange.month => 'Last 30 days',
        StatsRange.quarter => 'Last 3 months',
        StatsRange.year => 'Last year',
        StatsRange.allTime => 'All time',
      };
}

/// One play event, reduced to the columns the insights actually need.
///
/// [DatabaseService] keeps the full row; this read model means the builder
/// never has to know a SQLite column name or repeat the `num?` coercion dance,
/// and every value it reads is non-null by construction.
class PlayEventSample extends Equatable {
  final String filename;

  /// When the track started.
  final DateTime at;

  /// How much of it was actually heard. This is the honest basis for every
  /// duration figure on the screen — a skip contributes its few seconds, not
  /// the track length.
  final Duration played;

  /// Fraction of the track heard, 0..1. Rows written before `play_ratio`
  /// existed derive it from [played] against the track length.
  final double playRatio;

  const PlayEventSample({
    required this.filename,
    required this.at,
    required this.played,
    required this.playRatio,
  });

  factory PlayEventSample.fromRow(Map<String, Object?> row) {
    final playedSeconds = _toDouble(row['duration_played']);
    final trackLength = _toDouble(row['total_length']);
    final storedRatio =
        row['play_ratio'] == null ? null : _toDouble(row['play_ratio']);

    // Older rows predate play_ratio; fall back to the same ratio the history
    // screen derives so both surfaces classify an event identically.
    final ratio = storedRatio ??
        (trackLength > 0 ? (playedSeconds / trackLength).clamp(0.0, 1.0) : 0.0);

    return PlayEventSample(
      filename: row['song_filename'] as String? ?? '',
      at: DateTime.fromMillisecondsSinceEpoch(
        (((row['timestamp'] as num?)?.toDouble() ?? 0) * 1000).round(),
      ),
      played: Duration(milliseconds: (playedSeconds * 1000).round()),
      playRatio: ratio,
    );
  }

  /// Bounced off almost immediately — the event that carries no real listening.
  bool get isSkip =>
      played < const Duration(seconds: 10) && playRatio < _skipRatio;

  /// Counted as a play: heard long enough, or far enough in, to be a listen.
  bool get countsAsPlay =>
      played > const Duration(seconds: 10) || playRatio > _skipRatio;

  bool get isCompleted => playRatio >= 0.9;

  static const double _skipRatio = 0.25;

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return 0.0;
  }

  @override
  List<Object?> get props => [filename, at, played, playRatio];
}

/// How much listening one cell of a histogram holds.
class HistogramBucket extends Equatable {
  /// Position in the axis — 0..23 for hours, 0..6 for weekdays from Monday.
  final int index;

  final int plays;
  final Duration listened;

  const HistogramBucket({
    required this.index,
    required this.plays,
    required this.listened,
  });

  @override
  List<Object?> get props => [index, plays, listened];
}

/// One point on the trend series — a day or a month, depending on how much
/// history there is.
class TrendPoint extends Equatable {
  /// First day (or first day of the month) this point covers.
  final DateTime start;

  /// Short axis label: a weekday initial for a week, a day number for a month,
  /// a month name for a year.
  final String label;

  /// Full label for the readout above the chart.
  final String caption;

  final int plays;
  final Duration listened;

  const TrendPoint({
    required this.start,
    required this.label,
    required this.caption,
    required this.plays,
    required this.listened,
  });

  @override
  List<Object?> get props => [start, label, caption, plays, listened];
}

/// A ranked artist, album or song, carrying enough context for its own row.
class RankedName extends Equatable {
  final String name;

  /// The qualifier under the name — a song's artist, an album's artist.
  final String? detail;

  /// Set for songs, so a row can show artwork and resolve a selection.
  final String? filename;

  /// Cover art for [filename], when the song has any.
  final String? coverUrl;

  final int plays;
  final Duration listened;
  final bool isFavorite;

  const RankedName({
    required this.name,
    required this.plays,
    required this.listened,
    this.detail,
    this.filename,
    this.coverUrl,
    this.isFavorite = false,
  });

  @override
  List<Object?> get props => [
        name,
        detail,
        filename,
        coverUrl,
        plays,
        listened,
        isFavorite,
      ];
}

/// A current-window figure next to the same window immediately before it.
class TrendChange extends Equatable {
  final int current;
  final int previous;

  const TrendChange({required this.current, required this.previous});

  /// Nothing to compare against — the first window of a listener's life.
  bool get hasBaseline => previous > 0;

  /// Fractional change, or null when [previous] is zero.
  double? get change => previous <= 0 ? null : (current - previous) / previous;

  @override
  List<Object?> get props => [current, previous];
}

/// Everything the stats screen renders, for one [StatsRange].
///
/// Built by `buildInsights` in the domain layer — a widget never assembles a
/// figure, it only reads one.
class ListeningInsights extends Equatable {
  final StatsRange range;

  /// Inclusive first instant of the window, local midnight.
  final DateTime from;

  /// Today's local midnight.
  final DateTime to;

  /// Listens that lasted past the skip threshold.
  final int plays;

  /// Events bounced off within seconds.
  final int skips;

  /// Total wall-clock time spent listening, skips included.
  final Duration listened;

  /// Distinct tracks heard at least once in the window.
  final int uniqueSongs;

  /// Distinct tracks from the current library that were heard in the window —
  /// the numerator of the explorer figure.
  final int discoveredInLibrary;

  final int librarySize;

  /// Days in the window with any listening at all.
  final int activeDays;

  final int currentStreak;
  final int longestStreak;

  /// Plays that were of favourited tracks.
  final int favoritePlays;

  /// Lifetime, not windowed: the first and last play ever recorded.
  final DateTime? firstPlayAt;
  final DateTime? lastPlayAt;

  /// 24 buckets, 0 = midnight.
  final List<HistogramBucket> byHour;

  /// 7 buckets, 0 = Monday.
  final List<HistogramBucket> byWeekday;

  final List<TrendPoint> trend;

  final List<RankedName> topArtists;
  final List<RankedName> topSongs;
  final List<RankedName> topAlbums;

  final TrendChange listenedTrend;
  final TrendChange playsTrend;

  const ListeningInsights({
    required this.range,
    required this.from,
    required this.to,
    required this.plays,
    required this.skips,
    required this.listened,
    required this.uniqueSongs,
    required this.discoveredInLibrary,
    required this.librarySize,
    required this.activeDays,
    required this.currentStreak,
    required this.longestStreak,
    required this.favoritePlays,
    required this.firstPlayAt,
    required this.lastPlayAt,
    required this.byHour,
    required this.byWeekday,
    required this.trend,
    required this.topArtists,
    required this.topSongs,
    required this.topAlbums,
    required this.listenedTrend,
    required this.playsTrend,
  });

  /// Nothing has ever been recorded — the screen shows its empty state.
  bool get isEmpty => plays == 0 && skips == 0 && listened == Duration.zero;

  /// Total events in the window, whatever their verdict.
  int get events => plays + skips;

  double get skipRate => events == 0 ? 0 : skips / events;

  double get favoriteShare => plays == 0 ? 0 : favoritePlays / plays;

  /// Share of the library that has been played in this window, 0..1.
  double get exploredShare => librarySize == 0
      ? 0
      : (discoveredInLibrary / librarySize).clamp(0.0, 1.0);

  /// Average length of a track that was actually played.
  Duration get averagePlay => plays == 0 ? Duration.zero : listened ~/ plays;

  /// Average listening per day the user actually showed up.
  Duration get averageDay =>
      activeDays == 0 ? Duration.zero : listened ~/ activeDays;

  int get averagePlaysPerDay => activeDays == 0 ? 0 : plays ~/ activeDays;

  /// Busiest hour, or null when nothing was ever played.
  int? get peakHour => _peakIndex(byHour);

  /// Busiest weekday (0 = Monday), or null when nothing was ever played.
  int? get peakWeekday => _peakIndex(byWeekday);

  /// Best single point on the trend series.
  TrendPoint? get peakTrendPoint {
    TrendPoint? best;
    for (final point in trend) {
      if (point.listened > Duration.zero &&
          (best == null || point.listened > best.listened)) {
        best = point;
      }
    }
    return best;
  }

  /// Length of the window in days, or null for all time.
  int? get windowDays => range.days;

  static int? _peakIndex(List<HistogramBucket> buckets) {
    int? best;
    Duration bestValue = Duration.zero;
    for (final bucket in buckets) {
      if (bucket.listened > bestValue) {
        bestValue = bucket.listened;
        best = bucket.index;
      }
    }
    return best;
  }

  @override
  List<Object?> get props => [
        range,
        from,
        to,
        plays,
        skips,
        listened,
        uniqueSongs,
        discoveredInLibrary,
        librarySize,
        activeDays,
        currentStreak,
        longestStreak,
        favoritePlays,
        firstPlayAt,
        lastPlayAt,
        byHour,
        byWeekday,
        trend,
        topArtists,
        topSongs,
        topAlbums,
        listenedTrend,
        playsTrend,
      ];
}
