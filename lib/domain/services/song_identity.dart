import 'native_accel.dart';

/// Pure identity logic: which filename on this device does a song seen
/// elsewhere (or earlier) correspond to?
///
/// A filename stays the key for all user data on this device. What this layer
/// adds is a durable `filename -> content id` memory (see
/// `audio_content_id.dart`), so that when the same audio shows up under a
/// different name, data can be moved over instead of being orphaned.
///
/// The one rule that keeps this free of false positives: only identical
/// content ids ever link two names. Tags, durations and name similarity are
/// never evidence.
enum IdentityStatus {
  /// The file exists on this device right now.
  live,

  /// A name we know a content id for whose file is gone (or was never here,
  /// when it came from another device or a backup) and which may still hold
  /// user data waiting for its audio to reappear.
  orphan,

  /// A former name whose data has already moved on. Kept so records that still
  /// use the old name resolve to the current file.
  alias,
}

class IdentityRow {
  final String filename;
  final String cid;
  final double? mtime;
  final IdentityStatus status;

  const IdentityRow({
    required this.filename,
    required this.cid,
    this.mtime,
    this.status = IdentityStatus.live,
  });

  IdentityRow copyWith({IdentityStatus? status, double? mtime, String? cid}) =>
      IdentityRow(
        filename: filename,
        cid: cid ?? this.cid,
        mtime: mtime ?? this.mtime,
        status: status ?? this.status,
      );

  Map<String, Object?> toJson() => {
        'filename': filename,
        'cid': cid,
        if (mtime != null) 'mtime': mtime,
        'status': status.name,
      };
}

class IdentityMove {
  final String from;
  final String to;
  const IdentityMove(this.from, this.to);
}

/// A staged copy of the identity table. The rows cross the boundary once when
/// the index is built, so a sync record costs a small lookup afterwards.
class IdentityIndex {
  IdentityIndex(Iterable<IdentityRow> rows)
      : byFilename = {for (final row in rows) row.filename: row} {
    _stage();
  }

  static int _generations = 0;

  /// The known rows, in the shape callers read them (the cid of a name).
  final Map<String, IdentityRow> byFilename;
  int _generation = 0;

  void _stage() {
    _generation = ++_generations;
    NativeAccel.identityPrepare(
      [for (final row in byFilename.values) row.toJson()],
      generation: _generation,
    );
  }

  /// Adds a name known only by id (never live).
  void addOrphan(String filename, String cid) {
    if (byFilename.containsKey(filename)) return;
    byFilename[filename] = IdentityRow(
      filename: filename,
      cid: cid,
      status: IdentityStatus.orphan,
    );
    _stage();
  }

  /// Maps a filename named by another device (or an older name) to the file
  /// that holds the same audio here.
  ///
  /// Returns [filename] untouched when nothing is known, the mapped local
  /// filename when the audio is present under another name, and null when the
  /// name is taken by a different recording locally and the audio itself is
  /// absent: applying the record would attach it to the wrong song.
  String? resolve(String filename, {String? remoteCid}) =>
      NativeAccel.identityResolve(
        generation: _generation,
        filename: filename,
        remoteCid: remoteCid,
      )['filename'] as String?;

  List<String> liveFilesFor(String cid) => [
        for (final name in NativeAccel.identityResolve(
          generation: _generation,
          filename: '',
          remoteCid: cid,
        )['live'] as List)
          name as String,
      ];

  /// Orphans whose audio is now present exactly once. Several orphans of one
  /// content id collapse onto that file (they were all the same audio); two or
  /// more present copies make the target ambiguous, so nothing moves.
  List<IdentityMove> planHeals() => [
        for (final move
            in NativeAccel.identityHeals(generation: _generation)['moves']
                as List)
          IdentityMove(
            (move as Map<String, dynamic>)['from'] as String,
            move['to'] as String,
          ),
      ];
}
