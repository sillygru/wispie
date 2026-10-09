/// Smart shuffle's taste model.
///
/// Turns play history into raw taste mass per song and per artist, on two
/// timescales: long-term (90 day half-life) and recent trend (10 day half-life,
/// 30 day horizon). Masses are not normalized. How much of the shuffle goes to
/// each artist is decided downstream, so this file only measures evidence.
///
/// Negative evidence is deliberately weak: browsing taps, bursts of skips,
/// manual picks and skips later followed by a full listen all count for less.
///
/// Pure by design: no I/O, no clock reads beyond the injected [TasteInputs.now].
/// Legacy personalities keep using `song_affinity.dart`.
library;

import 'dart:math';

import '../models/play_source.dart';
import 'song_affinity.dart';

/// One `playevent` row. [timestamp] is epoch seconds, as in the database.
class PlaySignal {
  final String filename;
  final double timestamp;
  final double ratio;
  final double secondsPlayed;
  final String? sessionId;
  final PlaySource? source;

  const PlaySignal({
    required this.filename,
    required this.timestamp,
    required this.ratio,
    required this.secondsPlayed,
    this.sessionId,
    this.source,
  });
}

class SongMeta {
  final String artist;
  final String album;
  final List<String> moods;

  const SongMeta({this.artist = '', this.album = '', this.moods = const []});
}

class TasteInputs {
  final List<PlaySignal> events;

  /// Keyed by filename. Should cover the whole library, not only played songs.
  final Map<String, SongMeta> meta;
  final Set<String> favorites;
  final Set<String> suggestLess;
  final DateTime now;

  const TasteInputs({
    required this.events,
    required this.meta,
    required this.now,
    this.favorites = const {},
    this.suggestLess = const {},
  });
}

class SongTaste {
  final double trendMass;
  final double longMass;

  /// Decayed count of recent positive plays. Damps over-exposure downstream.
  final double saturation;

  /// Recency-weighted share of negative evidence, 0..1.
  final double skipRate;
  final int playCount;

  /// Epoch seconds, or null if never played.
  final double? lastPlayed;

  const SongTaste({
    required this.trendMass,
    required this.longMass,
    required this.saturation,
    required this.skipRate,
    required this.playCount,
    required this.lastPlayed,
  });
}

class ArtistTaste {
  final double trendMass;
  final double longMass;

  const ArtistTaste({required this.trendMass, required this.longMass});
}

class TasteSnapshot {
  /// Songs with at least one play event. Unplayed songs have no entry.
  final Map<String, SongTaste> songs;

  /// Keyed by [tasteArtistKey].
  final Map<String, ArtistTaste> artists;

  /// `a -> b` co-play strength, normalized per `a` to 0..1, top 20 targets only.
  final Map<String, Map<String, double>> coPlay;

  /// `artist -> artist` transition strength, normalized per source to 0..1,
  /// top 10 targets only. Trend window only.
  final Map<String, Map<String, double>> artistCoPlay;

  const TasteSnapshot({
    required this.songs,
    required this.artists,
    required this.coPlay,
    required this.artistCoPlay,
  });
}

/// Normalized artist key. Untagged songs get a per-file key so they never pool.
String tasteArtistKey(String artist, String filename) {
  final a = artist.trim().toLowerCase();
  return a.isEmpty ? '\u0000$filename' : a;
}

const double _negativeCap = 3.0;
const double _fullListenRatio = 0.85;
const double _shortListenSeconds = 3.0;
const double _longListenSeconds = 240.0;
const double _burstWindowSeconds = 90.0;
const double _forgivenessFactor = 0.3;
const double _replayBonus = 0.5;
const int _coPlayTop = 20;
const int _artistCoPlayTop = 10;

