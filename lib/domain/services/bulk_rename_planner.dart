import 'package:path/path.dart' as p;

import '../../models/song.dart';

/// The metadata fields a rename format can pull from.
///
/// [stem] is the song's current filename without its extension. It is what
/// makes "prefix these files" possible without losing what they are called
/// today.
enum BulkRenameToken { title, artist, album, stem, track, year }

/// One row in the user's format: either a token or literal text.
class BulkRenameSegment {
  const BulkRenameSegment.token(this.token) : literal = '';

  const BulkRenameSegment.literal(this.literal) : token = null;

  final BulkRenameToken? token;
  final String literal;

  bool get isLiteral => token == null;

  static const BulkRenameSegment literalSeparator =
      BulkRenameSegment.literal(' - ');

  /// The three built-in formats, as ordered segment lists.
  static const List<List<BulkRenameSegment>> presets = [
    [BulkRenameSegment.token(BulkRenameToken.title)],
    [
      BulkRenameSegment.token(BulkRenameToken.artist),
      literalSeparator,
      BulkRenameSegment.token(BulkRenameToken.title),
    ],
    [
      BulkRenameSegment.token(BulkRenameToken.artist),
      literalSeparator,
      BulkRenameSegment.token(BulkRenameToken.album),
      literalSeparator,
      BulkRenameSegment.token(BulkRenameToken.title),
    ],
  ];
}

/// What the planner decided to do with one song.
class BulkRenamePlan {
  const BulkRenamePlan({
    required this.song,
    required this.newStem,
    required this.newFilename,
    required this.newUrl,
    this.skipReason,
  });

  final Song song;

  /// The target name without extension, after sanitizing.
  final String newStem;

  /// [newStem] plus the song's original extension.
  final String newFilename;

  final String newUrl;

  /// Non-null means the song is left alone and [newFilename] is meaningless.
  final String? skipReason;

  bool get willRename => skipReason == null;

  BulkRenamePlan _skipped(String reason) => BulkRenamePlan(
        song: song,
        newStem: newStem,
        newFilename: newFilename,
        newUrl: newUrl,
        skipReason: reason,
      );
}

/// One song the batch could not rename.
class BulkRenameFailure {
  const BulkRenameFailure(this.filename, this.reason);

  final String filename;
  final String reason;
}

/// What a completed batch actually did.
class BulkRenameResult {
  const BulkRenameResult({
    required this.renamed,
    required this.remaps,
    required this.failures,
    this.stoppedEarly = false,
  });

  /// Nothing at all to do.
  const BulkRenameResult.empty()
      : renamed = const [],
        remaps = const {},
        failures = const [],
        stoppedEarly = false;

  /// The songs under their new identities, for a single batch write.
  final List<Song> renamed;

  /// Old filename to new filename, so every cache keyed by filename can be
  /// moved and the player can rebind its queue without inferring anything.
  final Map<String, String> remaps;

  final List<BulkRenameFailure> failures;

  /// The user stopped the batch partway. Whatever landed in [renamed] was
  /// carried all the way through the database, so this is a shorter rename, not
  /// a broken one.
  final bool stoppedEarly;

  bool get isEmpty => renamed.isEmpty && failures.isEmpty;

  int get successCount => renamed.length;
}

/// Turns a song list plus a user-built format into a concrete rename list.
///
/// Pure: the only filesystem access is the existence probe handed to
/// [excludeExistingTargets], so the whole policy is testable without a library.
class BulkRenamePlanner {
  /// Substitutes renamed songs back into [library], matched on their
  /// **previous** filename.
  ///
  /// Both keys matter. The library is keyed by the name a song has now, the map
  /// by the name it had before, so looking either side up by the other deletes
  /// every renamed song from the list instead of replacing it.
  static List<Song> applyRenames(
    List<Song> library,
    Map<String, Song> byPreviousFilename,
  ) =>
      [
        for (final song in library) byPreviousFilename[song.filename] ?? song,
      ];

  /// Characters no supported filesystem accepts in a name.
  ///
  /// `/` and `\` are path separators, the rest are rejected by Windows and by
  /// SAF volumes that mirror it. Everything here becomes a space so that
  /// "AC/DC" reads as "AC DC" rather than "ACDC".
  static final RegExp _illegal = RegExp(r'[/\\:*?"<>|\x00-\x1F]');

  /// A run of separators left behind when an optional token (album, artist)
  /// renders empty, e.g. `Artist -  - Title`.
  static final RegExp _collapsedSeparators =
      RegExp(r'\s*[-–—]\s*(?:[-–—]\s*)+');

  /// Windows silently drops trailing dots and spaces, so a name that ends in
  /// one is a name that will not come back.
  static final RegExp _trailingJunk = RegExp(r'[.\s]+$');

