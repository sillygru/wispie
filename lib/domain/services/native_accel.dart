import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../data/rust/wispie_core.dart';
import '../models/beat_map.dart';
import '../../models/song.dart';
import 'search_taste.dart';

class NativeRgb {
  final int red;
  final int green;
  final int blue;

  const NativeRgb(this.red, this.green, this.blue);
}

class NativeSwatch extends NativeRgb {
  final int population;

  const NativeSwatch(super.red, super.green, super.blue, this.population);
}

class NativePalette {
  final List<NativeSwatch> swatches;
  final NativeRgb accent;
  final bool isNeutral;
  final NativeRgb mixedColor;

  const NativePalette({
    required this.swatches,
    required this.accent,
    required this.isNeutral,
    required this.mixedColor,
  });
}

/// Synchronous access to the native hot paths.
///
/// These paths are Rust only: there is no Dart implementation to fall back on,
/// so a build without the core throws, exactly as the scanner does.
class NativeAccel {
  const NativeAccel._();

  static int _generation = 0;
  static List<Song>? _corpusSongs;
  static SearchTaste? _corpusTaste;

  static Map<String, dynamic> _ask(
    Map<String, Object?> request, {
    void Function(int done, int total)? onProgress,
  }) {
    Map<String, dynamic>? items;
    final code = WispieCore.run(request, onEvent: (kind, payload) {
      if (kind == WispieCore.eventItems) {
        items = jsonDecode(payload) as Map<String, dynamic>;
      } else if (kind == WispieCore.eventProgress && onProgress != null) {
        final progress = jsonDecode(payload) as Map<String, dynamic>;
        onProgress(
          (progress['done'] as num).toInt(),
          (progress['total'] as num).toInt(),
        );
      }
    });
    if (code != 0) {
      throw StateError('native ${request['command']} exited with $code');
    }
    final decoded = items;
    if (decoded == null) {
      throw StateError('native ${request['command']} sent no items');
    }
    return decoded;
  }

  static List<List<NativeWord>> prosodyLines(List<NativeProsodyLine> lines) {
    final decoded = _ask({
      'command': 'prosody',
      'lines': [
        for (final line in lines)
          {
            'text': line.text,
            'startUs': line.startUs,
            'endUs': line.endUs,
            'songCps': line.songCps,
          },
      ],
    });

    return [
      for (final line in decoded['lines'] as List<dynamic>)
        [
          for (final word
              in (line as Map<String, dynamic>)['words'] as List<dynamic>)
            (
              startUs:
                  ((word as Map<String, dynamic>)['startUs'] as num).toInt(),
              endUs: (word['endUs'] as num).toInt(),
              text: word['text'] as String,
            ),
        ],
    ];
  }

  static BeatMap analyzeBeatFile(String path, {int? maxBytes}) {
    return _beatMap(_ask({
      'command': 'beat_analyze',
      'path': path,
      if (maxBytes != null) 'maxBytes': maxBytes,
    }));
  }

  static BeatMap _beatMap(Map<String, dynamic> decoded) {
    return BeatMap(
      version: BeatMap.currentVersion,
      durationMs: (decoded['durationMs'] as num).toInt(),
      bpm: (decoded['bpm'] as num).toDouble(),
      beatsMs: Int32List.fromList(
        (decoded['beatsMs'] as List<dynamic>)
            .map((value) => (value as num).toInt())
            .toList(growable: false),
      ),
      beatStrength: Float32List.fromList(
        (decoded['beatStrength'] as List<dynamic>)
            .map((value) => (value as num).toDouble())
            .toList(growable: false),
      ),
      downbeats: Uint8List.fromList(
        (decoded['downbeats'] as List<dynamic>)
            .map((value) => (value as num).toInt())
            .toList(growable: false),
      ),
      bands: Uint8List.fromList(
        (decoded['bands'] as List<dynamic>)
            .map((value) => (value as num).toInt())
            .toList(growable: false),
      ),
    );
  }