/// Builds the taste snapshot. Runs in an isolate in production, so it must
/// stay free of Flutter and platform calls.
TasteSnapshot buildTasteSnapshot(TasteInputs inputs) {
  final nowSec = inputs.now.millisecondsSinceEpoch / 1000.0;

  final events = <PlaySignal>[
    for (final e in inputs.events)
      if (e.timestamp.isFinite) e,
  ]..sort(_bySessionThenTime);
  final n = events.length;

  final ratio = List<double>.filled(n, 0.0);
  final seconds = List<double>.filled(n, 0.0);
  final quality = List<double>.filled(n, 0.0);
  for (var i = 0; i < n; i++) {
    final e = events[i];
    final r = e.ratio.isFinite ? e.ratio.clamp(0.0, 1.0) : 0.0;
    final secs = e.secondsPlayed.isFinite ? e.secondsPlayed : 0.0;
    var q = _baseQuality(r);
    if (secs >= _longListenSeconds) q = max(q, 0.6);
    ratio[i] = r;
    seconds[i] = secs;
    quality[i] = q;
  }

  final burst = _burstFlags(events, quality);
  final forgiven = _forgivenessFlags(events, quality, ratio);
  final replay = _replayFlags(events, ratio);
  final artistOf = [
    for (final e in events)
      tasteArtistKey(inputs.meta[e.filename]?.artist ?? '', e.filename),
  ];

  final ledger = _Ledger();
  final coRaw = <String, Map<String, double>>{};
  final artistCoRaw = <String, Map<String, double>>{};

  for (var i = 0; i < n; i++) {
    final e = events[i];
    final d = _decayAt((nowSec - e.timestamp) / 86400.0);
    final q = quality[i];

    double w;
    if (q > 0) {
      w = q * _positiveSourceMultiplier(e.source);
    } else if (q < 0) {
      var m = _negativeSourceMultiplier(e.source);
      if (seconds[i] < _shortListenSeconds) m *= 0.1;
      if (burst[i]) m *= 0.15;
      if (forgiven[i]) m *= _forgivenessFactor;
      w = q * m;
    } else {
      w = 0.0;
    }

    ledger.credit(e.filename, artistOf[i], w, e.timestamp, d, countPlay: true);
    if (replay[i]) {
      ledger.credit(e.filename, artistOf[i], _replayBonus, e.timestamp, d,
          countPlay: false);
    }

    if (i > 0 &&
        e.sessionId != null &&
        events[i - 1].sessionId == e.sessionId &&
        quality[i - 1] >= 0.5 &&
        q >= 0.5 &&
        d.trend > 0) {
      final prev = events[i - 1];
      if (prev.filename != e.filename) {
        final row = coRaw.putIfAbsent(prev.filename, () => <String, double>{});
        row[e.filename] = (row[e.filename] ?? 0.0) + d.trend;
      }
      if (artistOf[i - 1] != artistOf[i]) {
        final row =
            artistCoRaw.putIfAbsent(artistOf[i - 1], () => <String, double>{});
        row[artistOf[i]] = (row[artistOf[i]] ?? 0.0) + d.trend;
      }
    }
  }

  final songs = <String, SongTaste>{
    for (final entry in ledger.songs.entries)
      entry.key: SongTaste(
        trendMass: entry.value.trendMass,
        longMass: entry.value.longMass,
        saturation: entry.value.saturation,
        skipRate: entry.value.totalW > 0
            ? entry.value.skipW / entry.value.totalW
            : 0.0,
        playCount: entry.value.playCount,
        lastPlayed:
            entry.value.lastPlayed.isFinite ? entry.value.lastPlayed : null,
      ),
  };

  final artists = <String, ArtistTaste>{
    for (final entry in ledger.artists.entries)
      entry.key: ArtistTaste(
        trendMass: entry.value.trendMass,
        longMass: entry.value.longMass,
      ),
  };

  return TasteSnapshot(
    songs: songs,
    artists: artists,
    coPlay: _topNormalized(coRaw, _coPlayTop),
    artistCoPlay: _topNormalized(artistCoRaw, _artistCoPlayTop),
  );
}

Map<String, Map<String, double>> _topNormalized(
  Map<String, Map<String, double>> raw,
  int top,
) {
  final out = <String, Map<String, double>>{};
  raw.forEach((a, row) {
    final sorted = row.entries.where((e) => e.value > 0).toList()
      ..sort((x, y) => y.value.compareTo(x.value));
    if (sorted.isEmpty) return;
    final capped = sorted.take(top).toList();
    final peak = capped.first.value;
    out[a] = {for (final e in capped) e.key: e.value / peak};
  });
  return out;
}

int _bySessionThenTime(PlaySignal a, PlaySignal b) {
  final s = (a.sessionId ?? '').compareTo(b.sessionId ?? '');
  return s != 0 ? s : a.timestamp.compareTo(b.timestamp);
}

/// Base evidence of one play from how much of it was heard.
double _baseQuality(double ratio) {
  if (ratio >= _fullListenRatio) return 1.0;
  if (ratio >= 0.5) return 0.5 + 0.5 * (ratio - 0.5) / 0.35;
  if (ratio >= 0.25) return 0.5 * (ratio - 0.25) / 0.25;
  return -1.0;
}

/// Skips that are one of at least three within 90 s in the same session.
/// Events are sorted by session then time, so a two-pointer window suffices.
List<bool> _burstFlags(List<PlaySignal> events, List<double> quality) {
  final n = events.length;
  final burst = List<bool>.filled(n, false);
  var gs = 0;
  while (gs < n) {
    var ge = gs + 1;
    while (ge < n && events[ge].sessionId == events[gs].sessionId) {
      ge++;
    }
    if (events[gs].sessionId != null) {
      final skips = <int>[
        for (var i = gs; i < ge; i++)
          if (quality[i] < 0) i,
      ];
      var lo = 0;
      var hi = -1;
      for (var k = 0; k < skips.length; k++) {
        final t = events[skips[k]].timestamp;
        while (hi + 1 < skips.length &&
            events[skips[hi + 1]].timestamp <= t + _burstWindowSeconds) {
          hi++;
        }
        while (events[skips[lo]].timestamp < t - _burstWindowSeconds) {
          lo++;
        }
        if (hi - lo >= 2) burst[skips[k]] = true;
      }
    }
    gs = ge;
  }
  return burst;
}

