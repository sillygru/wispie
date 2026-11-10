import 'package:path/path.dart' as p;

import 'native_accel.dart';

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

  /// Both files state a length and differ enough to suggest a different edit
  /// or master, without ruling the match out.
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

/// Sends a folder comparison to the Rust core and maps its proposals to UI models.
class SongMatchPlanner {
  const SongMatchPlanner._();

  static SongMatchPlan plan({
    required List<LibrarySongRef> library,
    required List<FolderSongRef> candidates,
  }) {
    final response = NativeAccel.matchPlan(
      library: [
        for (final song in library)
          {
            'filename': song.filename,
            'title': song.title,
            'artist': song.artist,
            'album': song.album,
            if (song.duration != null)
              'durationMs': song.duration!.inMilliseconds,
          },
      ],
      candidates: [
        for (final candidate in candidates)
          {
            'filename': candidate.filename,
            'path': candidate.path,
            'title': candidate.title,
            'artist': candidate.artist,
            'album': candidate.album,
            if (candidate.duration != null)
              'durationMs': candidate.duration!.inMilliseconds,
          },
      ],
    );
    final proposals = [
      for (final value in response['proposals'] as List<dynamic>)
        _proposal(
          value as Map<String, dynamic>,
          candidates,
        ),
    ];
    final unmatched = [
      for (final value in response['unmatched'] as List<dynamic>)
        candidates[(value as num).toInt()],
    ];
    return SongMatchPlan(
      proposals: proposals,
      unmatched: unmatched,
      libraryCompared: (response['libraryCompared'] as num).toInt(),
      candidatesCompared: (response['candidatesCompared'] as num).toInt(),
    );
  }

  static SongMatchProposal _proposal(
    Map<String, dynamic> value,
    List<FolderSongRef> candidates,
  ) {
    final signals = (value['signals'] as List<dynamic>)
        .map((name) => MatchSignal.values.byName(name as String))
        .toSet();
    return SongMatchProposal(
      filename: value['filename'] as String,
      candidate: candidates[(value['candidateIndex'] as num).toInt()],
      confidence: (value['confidence'] as num).toDouble(),
      signals: signals,
      lengthDiffers: value['lengthDiffers'] as bool,
    );
  }
}
