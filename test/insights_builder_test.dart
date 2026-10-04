import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/domain/models/listening_insights.dart';
import 'package:wispie/domain/services/insights_builder.dart';
import 'package:wispie/models/song.dart';

/// Fixed "now" so every window boundary in these tests is a constant rather
/// than whatever day the suite happens to run on.
final DateTime now = DateTime(2026, 3, 15, 21, 30);

Song _song(
  String filename, {
  String? title,
  String artist = 'Artist',
  String album = 'Album',
  String? coverUrl,
}) =>
    Song(
      title: title ?? filename,
      artist: artist,
      album: album,
      filename: filename,
      url: 'file://$filename',
      coverUrl: coverUrl,
    );

/// A completed play: [minutes] of a 4-minute track.
PlayEventSample _play(
  String filename,
  DateTime at, {
  int minutes = 4,
  double ratio = 1.0,
}) =>
    PlayEventSample(
      filename: filename,
      at: at,
      played: Duration(minutes: minutes),
      playRatio: ratio,
    );

/// A bounce: a couple of seconds, nowhere near the track length.
PlayEventSample _skip(String filename, DateTime at, {int seconds = 3}) =>
    PlayEventSample(
      filename: filename,
      at: at,
      played: Duration(seconds: seconds),
      playRatio: 0.02,
    );

ListeningInsights _build(
  List<PlayEventSample> events, {
  List<Song> library = const [],
  Set<String> favorites = const {},
  StatsRange range = StatsRange.month,
}) =>
    buildInsights(
      events: events,
      library: {for (final song in library) song.filename: song},
      favorites: favorites,
      range: range,
      now: now,
    );

