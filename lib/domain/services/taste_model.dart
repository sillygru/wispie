/// Smart shuffle's taste model.
///
/// Turns play history into raw taste mass per song and per artist, on two
/// timescales: long-term (90 day half-life) and recent trend (10 day half-life,
/// 30 day horizon). Masses are not normalized. How much of the shuffle goes to
/// each artist is decided downstream, so this only measures evidence.
///
/// The rules live in the native core (`rust/wispie_core/src/taste.rs`); this
/// file is the wire shape around one `taste_snapshot` request.
library;

import 'dart:typed_data';

import '../models/play_source.dart';
import 'native_accel.dart';

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

  const SongMeta({this.artist = '', this.album = ''});
}

class TasteInputs {
  final List<PlaySignal> events;

  /// Keyed by filename. Should cover the whole library, not only played songs.
  final Map<String, SongMeta> meta;
  final Set<String> favorites;
  final Set<String> suggestLess;
  final DateTime now;

  /// filename -> epoch seconds the app added the row, for the whole library.
  ///
  /// Used only to tell a genuinely fresh arrival from the bulk of the library.
  final Map<String, double> addedAt;

  const TasteInputs({
    required this.events,
    required this.meta,
    required this.now,
    this.favorites = const {},
    this.suggestLess = const {},
    this.addedAt = const {},
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

  /// filename -> 0..1 how much newer than the rest of the library this row is.
  ///
  /// Empty for a library that arrived in one go: with nothing older to be new
  /// against, "newly added" is not a preference, it is the whole library.
  final Map<String, double> newness;

  const TasteSnapshot({
    required this.songs,
    required this.artists,
    required this.coPlay,
    required this.artistCoPlay,
    this.newness = const {},
  });
}

/// Normalized artist key. Untagged songs get a per-file key so they never pool.
///
/// YouTube channel decoration is stripped: a streamed track credited to
/// `Aurora - Topic` or `AuroraVEVO` is the same artist as a local file tagged
/// `Aurora`, and keying them apart would hide half of a mixed history.
String tasteArtistKey(String artist, String filename) =>
    tasteArtistKeys([(artist: artist, filename: filename)]).first;

/// [tasteArtistKey] for a batch, in the order given.
List<String> tasteArtistKeys(List<({String artist, String filename})> songs) =>
    NativeAccel.tasteArtistKeys([
      for (final song in songs) [song.artist, song.filename],
    ]);

/// One event row: filename index, timestamp, ratio, seconds, session index,
/// source code.
const int _eventStride = 33;
const int _noSession = 0xFFFFFFFF;

/// Builds the taste snapshot. Runs in an isolate in production, so it must stay
/// free of Flutter and platform calls.
TasteSnapshot buildTasteSnapshot(TasteInputs inputs) {
  final events = [
    for (final event in inputs.events)
      if (event.timestamp.isFinite) event,
  ];

  final filenames = <String>[];
  final fileIndex = <String, int>{};
  final artists = <String>[];
  final sessions = <String>[];
  final sessionIndex = <String, int>{};

  final rows = ByteData(events.length * _eventStride);
  for (var i = 0; i < events.length; i++) {
    final event = events[i];
    final file = fileIndex.putIfAbsent(event.filename, () {
      filenames.add(event.filename);
      artists.add(inputs.meta[event.filename]?.artist ?? '');
      return filenames.length - 1;
    });
    final sessionId = event.sessionId;
    final session = sessionId == null
        ? _noSession
        : sessionIndex.putIfAbsent(sessionId, () {
            sessions.add(sessionId);
            return sessions.length - 1;
          });

    final offset = i * _eventStride;
    rows.setUint32(offset, file, Endian.little);
    rows.setFloat64(offset + 4, event.timestamp, Endian.little);
    rows.setFloat64(
      offset + 12,
      event.ratio.isFinite ? event.ratio : 0.0,
      Endian.little,
    );
    rows.setFloat64(
      offset + 20,
      event.secondsPlayed.isFinite ? event.secondsPlayed : 0.0,
      Endian.little,
    );
    rows.setUint32(offset + 28, session, Endian.little);
    rows.setUint8(offset + 32, _sourceCode(event.source));
  }

  final addedFiles = <String>[];
  final addedValues = <double>[];
  for (final entry in inputs.addedAt.entries) {
    if (!entry.value.isFinite || entry.value <= 0) continue;
    addedFiles.add(entry.key);
    addedValues.add(entry.value);
  }
  final added = ByteData(addedValues.length * 8);
  for (var i = 0; i < addedValues.length; i++) {
    added.setFloat64(i * 8, addedValues[i], Endian.little);
  }

  final bytes = Uint8List(rows.lengthInBytes + added.lengthInBytes)
    ..setAll(0, rows.buffer.asUint8List())
    ..setAll(rows.lengthInBytes, added.buffer.asUint8List());

  return _snapshotFrom(NativeAccel.tasteSnapshot({
    'now': inputs.now.millisecondsSinceEpoch / 1000.0,
    'eventCount': events.length,
    'filenames': filenames,
    'artists': artists,
    'sessions': sessions,
    'addedFiles': addedFiles,
  }, bytes));
}

int _sourceCode(PlaySource? source) => switch (source) {
      PlaySource.manual => 1,
      PlaySource.shuffle => 2,
      PlaySource.queued => 3,
      PlaySource.linear => 4,
      null => 0,
    };

TasteSnapshot _snapshotFrom(Map<String, dynamic> reply) {
  final songs = reply['songs'] as Map<String, dynamic>? ?? const {};
  final names =
      (songs['filenames'] as List<dynamic>? ?? const []).cast<String>();
  final trend = _doubles(songs['trendMass']);
  final long = _doubles(songs['longMass']);
  final saturation = _doubles(songs['saturation']);
  final skipRate = _doubles(songs['skipRate']);
  final playCount = songs['playCount'] as List<dynamic>? ?? const [];
  final lastPlayed = songs['lastPlayed'] as List<dynamic>? ?? const [];

  final artists = reply['artists'] as Map<String, dynamic>? ?? const {};
  final artistNames =
      (artists['keys'] as List<dynamic>? ?? const []).cast<String>();
  final artistTrend = _doubles(artists['trendMass']);
  final artistLong = _doubles(artists['longMass']);

  final newness = reply['newness'] as Map<String, dynamic>? ?? const {};
  final newnessNames =
      (newness['filenames'] as List<dynamic>? ?? const []).cast<String>();
  final newnessValues = _doubles(newness['values']);

  return TasteSnapshot(
    songs: {
      for (var i = 0; i < names.length; i++)
        names[i]: SongTaste(
          trendMass: trend[i],
          longMass: long[i],
          saturation: saturation[i],
          skipRate: skipRate[i],
          playCount: (playCount[i] as num).toInt(),
          lastPlayed: (lastPlayed[i] as num?)?.toDouble(),
        ),
    },
    artists: {
      for (var i = 0; i < artistNames.length; i++)
        artistNames[i]: ArtistTaste(
          trendMass: artistTrend[i],
          longMass: artistLong[i],
        ),
    },
    coPlay: _transitions(reply['coPlay']),
    artistCoPlay: _transitions(reply['artistCoPlay']),
    newness: {
      for (var i = 0; i < newnessNames.length; i++)
        newnessNames[i]: newnessValues[i],
    },
  );
}

List<double> _doubles(Object? raw) => [
      for (final value in raw as List<dynamic>? ?? const [])
        (value as num).toDouble(),
    ];

Map<String, Map<String, double>> _transitions(Object? raw) => {
      for (final entry in (raw as Map<String, dynamic>? ?? const {}).entries)
        entry.key: {
          for (final row
              in (entry.value as Map<String, dynamic>? ?? const {}).entries)
            row.key: _double(row.value),
        },
    };

double _double(Object? value) => (value as num?)?.toDouble() ?? 0.0;
