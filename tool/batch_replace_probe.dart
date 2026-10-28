// SPDX-License-Identifier: GPL-3.0-only

// Exercises the batch replace comparison the way the screen runs it: a folder
// outside the library is listed, its files' tags are read off the main isolate,
// and the result is paired against library songs.
//
// Fixtures are real audio files stamped with ffmpeg, so the tag reading and the
// duration matching are the same code the app uses rather than a stub. Nothing
// is replaced here — the swap needs the app's databases — but every decision
// that leads up to a replacement is decided for real, including the validation
// the batch applies per file.
//
//   dart run tool/batch_replace_probe.dart
//
// RESULT: ok means every expectation held. The cases are the ones the feature
// exists for: a release file whose name and tags disagree with the library row,
// a file with no tags at all, a same-titled song by a different artist that must
// not be proposed, and a folder holding more copies of one song than the library
// has.

// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:wispie/domain/services/song_folder_reader.dart';
import 'package:wispie/domain/services/song_match_planner.dart';
import 'package:wispie/domain/services/song_replacement_rules.dart';
import 'package:wispie/models/song.dart';

int _checks = 0;
int _failures = 0;

void check(String label, bool ok, [String? detail]) {
  _checks++;
  if (ok) {
    print('  ok   $label');
    return;
  }
  _failures++;
  print('  FAIL $label${detail == null ? '' : ' ($detail)'}');
}

Directory _tmpRoot() {
  final root = Directory.systemTemp.createTempSync('wispie-batch-replace-');
  return root;
}

/// Stamps a real audio file with tags, so the reader under test sees what a
/// release file actually holds.
Future<void> _makeAudio(
  String path, {
  required String codec,
  required String extension,
  String? title,
  String? artist,
  String? album,
  int seconds = 3,
}) async {
  final args = [
    '-y',
    '-loglevel',
    'error',
    '-f',
    'lavfi',
    '-i',
    'sine=frequency=440:duration=$seconds',
    if (title != null) ...['-metadata', 'title=$title'],
    if (artist != null) ...['-metadata', 'artist=$artist'],
    if (album != null) ...['-metadata', 'album=$album'],
    '-c:a',
    codec,
    path,
  ];

  final result = await Process.run('ffmpeg', args);
  if (result.exitCode != 0) {
    throw StateError('ffmpeg failed for $path: ${result.stderr}');
  }
  if (p.extension(path).toLowerCase() != '.$extension') {
    throw StateError('fixture extension mismatch for $path');
  }
}

bool _proposes(SongMatchPlan plan, String libraryFilename, String candidate) =>
    plan.proposals.any((row) =>
        row.filename == libraryFilename &&
        p.basename(row.candidate.path) == candidate);

SongMatchProposal _proposalFor(SongMatchPlan plan, String libraryFilename) =>
    plan.proposals.firstWhere((row) => row.filename == libraryFilename);

Song _songFor(String path, FolderSongRef ref) => Song(
      title: ref.title ?? p.basenameWithoutExtension(path),
      artist: ref.artist ?? 'Unknown Artist',
      album: ref.album ?? 'Unknown Album',
      filename: p.basename(path),
      url: path,
      duration: ref.duration,
    );