  static List<double> waveformPeaks(
    Uint8List pcm, {
    required int targetSamples,
    int expectedBytes = 0,
  }) {
    final decoded = _askBytes(
      {
        'command': 'waveform',
        'targetSamples': targetSamples,
        'expectedBytes': expectedBytes,
      },
      pcm,
    );
    return [
      for (final value in decoded['bars'] as List<dynamic>)
        (value as num).toDouble(),
    ];
  }

  static Map<String, dynamic> matchPlan({
    required List<Map<String, Object?>> library,
    required List<Map<String, Object?>> candidates,
  }) =>
      _ask({
        'command': 'match_plan',
        'library': library,
        'candidates': candidates,
      });

  static Map<String, dynamic> affinity({
    required List<String> filenames,
    required List<String> favorites,
    required double nowSeconds,
    required Uint8List events,
    required Map<String, double> params,
  }) =>
      _askBytes(
        {
          'command': 'affinity',
          'filenames': filenames,
          'favorites': favorites,
          'nowSeconds': nowSeconds,
          'params': params,
        },
        events,
      );

  static NativePalette palette(String path) {
    final decoded = _ask({'command': 'palette', 'path': path});
    NativeRgb rgb(Object? value) {
      final row = value as Map<String, dynamic>;
      return NativeRgb(
        (row['r'] as num).toInt(),
        (row['g'] as num).toInt(),
        (row['b'] as num).toInt(),
      );
    }

    return NativePalette(
      swatches: [
        for (final value in decoded['swatches'] as List<dynamic>)
          NativeSwatch(
            ((value as Map<String, dynamic>)['r'] as num).toInt(),
            (value['g'] as num).toInt(),
            (value['b'] as num).toInt(),
            (value['population'] as num).toInt(),
          ),
      ],
      accent: rgb(decoded['accent']),
      isNeutral: decoded['isNeutral'] as bool,
      mixedColor: rgb(decoded['mixedColor']),
    );
  }

  static Map<String, dynamic> bulkRenamePlan({
    required List<Map<String, Object?>> songs,
    required List<Map<String, Object?>> segments,
    void Function(int done, int total)? onProgress,
  }) =>
      _ask({
        'command': 'bulk_rename_plan',
        'songs': songs,
        'segments': segments,
        'windowsPaths': Platform.isWindows,
      }, onProgress: onProgress);

  static Map<String, dynamic> mergeCandidates({
    required List<Map<String, Object?>> songs,
    required Map<String, List<String>> existingGroups,
  }) =>
      _ask({
        'command': 'merge_candidates',
        'songs': songs,
        'existingGroups': existingGroups,
      });

  static Map<String, dynamic> insights({
    required List<NativePlayEvent> events,
    required List<Map<String, Object?>> songs,
    required Set<String> favorites,
    required String range,
    required DateTime now,
    required int topCount,
  }) {
    final filenameIndices = <String, int>{};
    final filenames = <String>[];
    final bytes = Uint8List(events.length * 36);
    final data = ByteData.sublistView(bytes);
    for (var index = 0; index < events.length; index++) {
      final event = events[index];
      final filenameIndex = filenameIndices.putIfAbsent(event.filename, () {
        filenames.add(event.filename);
        return filenames.length - 1;
      });
      final offset = index * 36;
      data.setUint32(offset, filenameIndex, Endian.little);
      data.setInt64(offset + 4, event.timestampMs, Endian.little);
      data.setInt64(offset + 12, event.playedMs, Endian.little);
      data.setFloat64(offset + 20, event.playRatio, Endian.little);
      data.setInt32(offset + 28, event.year, Endian.little);
      data.setUint8(offset + 32, event.month);
      data.setUint8(offset + 33, event.day);
      data.setUint8(offset + 34, event.hour);
      data.setUint8(offset + 35, event.weekday);
    }
    return _askBytes({
      'command': 'insights',
      'filenames': filenames,
      'songs': songs,
      'favorites': favorites.toList(growable: false),
      'range': range,
      'today': {'year': now.year, 'month': now.month, 'day': now.day},
      'epochLocalDay': _dateParts(DateTime.fromMillisecondsSinceEpoch(0)),
      'topCount': topCount,
    }, bytes);
  }