void main() {
  group('PlayEventSample', () {
    test('derives play_ratio from the track length for pre-ratio rows', () {
      final sample = PlayEventSample.fromRow({
        'song_filename': 'a.mp3',
        'timestamp': 1000.0,
        'duration_played': 60.0,
        'total_length': 120.0,
        'play_ratio': null,
      });

      expect(sample.playRatio, closeTo(0.5, 1e-9));
      expect(sample.countsAsPlay, isTrue);
    });

    test('a two-second bounce is a skip, not a play', () {
      final sample = PlayEventSample.fromRow({
        'song_filename': 'a.mp3',
        'timestamp': 1000.0,
        'duration_played': 2.0,
        'total_length': 240.0,
        'play_ratio': null,
      });

      expect(sample.isSkip, isTrue);
      expect(sample.countsAsPlay, isFalse);
    });

    test('a long listen at a low ratio still counts as a play', () {
      final sample = PlayEventSample.fromRow({
        'song_filename': 'a.mp3',
        'timestamp': 1000.0,
        'duration_played': 95.0,
        'total_length': 600.0,
        'play_ratio': null,
      });

      expect(sample.isSkip, isFalse);
      expect(sample.countsAsPlay, isTrue);
    });
  });

  group('windowing', () {
    test('a month covers 30 days back from today, inclusive', () {
      final insights = _build(
        [
          _play('a.mp3', DateTime(2026, 3, 15, 12)),
          _play('b.mp3', DateTime(2026, 2, 15, 12)),
          _play('c.mp3', DateTime(2026, 2, 13, 12)),
        ],
      );

      expect(insights.plays, 2);
    });

    test('a week covers 7 days back from today, inclusive', () {
      final insights = _build(
        [
          _play('a.mp3', DateTime(2026, 3, 15, 12)),
          _play('b.mp3', DateTime(2026, 3, 9, 12)),
          _play('c.mp3', DateTime(2026, 3, 8, 12)),
        ],
        range: StatsRange.week,
      );

      expect(insights.plays, 2);
    });

    test('all time reaches past the 30-day window', () {
      final insights = _build(
        [
          _play('a.mp3', DateTime(2026, 3, 15, 12)),
          _play('b.mp3', DateTime(2019, 7, 4, 12)),
        ],
        range: StatsRange.allTime,
      );

      expect(insights.plays, 2);
    });

    test('events after today never leak in', () {
      final insights = _build([
        _play('a.mp3', DateTime(2026, 3, 15, 12)),
        _play('b.mp3', DateTime(2026, 3, 16, 3)),
      ]);

      expect(insights.plays, 1);
    });
  });

  group('totals', () {
    test('counts plays and skips separately and sums listening time', () {
      final insights = _build([
        _play('a.mp3', DateTime(2026, 3, 15, 9), minutes: 4),
        _play('a.mp3', DateTime(2026, 3, 15, 10), minutes: 6),
        _skip('b.mp3', DateTime(2026, 3, 15, 11)),
      ]);

      expect(insights.plays, 2);
      expect(insights.skips, 1);
      expect(insights.events, 3);
      expect(insights.listened, const Duration(minutes: 10, seconds: 3));
      expect(insights.skipRate, closeTo(1 / 3, 1e-9));
    });

    test('unique tracks counts distinct filenames, not plays', () {
      final insights = _build([
        _play('a.mp3', DateTime(2026, 3, 15, 9)),
        _play('a.mp3', DateTime(2026, 3, 15, 10)),
        _play('b.mp3', DateTime(2026, 3, 14, 10)),
      ]);

      expect(insights.uniqueSongs, 2);
      expect(insights.activeDays, 2);
    });

    test('explorer share is measured against the current library', () {
      final insights = _build(
        [
          _play('a.mp3', DateTime(2026, 3, 15, 9)),
          _play('b.mp3', DateTime(2026, 3, 15, 10)),
          // Played, but the file has since left the library.
          _play('gone.mp3', DateTime(2026, 3, 15, 11)),
        ],
        library: [_song('a.mp3'), _song('b.mp3')],
      );

      expect(insights.librarySize, 2);
      expect(insights.uniqueSongs, 3);
      expect(insights.discoveredInLibrary, 2);
      expect(insights.exploredShare, closeTo(1.0, 1e-9));
    });

    test('favourite share counts plays of favourited tracks', () {
      final insights = _build(
        [
          _play('a.mp3', DateTime(2026, 3, 15, 9)),
          _play('a.mp3', DateTime(2026, 3, 15, 10)),
          _play('b.mp3', DateTime(2026, 3, 15, 11)),
        ],
        library: [_song('a.mp3'), _song('b.mp3')],
        favorites: {'a.mp3'},
      );

      expect(insights.favoritePlays, 2);
      expect(insights.favoriteShare, closeTo(2 / 3, 1e-9));
    });

    test('no events means empty, not zero-filled nonsense', () {
      final insights = _build(const []);

      expect(insights.isEmpty, isTrue);
      expect(insights.skipRate, 0);
      expect(insights.favoriteShare, 0);
      expect(insights.exploredShare, 0);
      expect(insights.averageDay, Duration.zero);
      expect(insights.peakHour, isNull);
      expect(insights.peakWeekday, isNull);
      expect(insights.peakTrendPoint, isNull);
    });
  });

  group('histograms', () {
    test('hours and weekdays bucket by local clock time', () {
      final insights = _build([
        _play('a.mp3', DateTime(2026, 3, 15, 0, 30), minutes: 60),
        _play('a.mp3', DateTime(2026, 3, 15, 0, 45), minutes: 30),
        _play('a.mp3', DateTime(2026, 3, 11, 14), minutes: 10),
      ]);

      expect(insights.byHour, hasLength(24));
      expect(insights.byHour[0].listened, const Duration(minutes: 90));
      expect(insights.byHour[14].listened, const Duration(minutes: 10));
      expect(insights.peakHour, 0);

      expect(insights.byWeekday, hasLength(7));
      // 2026-03-15 is a Sunday, so it lands on index 6.
      expect(insights.byWeekday[6].listened, const Duration(minutes: 90));
      // 2026-03-11 is the Wednesday of the same week: index 2.
      expect(insights.byWeekday[2].listened, const Duration(minutes: 10));
      expect(insights.peakWeekday, 6);
    });

    test('skips count towards when-you-listen but not towards plays', () {
      final insights = _build([
        _play('a.mp3', DateTime(2026, 3, 15, 9)),
        _skip('b.mp3', DateTime(2026, 3, 15, 9)),
      ]);

      expect(insights.byHour[9].plays, 2);
      expect(insights.plays, 1);
    });
  });

  group('trend series', () {
    test('is dense: every day in the window has a point', () {
      final insights = _build(
        [_play('a.mp3', DateTime(2026, 3, 15, 9))],
        range: StatsRange.week,
      );

      expect(insights.trend, hasLength(7));
      expect(insights.trend.last.listened, const Duration(minutes: 4));
      expect(insights.trend.first.listened, Duration.zero);
    });

    test('switches to months once the history is long', () {
      final insights = _build(
        [
          _play('a.mp3', DateTime(2026, 3, 15, 9)),
          _play('a.mp3', DateTime(2025, 6, 2, 9)),
        ],
        range: StatsRange.allTime,
      );

      final labels = insights.trend.map((point) => point.label).toSet();
      expect(labels, containsAll(<String>['Mar', 'Jun']));
      // Ten months of history, not the fifty-odd silent ones before it.
      expect(insights.trend, hasLength(10));
    });

    test('a year is reported as twelve months, not 365 days', () {
      final insights = _build(
        [_play('a.mp3', DateTime(2026, 3, 15, 9))],
        range: StatsRange.year,
      );

      // Thirteen: the window opens mid-March 2025 and closes in March 2026, so
      // both of those months hold part of the range.
      expect(insights.trend, hasLength(13));
    });
  });

  group('streaks', () {
    test('counts consecutive days ending today', () {
      final insights = _build([
        _play('a.mp3', DateTime(2026, 3, 13, 9)),
        _play('a.mp3', DateTime(2026, 3, 14, 9)),
        _play('a.mp3', DateTime(2026, 3, 15, 9)),
        _play('a.mp3', DateTime(2026, 3, 10, 9)),
      ]);

      expect(insights.currentStreak, 3);
      expect(insights.longestStreak, 3);
    });

    test('survives a today that has not been listened to yet', () {
      final insights = _build([
        _play('a.mp3', DateTime(2026, 3, 13, 9)),
        _play('a.mp3', DateTime(2026, 3, 14, 9)),
      ]);

      expect(insights.currentStreak, 2);
    });

    test('ends after a missed day', () {
      final insights = _build([
        _play('a.mp3', DateTime(2026, 3, 10, 9)),
        _play('a.mp3', DateTime(2026, 3, 11, 9)),
      ]);

      expect(insights.currentStreak, 0);
      expect(insights.longestStreak, 2);
    });

    test('is measured over all history, not the selected window', () {
      final insights = _build(
        [
          _play('a.mp3', DateTime(2026, 1, 1, 9)),
          _play('a.mp3', DateTime(2026, 1, 2, 9)),
          _play('a.mp3', DateTime(2026, 3, 15, 9)),
        ],
        range: StatsRange.week,
      );

      expect(insights.plays, 1);
      expect(insights.longestStreak, 2);
    });

    test('crosses a month boundary without breaking the run', () {
      final insights = _build([
        _play('a.mp3', DateTime(2026, 2, 28, 9)),
        _play('a.mp3', DateTime(2026, 3, 1, 9)),
      ]);

      expect(insights.longestStreak, 2);
    });
  });

  group('previous-period comparison', () {
    test('compares the window against the one immediately before it', () {
      final insights = _build([
        // Previous 30 days (2026-01-15 to 2026-02-13): one 10-minute play.
        _play('a.mp3', DateTime(2026, 2, 10, 9), minutes: 10),
        // Current 30 days: two 10-minute plays.
        _play('a.mp3', DateTime(2026, 3, 14, 9), minutes: 10),
        _play('a.mp3', DateTime(2026, 3, 15, 9), minutes: 10),
      ]);

      expect(insights.listenedTrend.current, 1200);
      expect(insights.listenedTrend.previous, 600);
      expect(insights.listenedTrend.change, closeTo(1.0, 1e-9));
      expect(insights.playsTrend.current, 2);
      expect(insights.playsTrend.previous, 1);
    });

    test('has no baseline for an all-time window', () {
      final insights = _build(
        [_play('a.mp3', DateTime(2026, 3, 15, 9))],
        range: StatsRange.allTime,
      );

      expect(insights.listenedTrend.hasBaseline, isFalse);
      expect(insights.listenedTrend.change, isNull);
    });

    test('does not divide by a silent previous window', () {
      final insights = _build([
        _play('a.mp3', DateTime(2026, 3, 15, 9)),
      ]);

      expect(insights.listenedTrend.previous, 0);
      expect(insights.listenedTrend.change, isNull);
    });
  });

  group('ranked lists', () {
    test('orders by plays and drops the scanner sentinels', () {
      final insights = _build(
        [
          _play('a.mp3', DateTime(2026, 3, 15, 9)),
          _play('a.mp3', DateTime(2026, 3, 15, 10)),
          _play('a.mp3', DateTime(2026, 3, 15, 11)),
          _play('b.mp3', DateTime(2026, 3, 15, 12)),
          _play('untagged.mp3', DateTime(2026, 3, 15, 13)),
        ],
        library: [
          _song('a.mp3', title: 'A', artist: 'Alpha', album: 'One'),
          _song('b.mp3', title: 'B', artist: 'Beta', album: 'Two'),
          _song('untagged.mp3', artist: kUnknownArtist, album: kUnknownAlbum),
        ],
      );

      expect(insights.topArtists.map((e) => e.name), ['Alpha', 'Beta']);
      expect(insights.topArtists.first.plays, 3);
      expect(insights.topAlbums.map((e) => e.name), ['One', 'Two']);
      // The untagged file's *title* is its filename — that is what the scan
      // wrote, and the row has nothing better to show.
      expect(
        insights.topSongs.map((e) => e.name),
        ['A', 'B', 'untagged.mp3'],
      );
      expect(insights.topSongs.last.detail, isNull);
    });

    test('a song outside the library falls back to its filename', () {
      final insights = _build([
        _play('/music/Artist/Fallback Track.mp3', DateTime(2026, 3, 15, 9)),
      ]);

      expect(insights.topSongs.single.name, 'Fallback Track');
      expect(insights.topSongs.single.filename,
          '/music/Artist/Fallback Track.mp3');
      expect(insights.discoveredInLibrary, 0);
    });

    test('skips never reach a leaderboard', () {
      final insights = _build([
        _skip('a.mp3', DateTime(2026, 3, 15, 9)),
      ]);

      expect(insights.topSongs, isEmpty);
      expect(insights.topArtists, isEmpty);
    });

    test('honours the requested row count', () {
      final insights = _build(
        [
          for (var i = 0; i < 30; i++)
            _play('song_$i.mp3', DateTime(2026, 3, 15, 9, i)),
        ],
        library: [
          for (var i = 0; i < 30; i++) _song('song_$i.mp3'),
        ],
      );

      expect(insights.topSongs, hasLength(10));
      expect(insights.topArtists, hasLength(1));
    });
  });
}
