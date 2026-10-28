import 'package:path/path.dart' as p;

/// What a library song offers to a comparison.
///
/// [filename] is the identity the rest of the app keys user data on, so it is
/// the only field the plan carries back; the rest exists to be compared.
class LibrarySongRef {
  final String filename;
  final String title;
  final String artist;
  final String album;
  final Duration? duration;

  const LibrarySongRef({
    required this.filename,
    required this.title,
    required this.artist,
    required this.album,
    this.duration,
  });
}

/// What a file outside the library offers.
///
/// Tags are nullable on purpose: a release download often carries none, and the
/// filename is then the only thing there is to compare. Reporting "unknown"
/// rather than substituting a value from the path keeps a match honest about
/// which signal it actually found.
class FolderSongRef {
  final String path;
  final String? title;
  final String? artist;
  final String? album;
  final Duration? duration;

  const FolderSongRef({
    required this.path,
    this.title,
    this.artist,
    this.album,
    this.duration,
  });

  String get filename => p.basename(path);
}

/// The kinds of agreement a proposal is built from, so the UI can say why it
/// thinks two files are the same song instead of just asserting a number.
enum MatchSignal { title, filename, artist, album, duration }

/// One proposed pairing: [filename] on the library side, [candidate] on disk.
class SongMatchProposal {
  final String filename;
  final FolderSongRef candidate;
  final double confidence;
  final Set<MatchSignal> signals;

  /// Both files state a length and they differ by more than [lengthClose] but
  /// not by enough to rule the match out. Surfaced so the user can decide —
  /// an edit or a different master still matches, a different song does not.
  final bool lengthDiffers;

  const SongMatchProposal({
    required this.filename,
    required this.candidate,
    required this.confidence,
    required this.signals,
    required this.lengthDiffers,
  });

  /// Confidence as a whole percentage, for display.
  int get confidencePercent => (confidence * 100).round();
}

/// The outcome of comparing a folder against the library: one-to-one pairings,
/// and the candidates nothing claimed.
class SongMatchPlan {
  final List<SongMatchProposal> proposals;
  final List<FolderSongRef> unmatched;
  final int libraryCompared;
  final int candidatesCompared;

  const SongMatchPlan({
    required this.proposals,
    required this.unmatched,
    required this.libraryCompared,
    required this.candidatesCompared,
  });

  bool get isEmpty => proposals.isEmpty;
}

/// Pairs library songs with files from another folder.
///
/// Pure: no filesystem, no database, no state management. Everything the score
/// depends on arrives as a value, which is what makes the part that can get a
/// user's files rewritten reviewable on its own.
///
/// The scoring is deliberately name-first. Tags are the most reliable signal
/// when both sides have them, but a candidate folder is exactly the case where
/// one side often has none, so a match that comes out of filenames alone has to
/// be able to clear the bar by itself.
class SongMatchPlanner {
  const SongMatchPlanner._();

  /// Below this, a pairing is not proposed.
  static const double minimumConfidence = 0.55;

  /// Weights. Text tops out the same whether the agreement came from tags or
  /// from filenames — they are redundant evidence for the same property, so the
  /// two never add up.
  static const double _textScore = 0.55;
  static const double _partialTextScore = 0.28;
  static const double _artistScore = 0.18;
  static const double _albumScore = 0.05;
  static const double _durationScore = 0.12;

  /// A conflicting artist is strong disproof: same-titled songs by different
  /// artists are everywhere, so exact titles must not carry past it.
  static const double _artistConflict = -0.45;

  static const Duration lengthClose = Duration(seconds: 3);
  static const Duration lengthLoose = Duration(seconds: 10);
  static const Duration lengthWarning = Duration(seconds: 30);

  /// Beyond this, two files are different recordings of something, not two
  /// copies of one song.
  static const Duration lengthImpossible = Duration(seconds: 60);

  /// Words that appear in file names without saying anything about the song.
  static const Set<String> _stopWords = {
    'the',
    'a',
    'an',
    'and',
    'of',
    'to',
    'in',
    'on',
    'with',
    'feat',
    'ft',
    'official',
    'audio',
    'video',
    'lyrics',
    'lyric',
    'hd',
    'hq',
    'remaster',
    'remastered',
    'explicit',
    'prod',
    'version',
    'mix',
    'music',
    'mv',
    '4k',
  };