/// A skip is forgiven if the same song was fully heard at some later time.
/// Walks newest to oldest so one set answers "completed later?" in O(1).
List<bool> _forgivenessFlags(
  List<PlaySignal> events,
  List<double> quality,
  List<double> ratio,
) {
  final n = events.length;
  final forgiven = List<bool>.filled(n, false);
  final order = List<int>.generate(n, (i) => i)
    ..sort((a, b) => events[b].timestamp.compareTo(events[a].timestamp));
  final completedLater = <String>{};
  for (final i in order) {
    final fn = events[i].filename;
    if (quality[i] < 0 && completedLater.contains(fn)) forgiven[i] = true;
    if (ratio[i] >= _fullListenRatio) completedLater.add(fn);
  }
  return forgiven;
}

/// Marks the second full listen of a song within one session.
List<bool> _replayFlags(List<PlaySignal> events, List<double> ratio) {
  final replay = List<bool>.filled(events.length, false);
  final completions = <String, int>{};
  for (var i = 0; i < events.length; i++) {
    final e = events[i];
    if (e.sessionId == null || ratio[i] < _fullListenRatio) continue;
    final key = '${e.sessionId}\u0000${e.filename}';
    final c = (completions[key] ?? 0) + 1;
    completions[key] = c;
    if (c == 2) replay[i] = true;
  }
  return replay;
}

double _positiveSourceMultiplier(PlaySource? source) => switch (source) {
      PlaySource.queued => 1.4,
      PlaySource.manual => 1.3,
      PlaySource.shuffle || PlaySource.radio => 0.8,
      PlaySource.linear || null => 1.0,
    };

double _negativeSourceMultiplier(PlaySource? source) => switch (source) {
      PlaySource.shuffle || PlaySource.radio => 1.0,
      PlaySource.queued => 0.5,
      PlaySource.manual => 0.3,
      PlaySource.linear || null => 0.6,
    };

class _Decay {
  final double long;
  final double trend;
  final double neg;
  final double negTrend;
  final double sat;

  const _Decay({
    required this.long,
    required this.trend,
    required this.neg,
    required this.negTrend,
    required this.sat,
  });
}

/// Positive evidence decays on the long/trend half-lives. Negative evidence
/// decays fast (10 days) so old skips stop mattering quickly.
_Decay _decayAt(double ageDays) {
  final age = ageDays < 0 ? 0.0 : ageDays;
  final neg = decayFactor(age, 10);
  return _Decay(
    long: decayFactor(age, 90),
    trend: age <= 30 ? decayFactor(age, 10) : 0.0,
    neg: neg,
    negTrend: age <= 30 ? neg : 0.0,
    sat: decayFactor(age, 2),
  );
}

class _Acc {
  double posLong = 0.0;
  double negLong = 0.0;
  double posTrend = 0.0;
  double negTrend = 0.0;
  double saturation = 0.0;
  double skipW = 0.0;
  double totalW = 0.0;
  int playCount = 0;
  double lastPlayed = double.negativeInfinity;

  double get longMass => max(0.0, posLong - min(negLong, _negativeCap));
  double get trendMass => max(0.0, posTrend - min(negTrend, _negativeCap));
}

void _addEvidence(_Acc a, double w, double ts, _Decay d,
    {required bool countPlay}) {
  final m = w.abs();
  if (w > 0) {
    a.posLong += w * d.long;
    a.posTrend += w * d.trend;
    a.saturation += d.sat;
  } else {
    a.negLong += m * d.neg;
    a.negTrend += m * d.negTrend;
  }
  if (w < 0) a.skipW += m * d.long;
  a.totalW += m * d.long;
  if (countPlay) {
    a.playCount++;
    a.lastPlayed = max(a.lastPlayed, ts);
  }
}

/// Per-entity evidence for songs and artists.
class _Ledger {
  final songs = <String, _Acc>{};
  final artists = <String, _Acc>{};

  void credit(
    String filename,
    String artistKey,
    double w,
    double ts,
    _Decay d, {
    required bool countPlay,
  }) {
    _addEvidence(songs.putIfAbsent(filename, () => _Acc()), w, ts, d,
        countPlay: countPlay);
    _addEvidence(artists.putIfAbsent(artistKey, () => _Acc()), w, ts, d,
        countPlay: countPlay);
  }
}
