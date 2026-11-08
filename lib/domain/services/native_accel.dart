import 'dart:convert';

import '../../data/rust/wispie_core.dart';
import '../../models/song.dart';
import 'search_taste.dart';

/// Synchronous access to the native hot paths.
///
/// These paths are Rust only: there is no Dart implementation to fall back on,
/// so a build without the core throws, exactly as the scanner does.
class NativeAccel {
  const NativeAccel._();

  static int _generation = 0;
  static List<Song>? _corpusSongs;
  static SearchTaste? _corpusTaste;

  static Map<String, dynamic> _ask(Map<String, Object?> request) {
    Map<String, dynamic>? items;
    final code = WispieCore.run(request, onEvent: (kind, payload) {
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
}

typedef NativeWord = ({int startUs, int endUs, String text});

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