  /// Makes [raw] safe to use as a filename.
  ///
  /// Applied to the whole rendered format rather than per token, so the
  /// separators the user typed survive.
  static String sanitize(String raw) {
    var value =
        raw.replaceAll(_illegal, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    while (_collapsedSeparators.hasMatch(value)) {
      value = value.replaceAll(_collapsedSeparators, ' - ');
    }
    value = value.replaceAll(_trailingJunk, '').trim();
    // A leading separator left by an empty first token.
    return value.replaceFirst(RegExp(r'^[-–—]+\s*'), '');
  }

  /// The stem [segments] produce for [song]. [index] is the song's 0-based
  /// position in the batch, which is what the `track` token numbers.
  ///
  /// Empty tokens render to nothing and drop their adjacent separator runs,
  /// so a song with no album still gets `Artist - Title` rather than
  /// `Artist -  - Title`.
  static String renderStem(
    List<BulkRenameSegment> segments,
    Song song, {
    required int index,
  }) {
    final parts = <String>[];
    for (final segment in segments) {
      final value = segment.isLiteral
          ? segment.literal
          : _renderToken(segment.token!, song, index);
      if (value.trim().isEmpty) continue;
      parts.add(value.trim());
    }
    return sanitize(parts.join(' '));
  }

  static String _renderToken(
    BulkRenameToken token,
    Song song,
    int index,
  ) {
    switch (token) {
      case BulkRenameToken.title:
        return song.title;
      case BulkRenameToken.artist:
        return song.artist;
      case BulkRenameToken.album:
        return song.album;
      case BulkRenameToken.stem:
        return p.basenameWithoutExtension(song.filename);
      case BulkRenameToken.track:
        return '${index + 1}';
      case BulkRenameToken.year:
        final epoch = song.songDateEpochSec;
        if (epoch == null || epoch <= 0) return '';
        return DateTime.fromMillisecondsSinceEpoch((epoch * 1000).round())
            .year
            .toString();
    }
  }

  /// Decides what to do with each song, without touching the filesystem.
  ///
  /// Only intra-batch conflicts are resolved here, because that is what a live
  /// preview can show the instant a format changes. Two songs in different
  /// folders may legitimately end up with the same name, so folder is part of
  /// a target's identity.
  ///
  /// [onProgress] is called with the running count so an off-thread run can
  /// report movement. It fires per song and is expected to be cheap.
  static List<BulkRenamePlan> plan({
    required List<Song> songs,
    required List<BulkRenameSegment> segments,
    void Function(int done)? onProgress,
  }) {
    final claimed = <String, String>{};
    final results = <BulkRenamePlan>[];
    onProgress?.call(0);

    for (var index = 0; index < songs.length; index++) {
      results.add(_planSong(songs[index], segments, index, claimed));
      onProgress?.call(index + 1);
    }

    return results;
  }

  static BulkRenamePlan _planSong(
    Song song,
    List<BulkRenameSegment> segments,
    int index,
    Map<String, String> claimed,
  ) {
    final stem = renderStem(segments, song, index: index);
    final extension = p.extension(song.url);
    final newFilename = '$stem$extension';
    final newUrl = p.join(p.dirname(song.url), newFilename);

    final candidate = BulkRenamePlan(
      song: song,
      newStem: stem,
      newFilename: newFilename,
      newUrl: newUrl,
    );

    if (stem.isEmpty) {
      return candidate._skipped('No title text left after cleanup');
    }
    if (newFilename == song.filename) {
      return candidate._skipped('Already named this');
    }

    // Android and iOS volumes are almost always case-insensitive, so
    // `Song.mp3` and `song.mp3` cannot coexist even though SQLite would
    // happily hold both.
    final claim = _claimKey(song.url, newFilename);
    final holder = claimed[claim];
    if (holder != null) {
      return candidate._skipped('Same name as "$holder" in this folder');
    }

    claimed[claim] = song.filename;
    return candidate;
  }

  /// Adds the on-disk check [plan] cannot make: a target file that already
  /// exists and is not itself being renamed away.
  ///
  /// Returns a new list; skipped entries are left as [plan] produced them.
  ///
  /// [onProgress] reports how many names have been checked, because this is one
  /// filesystem call per song and a large library on removable storage takes long
  /// enough that saying nothing would read as a frozen app. [isCancelled] stops
  /// between batches, leaving everything not yet checked as it was — "not ruled
  /// out" rather than "cleared", which is why the caller checks again before
  /// committing to anything.
  ///
  /// [concurrency] bounds how many names are probed at once. Strictly sequential
  /// is a minute of round trips against an SD card; unbounded is a flood of
  /// system calls at one document tree, which is slower still and much harder on
  /// the device.
  static Future<List<BulkRenamePlan>> excludeExistingTargets(
    List<BulkRenamePlan> plans, {
    required Future<bool> Function(String path) exists,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
    int concurrency = 8,
  }) async {
    final sources = plans.map((entry) => entry.song.url).toSet();

    final result = List<BulkRenamePlan?>.filled(plans.length, null);
    final probes = <int>[];

    for (var i = 0; i < plans.length; i++) {
      final entry = plans[i];
      if (!entry.willRename) {
        result[i] = entry;
      } else if (sources.contains(entry.newUrl)) {
        // Landing on another selected song's file is refused even though this
        // batch is also renaming that song away. Chaining renames would depend
        // on execution order, and `File.rename` silently replaces its target,
        // so the wrong order destroys a file outright.
        result[i] = entry._skipped('Another selected song has that name');
      } else {
        probes.add(i);
      }
    }

    final total = probes.length;
    final cancel = isCancelled ?? () => false;
    final width = concurrency < 1 ? 1 : concurrency;
    var done = 0;
    onProgress?.call(0, total);

    for (var start = 0; start < total; start += width) {
      if (cancel()) break;

      final end = (start + width).clamp(0, total);
      final batch = probes.sublist(start, end);
      final taken = await Future.wait([
        for (final index in batch) exists(plans[index].newUrl),
      ]);

      for (var i = 0; i < batch.length; i++) {
        final index = batch[i];
        final entry = plans[index];
        result[index] = taken[i]
            ? entry._skipped('A file with that name is already here')
            : entry;
      }

      done = end;
      onProgress?.call(done, total);
    }

    // Whatever the loop never reached keeps the verdict it came in with: a name
    // nobody looked at has not been shown to be taken.
    return [for (var i = 0; i < plans.length; i++) result[i] ?? plans[i]];
  }

  static String _claimKey(String siblingUrl, String newFilename) =>
      '${p.dirname(siblingUrl)}\x00${newFilename.toLowerCase()}';
}