  /// Pairs [library] with [candidates], one candidate per song at most.
  static SongMatchPlan plan({
    required List<LibrarySongRef> library,
    required List<FolderSongRef> candidates,
  }) {
    final scored = <_Scored>[];
    final libraryIndex = <String, LibrarySongRef>{
      for (final song in library) song.filename: song,
    };

    // Identical filenames are the same file, not a replacement for it.
    final libraryNames = <String>{
      for (final song in library) song.filename.toLowerCase(),
    };

    for (final candidate in candidates) {
      if (libraryNames.contains(candidate.filename.toLowerCase())) continue;
      for (final song in library) {
        final result = _score(song, candidate);
        if (result != null) scored.add(result);
      }
    }

    scored.sort((a, b) {
      final byScore = b.confidence.compareTo(a.confidence);
      if (byScore != 0) return byScore;
      // A tie on score is broken by the name, so the outcome does not depend on
      // the order the folder happened to be listed in.
      return a.candidate.filename.compareTo(b.candidate.filename);
    });

    final takenSongs = <String>{};
    final takenCandidates = <String>{};
    final proposals = <SongMatchProposal>[];

    for (final match in scored) {
      if (takenSongs.contains(match.libraryFilename)) continue;
      if (takenCandidates.contains(match.candidate.path)) continue;
      takenSongs.add(match.libraryFilename);
      takenCandidates.add(match.candidate.path);
      proposals.add(SongMatchProposal(
        filename: match.libraryFilename,
        candidate: match.candidate,
        confidence: match.confidence,
        signals: match.signals,
        lengthDiffers: match.lengthDiffers,
      ));
    }

    proposals.sort((a, b) {
      final byScore = b.confidence.compareTo(a.confidence);
      if (byScore != 0) return byScore;
      final aTitle = libraryIndex[a.filename]?.title ?? a.filename;
      final bTitle = libraryIndex[b.filename]?.title ?? b.filename;
      return aTitle.toLowerCase().compareTo(bTitle.toLowerCase());
    });

    return SongMatchPlan(
      proposals: proposals,
      unmatched: [
        for (final candidate in candidates)
          if (!takenCandidates.contains(candidate.path)) candidate,
      ],
      libraryCompared: library.length,
      candidatesCompared: candidates.length,
    );
  }

  static _Scored? _score(LibrarySongRef song, FolderSongRef candidate) {
    final signals = <MatchSignal>{};
    double score = 0;
    var lengthDiffers = false;

    final libraryKeys = _keysFor(
      title: song.title,
      artist: song.artist,
      path: song.filename,
    );
    final candidateKeys = _keysFor(
      title: candidate.title,
      artist: candidate.artist,
      path: candidate.path,
    );

    final titleExact = libraryKeys.title != null &&
        candidateKeys.title != null &&
        libraryKeys.title == candidateKeys.title;
    final nameExact = _sharesKey(libraryKeys.strong, candidateKeys.strong);

    if (titleExact || nameExact) {
      score += _textScore;
      signals.add(titleExact ? MatchSignal.title : MatchSignal.filename);
    } else if (_readsAsSameSong(libraryKeys, candidateKeys)) {
      score += _partialTextScore;
    } else {
      // Nothing about the two names agrees, and there is nothing left that
      // could identify a song.
      return null;
    }

    final artistCompare = _compareArtists(song.artist, candidate.artist);
    score += artistCompare.score;
    if (artistCompare.exact) signals.add(MatchSignal.artist);
    if (artistCompare.conflict && !titleExact) return null;

    if (_sameText(song.album, candidate.album)) {
      score += _albumScore;
      signals.add(MatchSignal.album);
    }

    final songLength = song.duration;
    final candidateLength = candidate.duration;
    final bothLengths = songLength != null &&
        candidateLength != null &&
        songLength.inMilliseconds > 0 &&
        candidateLength.inMilliseconds > 0;

    if (bothLengths) {
      final difference = (songLength - candidateLength).abs();
      if (difference <= lengthClose) {
        score += _durationScore;
        signals.add(MatchSignal.duration);
      } else if (difference <= lengthLoose) {
        score += _durationScore / 2;
      } else if (difference <= lengthWarning) {
        score += _durationScore / 6;
        lengthDiffers = true;
      } else if (difference <= lengthImpossible) {
        lengthDiffers = true;
      } else if (!(titleExact && artistCompare.exact)) {
        // Long enough apart to be a different recording, and not vouched for by
        // both tags.
        return null;
      }
    }

    if (score < minimumConfidence) return null;

    return _Scored(
      libraryFilename: song.filename,
      candidate: candidate,
      confidence: score > 1 ? 1 : score,
      signals: signals,
      lengthDiffers: lengthDiffers,
    );
  }

  static bool _sharesKey(List<String> a, List<String> b) {
    for (final left in a) {
      for (final right in b) {
        if (left == right) return true;
      }
    }
    return false;
  }