  static Map<String, int> _dateParts(DateTime value) => {
        'year': value.year,
        'month': value.month,
        'day': value.day,
      };

  static List<int> rankSearch({
    required String query,
    required List<NativeRankRow> results,
  }) {
    final decoded = _ask({
      'command': 'rank_search',
      'query': query,
      'results': [
        for (final row in results)
          {
            'title': row.title,
            'artist': row.artist,
            'album': row.album,
            'matchedTitle': row.matchedTitle,
            'matchedArtist': row.matchedArtist,
            'matchedAlbum': row.matchedAlbum,
            if (row.lyricsLine != null) 'lyricsLine': row.lyricsLine,
            'taste': row.taste,
          },
      ],
    });

    return [
      for (final index in decoded['order'] as List<dynamic>)
        (index as num).toInt(),
    ];
  }

  /// Hands the whole library to the core once; a search then only sends tokens.
  ///
  /// The staged copy is kept until the song list or the taste snapshot is
  /// replaced, which is what the provider hands out on a library or history
  /// change.
  static void prepareSearchCorpus({
    required List<Song> songs,
    required SearchTaste taste,
    bool force = false,
  }) {
    if (!force &&
        identical(_corpusSongs, songs) &&
        identical(_corpusTaste, taste)) {
      return;
    }

    _generation++;
    _ask({
      'command': 'search_prepare',
      'generation': _generation,
      'songs': [
        for (final song in songs)
          [
            song.filename,
            song.title,
            song.artist,
            song.album,
            taste.scoreOf(song),
          ],
      ],
    });
    _corpusSongs = songs;
    _corpusTaste = taste;
  }

  static List<NativeFuzzyHit> fuzzySearch({
    required List<String> tokens,
    required List<Song> songs,
    required SearchTaste taste,
    required Set<String> exclude,
    required bool titles,
    required bool artists,
    required bool albums,
  }) {
    prepareSearchCorpus(songs: songs, taste: taste);
    try {
      return _fuzzyQuery(tokens, exclude, titles, artists, albums);
    } on StateError {
      // Another isolate staged a different corpus; stage ours again.
      prepareSearchCorpus(songs: songs, taste: taste, force: true);
      return _fuzzyQuery(tokens, exclude, titles, artists, albums);
    }
  }

  static List<NativeFuzzyHit> _fuzzyQuery(
    List<String> tokens,
    Set<String> exclude,
    bool titles,
    bool artists,
    bool albums,
  ) {
    final decoded = _ask({
      'command': 'fuzzy_search',
      'generation': _generation,
      'tokens': tokens,
      'titles': titles,
      'artists': artists,
      'albums': albums,
      'exclude': exclude.toList(),
    });

    return [
      for (final hit in decoded['matches'] as List<dynamic>)
        (
          index: ((hit as Map<String, dynamic>)['index'] as num).toInt(),
          field: hit['field'] as String,
        ),
    ];
  }

  static Map<String, dynamic> _askBytes(
    Map<String, Object?> request,
    Uint8List bytes,
  ) {
    Map<String, dynamic>? items;
    final code = WispieCore.runBytes(request, bytes, onEvent: (kind, payload) {
      if (kind == WispieCore.eventItems) {
        items = jsonDecode(payload) as Map<String, dynamic>;
      }
    });
    if (code != 0) {
      throw StateError('native ${request['command']} exited with $code');
    }
    final decoded = items;
    if (decoded == null) {
      throw StateError('native ${request['command']} sent no items');
    }
    return decoded;
  }
}

typedef NativeWord = ({int startUs, int endUs, String text});

typedef NativePlayEvent = ({
  String filename,
  int timestampMs,
  int playedMs,
  double playRatio,
  int year,
  int month,
  int day,
  int hour,
  int weekday,
});

typedef NativeProsodyLine = ({
  String text,
  int startUs,
  int endUs,
  double songCps,
});

typedef NativeRankRow = ({
  String title,
  String artist,
  String album,
  bool matchedTitle,
  bool matchedArtist,
  bool matchedAlbum,
  String? lyricsLine,
  double taste,
});

typedef NativeFuzzyHit = ({int index, String field});
