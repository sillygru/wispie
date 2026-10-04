import '../../models/song.dart';
import '../models/listening_insights.dart';

/// Folds raw play events into the aggregates the stats screen renders.
///
/// Pure by design: no database, no clock, no widgets. [now] is injected so
/// window boundaries are deterministic, which is what makes the streak and
/// period-comparison arithmetic testable without a fixture clock.
///
/// [events] may arrive in any order — the builder sorts a copy once, because
/// every pass below reads them as a timeline.
ListeningInsights buildInsights({
  required List<PlayEventSample> events,
  required Map<String, Song> library,
  required Set<String> favorites,
  required StatsRange range,
  required DateTime now,
  int topCount = 10,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final windowStart = _windowStart(range, today);
  final windowEnd = _addDays(today, 1); // exclusive

  final previousStart =
      range.days == null ? null : _addDays(windowStart, -range.days!);
  final previousEnd = previousStart == null ? null : windowStart;

  final ordered = [...events]..sort((a, b) => a.at.compareTo(b.at));

  var plays = 0;
  var skips = 0;
  var listenedSeconds = 0.0;
  var previousPlays = 0;
  var previousListenedSeconds = 0.0;
  var favoritePlays = 0;

  final lifetimeDays = <DateTime>{};
  final activeDays = <DateTime>{};
  final uniqueSongs = <String>{};
  final discovered = <String>{};

  final artistTally = <String, _Tally>{};
  final albumTally = <(String, String), _Tally>{};
  final songTally = <String, _Tally>{};

  final hourListened = List<double>.filled(24, 0);
  final hourPlays = List<int>.filled(24, 0);
  final weekdayListened = List<double>.filled(7, 0);
  final weekdayPlays = List<int>.filled(7, 0);
  final dayListened = <DateTime, double>{};
  final dayPlays = <DateTime, int>{};

  DateTime? firstPlayAt;
  DateTime? lastPlayAt;

  for (final event in ordered) {
    final day = DateTime(event.at.year, event.at.month, event.at.day);
    lifetimeDays.add(day);
    if (firstPlayAt == null || event.at.isBefore(firstPlayAt)) {
      firstPlayAt = event.at;
    }
    if (lastPlayAt == null || event.at.isAfter(lastPlayAt)) {
      lastPlayAt = event.at;
    }

    if (previousStart != null &&
        !event.at.isBefore(previousStart) &&
        event.at.isBefore(previousEnd!)) {
      previousListenedSeconds += _secondsOf(event);
      if (event.countsAsPlay) previousPlays++;
    }

    if (event.at.isBefore(windowStart) || !event.at.isBefore(windowEnd)) {
      continue;
    }

    final seconds = _secondsOf(event);
    listenedSeconds += seconds;
    activeDays.add(day);
    dayListened[day] = (dayListened[day] ?? 0) + seconds;
    dayPlays[day] = (dayPlays[day] ?? 0) + 1;
    hourListened[event.at.hour] += seconds;
    hourPlays[event.at.hour] += 1;
    weekdayListened[event.at.weekday - 1] += seconds;
    weekdayPlays[event.at.weekday - 1] += 1;

    if (event.isSkip) {
      skips++;
      continue;
    }
    if (!event.countsAsPlay) continue;

    plays++;
    uniqueSongs.add(event.filename);
    songTally.addTally(event.filename, seconds);

    final song = library[event.filename];
    if (song == null) continue;

    discovered.add(event.filename);
    if (favorites.contains(event.filename)) favoritePlays++;
    if (_isRealName(song.artist, kUnknownArtist)) {
      artistTally.addTally(song.artist, seconds);
    }
    if (_isRealName(song.album, kUnknownAlbum)) {
      albumTally.addTally((song.album, song.artist), seconds);
    }
  }

  return ListeningInsights(
    range: range,
    from: windowStart,
    to: today,
    plays: plays,
    skips: skips,
    listened: _durationOf(listenedSeconds),
    uniqueSongs: uniqueSongs.length,
    discoveredInLibrary: discovered.length,
    librarySize: library.length,
    activeDays: activeDays.length,
    currentStreak: _currentStreak(lifetimeDays, today),
    longestStreak: _longestStreak(lifetimeDays),
    favoritePlays: favoritePlays,
    firstPlayAt: firstPlayAt,
    lastPlayAt: lastPlayAt,
    byHour: _bucketize(hourListened, hourPlays),
    byWeekday: _bucketize(weekdayListened, weekdayPlays),
    trend: _buildTrend(
      range: range,
      today: today,
      windowStart: windowStart,
      firstPlayAt: firstPlayAt,
      dayListened: dayListened,
      dayPlays: dayPlays,
    ),
    topArtists: _rank(artistTally, limit: topCount, build: (key, tally) {
      return RankedName(
        name: key,
        plays: tally.plays,
        listened: _durationOf(tally.seconds),
      );
    }),
    topAlbums: _rank(albumTally, limit: topCount, build: (key, tally) {
      final (album, artist) = key;
      return RankedName(
        name: album,
        detail: _isRealName(artist, kUnknownArtist) ? artist : null,
        plays: tally.plays,
        listened: _durationOf(tally.seconds),
      );
    }),
    topSongs: _rank(songTally, limit: topCount, build: (key, tally) {
      final song = library[key];
      return RankedName(
        name: song?.title ?? displayTitleFromFilename(key),
        detail: _isRealName(song?.artist, kUnknownArtist) ? song?.artist : null,
        filename: key,
        coverUrl: song?.coverUrl,
        plays: tally.plays,
        listened: _durationOf(tally.seconds),
        isFavorite: favorites.contains(key),
      );
    }),
    listenedTrend: TrendChange(
      current: listenedSeconds.round(),
      previous: previousListenedSeconds.round(),
    ),
    playsTrend: TrendChange(
      current: plays,
      previous: previousPlays,
    ),
  );
}

double _secondsOf(PlayEventSample event) => event.played.inMilliseconds / 1000;

DateTime _windowStart(StatsRange range, DateTime today) => switch (range) {
      StatsRange.week => _addDays(today, -6),
      StatsRange.month => _addDays(today, -29),
      StatsRange.quarter => _addDays(today, -89),
      StatsRange.year => _addDays(today, -364),
      StatsRange.allTime => DateTime.fromMillisecondsSinceEpoch(0),
    };

/// Calendar-day arithmetic, not [Duration] arithmetic: adding 24 hours across a
/// daylight-saving boundary lands on 23:00 or 01:00 the next day, which would
/// silently shift every bucket and every streak.
DateTime _addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

List<HistogramBucket> _bucketize(
  List<double> listened,
  List<int> plays,
) {
  return List<HistogramBucket>.generate(
    listened.length,
    (index) => HistogramBucket(
      index: index,
      plays: plays[index],
      listened: _durationOf(listened[index]),
    ),
    growable: false,
  );
}

/// A dense series over the window: every day gets a point, including the empty
/// ones, so the chart shows silence instead of hiding it. Long windows switch
/// to months — 365 one-pixel bars is a smear, not a chart.
List<TrendPoint> _buildTrend({
  required StatsRange range,
  required DateTime today,
  required DateTime windowStart,
  required DateTime? firstPlayAt,
  required Map<DateTime, double> dayListened,
  required Map<DateTime, int> dayPlays,
}) {
  final monthly = range == StatsRange.year ||
      (firstPlayAt != null && _daysBetween(firstPlayAt, today) > 120);

  if (!monthly) {
    return [
      for (var day = windowStart; !day.isAfter(today); day = _addDays(day, 1))
        TrendPoint(
          start: day,
          label: _dayLabel(range, day),
          caption: _dayCaption(day),
          plays: dayPlays[day] ?? 0,
          listened: _durationOf(dayListened[day] ?? 0),
        ),
    ];
  }

  final points = <TrendPoint>[];
  // An all-time window opens at the epoch, so the series has to start where
  // the listening does — otherwise the screen plots six hundred silent months
  // before the first play.
  var cursor = DateTime(windowStart.year, windowStart.month);
  // Only an unbounded window can open before the listening does, and only that
  // one should be trimmed: a fixed range has to span its whole length even
  // when the first play of the window came late.
  if (windowStart.year <= 1971 && firstPlayAt != null) {
    final firstMonth = DateTime(firstPlayAt.year, firstPlayAt.month);
    if (firstMonth.isAfter(cursor)) cursor = firstMonth;
  }
  final last = DateTime(today.year, today.month);
  while (!cursor.isAfter(last)) {
    points.add(_monthPoint(cursor, dayListened, dayPlays));
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  return points;
}

TrendPoint _monthPoint(
  DateTime month,
  Map<DateTime, double> dayListened,
  Map<DateTime, int> dayPlays,
) {
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  var seconds = 0.0;
  var plays = 0;
  for (var day = 1; day <= daysInMonth; day++) {
    final key = DateTime(month.year, month.month, day);
    seconds += dayListened[key] ?? 0;
    plays += dayPlays[key] ?? 0;
  }
  final name = shortMonth(month.month);
  return TrendPoint(
    start: month,
    label: name,
    caption: '$name ${month.year}',
    plays: plays,
    listened: _durationOf(seconds),
  );
}

String _dayLabel(StatsRange range, DateTime day) {
  if (range == StatsRange.week) {
    return const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day.weekday - 1];
  }
  return '${day.day}';
}

String _dayCaption(DateTime day) =>
    '${weekdayName(day.weekday - 1)} ${day.day} ${shortMonth(day.month)}';

/// Fallback title for a play whose file is no longer in the library — the
/// scan can't tell us anything else about it.
String displayTitleFromFilename(String filename) {
  final slash = filename.lastIndexOf(RegExp(r'[/\\]'));
  final base = slash == -1 ? filename : filename.substring(slash + 1);
  final dot = base.lastIndexOf('.');
  return dot <= 0 ? base : base.substring(0, dot);
}

bool _isRealName(String? value, String sentinel) {
  if (value == null) return false;
  final trimmed = value.trim();
  return trimmed.isNotEmpty && trimmed != sentinel;
}

int _daysBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day)
    .difference(DateTime.utc(a.year, a.month, a.day))
    .inDays;