  /// Whether two names read as the same song without being identical.
  ///
  /// Tolerates the usual clutter: a bracketed suffix, a dropped subtitle, one
  /// extra word. Requires enough words to be about a song rather than about a
  /// shared article.
  static bool _readsAsSameSong(_NameKeys a, _NameKeys b) {
    for (final left in a.strong) {
      for (final right in b.strong) {
        if (left.length >= 6 && right.length >= 6) {
          if (left.contains(right) || right.contains(left)) return true;
        }
      }
    }
    return _tokensContained(a.tokens, b.tokens) ||
        _tokensContained(b.tokens, a.tokens);
  }

  /// Whether [smaller] is contained in [larger] with little left over.
  static bool _tokensContained(Set<String> smaller, Set<String> larger) {
    if (smaller.isEmpty || larger.isEmpty) return false;
    if (!smaller.every(larger.contains)) return false;
    if (larger.length - smaller.length > 3) return false;
    if (smaller.length >= 2) return true;
    // A single shared word only counts when it is long enough to be a name
    // rather than an article.
    return smaller.first.length >= 6;
  }

  static _ArtistCompare _compareArtists(String? a, String? b) {
    final left = _clean(a ?? '');
    final right = _clean(b ?? '');
    if (left.isEmpty || right.isEmpty) {
      return const _ArtistCompare(score: 0);
    }
    if (left == right) {
      return const _ArtistCompare(score: _artistScore, exact: true);
    }
    if (left.contains(right) || right.contains(left)) {
      return const _ArtistCompare(score: _artistScore / 2);
    }
    final leftTokens = _tokens(left);
    final rightTokens = _tokens(right);
    if (leftTokens.intersection(rightTokens).isNotEmpty) {
      return const _ArtistCompare(score: _artistScore / 2);
    }
    return const _ArtistCompare(score: _artistConflict, conflict: true);
  }

  static bool _sameText(String? a, String? b) {
    final left = _clean(a ?? '');
    final right = _clean(b ?? '');
    return left.isNotEmpty && left == right;
  }

  /// Every name a side could be known by, in two forms: whole strings that are
  /// compared for equality, and words for the looser comparison.
  static _NameKeys _keysFor({
    required String? title,
    required String? artist,
    required String path,
  }) {
    final titleTag = _clean(title ?? '');
    final artistTag = _clean(artist ?? '');
    final stem = p.basenameWithoutExtension(path);

    final strong = <String>{};
    if (titleTag.isNotEmpty) strong.add(titleTag);

    for (final variant in _stemVariants(stem, artistTag)) {
      if (variant.isNotEmpty) strong.add(variant);
    }

    final tokens = <String>{};
    for (final key in strong) {
      tokens.addAll(_tokens(key));
    }

    return _NameKeys(
      title: titleTag.isEmpty ? null : titleTag,
      strong: strong.toList(),
      tokens: tokens,
    );
  }

  /// The readable forms of a filename: as-is, minus a track number, minus
  /// bracketed noise, and minus a leading artist that its own tags confirm.
  static List<String> _stemVariants(String stem, String artistTag) {
    final variants = <String>{};

    void add(String value) {
      final cleaned = _clean(value);
      if (cleaned.isNotEmpty) variants.add(cleaned);
    }

    add(stem);

    var stripped = stem.replaceAll(RegExp(r'^\s*(?:\d{1,3}\s*[-._])+\s*'), '');
    add(stripped);

    final withoutBrackets =
        stripped.replaceAll(RegExp(r'[\(\[][^\)\]]*[\)\]]'), '');
    add(withoutBrackets);

    if (artistTag.isNotEmpty) {
      for (final candidate in [stripped, withoutBrackets]) {
        final index = _clean(candidate).indexOf(artistTag);
        if (index != 0) continue;
        final rest = candidate
            .substring(artistTag.length)
            .replaceFirst(RegExp(r'^[\s\-–—:|]+'), '');
        add(rest);
      }
    }

    return variants.toList();
  }

  /// Lowercased, letters and digits only, single-spaced.
  static String _clean(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static Set<String> _tokens(String cleaned) {
    return {
      for (final word in cleaned.split(' '))
        if (word.isNotEmpty && !_stopWords.contains(word)) word,
    };
  }
}

class _NameKeys {
  final String? title;
  final List<String> strong;
  final Set<String> tokens;

  const _NameKeys({
    required this.title,
    required this.strong,
    required this.tokens,
  });
}

class _ArtistCompare {
  final double score;
  final bool exact;
  final bool conflict;

  const _ArtistCompare({
    required this.score,
    this.exact = false,
    this.conflict = false,
  });
}

class _Scored {
  final String libraryFilename;
  final FolderSongRef candidate;
  final double confidence;
  final Set<MatchSignal> signals;
  final bool lengthDiffers;

  const _Scored({
    required this.libraryFilename,
    required this.candidate,
    required this.confidence,
    required this.signals,
    required this.lengthDiffers,
  });
}