Future<void> main() async {
  final root = _tmpRoot();
  final libraryDir = Directory(p.join(root.path, 'library'))..createSync();
  final sourceDir = Directory(p.join(root.path, 'new-releases'))..createSync();
  final discDir = Directory(p.join(sourceDir.path, 'Disc 2'))..createSync();

  // The library side: lossy rips, tagged the way a scanner would find them.
  final libraryFiles = {
    'Only You': p.join(libraryDir.path, 'The Pretty Reckless - Only You.m4a'),
    'My Medicine':
        p.join(libraryDir.path, 'The Pretty Reckless - My Medicine.m4a'),
    'Hit Me Like A Man':
        p.join(libraryDir.path, 'The Pretty Reckless - Hit Me Like A Man.m4a'),
  };
  for (final entry in libraryFiles.entries) {
    await _makeAudio(
      entry.value,
      codec: 'aac',
      extension: 'm4a',
      title: entry.key,
      artist: 'The Pretty Reckless',
      album: 'Light Me Up',
    );
  }

  // The comparison folder: a release rip whose names carry track numbers, one
  // file with no tags at all, a same-titled song by someone else, and a nested
  // disc.
  final tagged = p.join(sourceDir.path, '04 - Only You.flac');
  final untagged = p.join(sourceDir.path, 'Only You (Original).flac');
  final differentArtist = p.join(sourceDir.path, '02 - Only You.mp3');
  final nested = p.join(discDir.path, '07 - My Medicine.flac');
  final unrelated =
      p.join(sourceDir.path, '01 - Nothing Like This At All.flac');

  await _makeAudio(tagged,
      codec: 'flac',
      extension: 'flac',
      title: 'Only You',
      artist: 'The Pretty Reckless',
      album: 'Light Me Up');
  await _makeAudio(untagged, codec: 'flac', extension: 'flac');
  await _makeAudio(differentArtist,
      codec: 'libmp3lame',
      extension: 'mp3',
      title: 'Only You',
      artist: 'Different Artist',
      album: 'Different Album');
  await _makeAudio(nested,
      codec: 'flac',
      extension: 'flac',
      title: 'My Medicine',
      artist: 'The Pretty Reckless',
      album: 'Light Me Up');
  await _makeAudio(unrelated,
      codec: 'flac',
      extension: 'flac',
      title: 'Nothing Like This At All',
      artist: 'Nobody');
  // Not a song, and not a file the library would ever index.
  File(p.join(sourceDir.path, 'cover.jpg')).writeAsStringSync('not audio');

  print('Fixture: ${root.path}');

  // --- Listing ------------------------------------------------------------
  print('\nListing');
  final recursive = await SongFolderReader.listMediaFiles(sourceDir.path);
  final flat =
      await SongFolderReader.listMediaFiles(sourceDir.path, recursive: false);

  check('recursive listing finds the nested disc (${recursive.length} files)',
      recursive.length == 5, 'found ${recursive.length}');
  check('non-recursive listing stops at the top level', flat.length == 4,
      'found ${flat.length}');
  check('cover art is not treated as a song',
      !recursive.any((path) => path.endsWith('cover.jpg')));

  // --- Reading tags off the main isolate ----------------------------------
  print('\nReading tags');
  final progress = <int>[];
  final port = ReceivePort();
  port.listen((message) => progress.add(message as int));

  final libraryRefs = await SongFolderReader.readFacts(
    await SongFolderReader.listMediaFiles(libraryDir.path),
    progress: port.sendPort,
  );
  final candidates = await SongFolderReader.readFacts(
    recursive,
    progress: port.sendPort,
  );
  port.close();

  check('progress reported every file read (${progress.length})',
      progress.length == libraryRefs.length + candidates.length);

  final libraryByFilename = {
    for (final ref in libraryRefs) p.basename(ref.path): ref,
  };
  final taggedRef = candidates.firstWhere((ref) => ref.path == tagged);
  final untaggedRef = candidates.firstWhere((ref) => ref.path == untagged);

  check(
      'tags survive the isolate hop (title="Only You", artist=Pretty Reckless)',
      taggedRef.title == 'Only You' &&
          taggedRef.artist == 'The Pretty Reckless',
      '${taggedRef.title} / ${taggedRef.artist}');
  check('album survives too', taggedRef.album == 'Light Me Up');
  check('a file with no tags reports none rather than guessing',
      untaggedRef.title == null && untaggedRef.artist == null);

  // --- Pairing ------------------------------------------------------------
  print('\nPairing');
  final plan = SongMatchPlanner.plan(
    library: [
      for (final entry in libraryFiles.entries)
        LibrarySongRef(
          filename: p.basename(entry.value),
          title: entry.key,
          artist: 'The Pretty Reckless',
          album: 'Light Me Up',
          duration: libraryByFilename[p.basename(entry.value)]?.duration,
        ),
    ],
    candidates: candidates,
  );

  for (final row in plan.proposals) {
    print('  ${row.confidencePercent}%  ${row.filename}'
        '  <-  ${p.basename(row.candidate.path)}'
        '  [${row.signals.map((s) => s.name).join(', ')}]'
        '${row.lengthDiffers ? ' length differs' : ''}');
  }
  for (final missed in plan.unmatched) {
    print('  --      (unmatched)  ${p.basename(missed.path)}');
  }

  // The case the feature was asked for: "The Pretty Reckless - Only You.m4a"
  // against "04 - Only You.flac".
  check(
      'track-numbered release file matches its library song',
      _proposes(
          plan, p.basename(libraryFiles['Only You']!), '04 - Only You.flac'));
  check(
      'a nested disc file matches too',
      _proposes(plan, p.basename(libraryFiles['My Medicine']!),
          '07 - My Medicine.flac'));

  final onlyYou = _proposalFor(plan, p.basename(libraryFiles['Only You']!));
  check('the untagged flac loses to the tagged one',
      onlyYou.candidate.path == tagged, p.basename(onlyYou.candidate.path));
  check(
      'the tagged match carries title, artist and length signals',
      onlyYou.signals.containsAll(const {
        MatchSignal.title,
        MatchSignal.artist,
        MatchSignal.duration,
      }),
      onlyYou.signals.map((s) => s.name).join(', '));

  final differentArtistSong = p.basename(libraryFiles['Hit Me Like A Man']!);
  check(
      'a same-titled song by another artist is not proposed',
      !plan.proposals
          .any((row) => p.basename(row.candidate.path) == '02 - Only You.mp3'));
  check('the other artist\'s file is left unmatched',
      plan.unmatched.any((ref) => p.basename(ref.path) == '02 - Only You.mp3'));
  check(
      'an unrelated song proposes nothing',
      !plan.proposals.any((row) =>
          p.basename(row.candidate.path) ==
          '01 - Nothing Like This At All.flac'));
  check(
      'nothing is paired to the same song twice',
      plan.proposals.map((row) => row.filename).toSet().length ==
          plan.proposals.length);
  check(
      'nothing is paired to the same file twice',
      plan.proposals.map((row) => row.candidate.path).toSet().length ==
          plan.proposals.length);
  check('a song with no candidate stays out of the proposals',
      !plan.proposals.any((row) => row.filename == differentArtistSong));

  // --- The rules the batch applies before touching a file ------------------
  print('\nReplacement rules');
  final song = _songFor(
    libraryFiles['Only You']!,
    libraryByFilename[p.basename(libraryFiles['Only You']!)]!,
  );

  final accepted = SongReplacementRules.check(
    original: song,
    sourcePath: onlyYou.candidate.path,
    isSupportedMediaFile: true,
    trackedFolders: [libraryDir.path],
    libraryFilenames:
        libraryFiles.keys.map((title) => p.basename(libraryFiles[title]!)),
    destinationExists: false,
  );

  if (accepted case ReplacementAccepted ok) {
    check(
        'the accepted destination keeps the library directory, not the name',
        p.equals(p.dirname(ok.destinationPath), libraryDir.path) &&
            ok.newFilename == '04 - Only You.flac',
        ok.destinationPath);
  } else {
    check('the proposal passes validation', false, '$accepted');
  }

  final insideLibrary = SongReplacementRules.check(
    original: song,
    sourcePath: p.join(libraryDir.path, '04 - Only You.flac'),
    isSupportedMediaFile: true,
    trackedFolders: [libraryDir.path],
    libraryFilenames: const [],
    destinationExists: false,
  );
  check(
      'a source inside the library is refused',
      insideLibrary is ReplacementRejected &&
          (insideLibrary).reason == ReplacementRejectReason.insideLibrary);

  final taken = SongReplacementRules.check(
    original: song,
    sourcePath: onlyYou.candidate.path,
    isSupportedMediaFile: true,
    trackedFolders: [libraryDir.path],
    libraryFilenames: const [],
    destinationExists: true,
  );
  check(
      'an occupied destination is refused',
      taken is ReplacementRejected &&
          (taken).reason == ReplacementRejectReason.destinationExists);

  root.deleteSync(recursive: true);

  print(
      '\nRESULT: ${_failures == 0 ? 'ok' : 'failed ($_failures of $_checks)'}');
  exit(_failures == 0 ? 0 : 1);
}