/// Consecutive listening days ending today, or yesterday if today is still
/// silent — a streak isn't dead until the day is actually over.
int _currentStreak(Set<DateTime> days, DateTime today) {
  var cursor = days.contains(today) ? today : _addDays(today, -1);
  if (!days.contains(cursor)) return 0;
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = _addDays(cursor, -1);
  }
  return streak;
}

int _longestStreak(Set<DateTime> days) {
  if (days.isEmpty) return 0;
  final sorted = days.toList()..sort();
  var best = 1;
  var run = 1;
  for (var i = 1; i < sorted.length; i++) {
    run = _daysBetween(sorted[i - 1], sorted[i]) == 1 ? run + 1 : 1;
    if (run > best) best = run;
  }
  return best;
}

Duration _durationOf(double seconds) =>
    Duration(milliseconds: (seconds * 1000).round());

/// Running totals for one ranked group.
class _Tally {
  int plays = 0;
  double seconds = 0;

  void absorb(double moreSeconds) {
    plays++;
    seconds += moreSeconds;
  }
}

extension _TallyMap<K> on Map<K, _Tally> {
  void addTally(K key, double seconds) {
    (this[key] ??= _Tally()).absorb(seconds);
  }
}

/// Sorts a tally map by plays (descending, name ascending to break ties) and
/// keeps the head.
List<RankedName> _rank<K extends Object>(
  Map<K, _Tally> tallies, {
  required int limit,
  required RankedName Function(K key, _Tally tally) build,
}) {
  final keys = tallies.keys.toList()
    ..sort((a, b) {
      final byCount = tallies[b]!.plays.compareTo(tallies[a]!.plays);
      return byCount != 0 ? byCount : _keyOf(a).compareTo(_keyOf(b));
    });
  return keys
      .take(limit)
      .map((key) => build(key, tallies[key]!))
      .toList(growable: false);
}

String _keyOf(Object key) => switch (key) {
      String value => value,
      (String first, String second) => '$first|$second',
      _ => key.toString(),
    };
