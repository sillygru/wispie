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
}

class IdentityMove {
  final String from;
  final String to;
  const IdentityMove(this.from, this.to);
}

class IdentityIndex {
  final Map<String, IdentityRow> byFilename = {};
  final Map<String, List<String>> _liveByCid = {};

  IdentityIndex(Iterable<IdentityRow> rows) {
    for (final r in rows) {
      byFilename[r.filename] = r;
    }
    _rebuildLive();
  }

  void _rebuildLive() {
    _liveByCid.clear();
    for (final r in byFilename.values) {
      if (r.status == IdentityStatus.live) {
        (_liveByCid[r.cid] ??= []).add(r.filename);
      }
    }
    for (final list in _liveByCid.values) {
      list.sort();
    }
  }

  /// Adds a name known only by id (never live) without a rebuild.
  void addOrphan(String filename, String cid) {
    byFilename.putIfAbsent(
        filename,
        () => IdentityRow(
            filename: filename, cid: cid, status: IdentityStatus.orphan));
  }

  List<String> liveFilesFor(String cid) => _liveByCid[cid] ?? const [];

  /// Maps a filename named by another device (or an older name) to the file
  /// that holds the same audio here.
  ///
  /// Returns [filename] untouched when nothing is known, the mapped local
  /// filename when the audio is present under another name, and null when the
  /// name is taken by a different recording locally and the audio itself is
  /// absent: applying the record would attach it to the wrong song.
  String? resolve(String filename, {String? remoteCid}) {
    final local = byFilename[filename];
    final cid = remoteCid ?? local?.cid;
    if (cid == null) return filename;

    final live = _liveByCid[cid];
    if (live != null && live.contains(filename)) return filename;

    final nameTakenByOther = local != null &&
        local.status == IdentityStatus.live &&
        local.cid != cid;
    if (live != null && live.isNotEmpty) return live.first;
    return nameTakenByOther ? null : filename;
  }

  /// Orphans whose audio is now present exactly once. Several orphans of one
  /// content id collapse onto that file (they were all the same audio); two or
  /// more present copies make the target ambiguous, so nothing moves.
  List<IdentityMove> planHeals() {
    final orphansByCid = <String, List<String>>{};
    for (final r in byFilename.values) {
      if (r.status == IdentityStatus.orphan) {
        (orphansByCid[r.cid] ??= []).add(r.filename);
      }
    }
    final moves = <IdentityMove>[];
    orphansByCid.forEach((cid, orphans) {
      final live = _liveByCid[cid];
      if (live == null || live.length != 1) return;
      orphans.sort();
      for (final o in orphans) {
        moves.add(IdentityMove(o, live.first));
      }
    });
    return moves;
  }
}
