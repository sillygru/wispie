// SPDX-License-Identifier: GPL-3.0-only

// Verifies sidecar lyrics end to end on the native core: linking a song to its
// `.lrc`/`.ttml` file, choosing one when several match, converting TTML to LRC,
// finding files in a separate lyrics folder, the library scan marking the song
// as having lyrics, and the bulk-rename side of moving them.
//
//   dart run tool/rust/build.dart host
//   WISPIE_CORE_LIB=rust/target/<triple>/release/libwispie_core.dylib \
//     dart run tool/lyrics_files_probe.dart
//
// On Linux/Windows the library is picked up by name, so the env var can be
// omitted. Writes build/lyrics_files_probe_result.txt and exits non-zero on
// regression.

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:wispie/data/rust/rust_library_tasks.dart';
import 'package:wispie/models/song.dart';

final List<String> _failures = [];
final List<String> _lines = [];

void check(String label, bool ok, [String? detail]) {
  _lines.add(
      '${ok ? 'ok  ' : 'FAIL'} $label${detail == null ? '' : ': $detail'}');
  print(_lines.last);
  if (!ok) _failures.add(label);
}

Future<void> main() async {
  if (!RustLibraryTasks.isAvailable) {
    stderr.writeln('native core unavailable: ${RustLibraryTasks.isAvailable}');
    stderr.writeln('build it with `dart run tool/rust/build.dart host` and '
        'point WISPIE_CORE_LIB at the dylib if needed');
    exit(2);
  }

  final root = Directory(p.join('build', 'lyrics_files_probe'));
  if (root.existsSync()) root.deleteSync(recursive: true);
  final music = Directory(p.join(root.path, 'music'))
    ..createSync(recursive: true);
  final extra = Directory(p.join(root.path, 'extra'))
    ..createSync(recursive: true);
  final covers = Directory(p.join(root.path, 'covers'))
    ..createSync(recursive: true);

  Song song(String name) => Song(
      title: name,
      artist: 'A',
      album: 'B',
      filename: name,
      url: p.join(music.path, name));

  final single = song('Track One.mp3');
  final dual = song('Dual.mp3');
  final ttmlOnly = song('Ttml Only.mp3');
  final extraSong = song('Extra Song.mp3');
  final bare = song('Bare.mp3');

  for (final entry in [single, dual, ttmlOnly, extraSong, bare]) {
    File(entry.url).writeAsBytesSync(List<int>.filled(64, 0));
  }

  File(p.join(music.path, 'Track One.lrc'))
      .writeAsStringSync('[00:01.10]first\n[00:05.00]second\n');
  File(p.join(music.path, 'Dual.lrc'))
      .writeAsStringSync('[00:02.00]lrc copy\n');
  File(p.join(music.path, 'Dual.ttml')).writeAsStringSync(_ttml);
  File(p.join(music.path, 'Ttml Only.ttml')).writeAsStringSync(_ttml);
  File(p.join(extra.path, 'Extra Song.lrc'))
      .writeAsStringSync('[00:03.00]from the extra root\n');

  final links = await RustLibraryTasks.lyricsLinks(
    [single, dual, ttmlOnly, extraSong, bare],
    roots: [extra.path],
    withText: true,
  );

  final one = links[single.filename];
  check('lrc beside the song is linked', one != null, one?.path);
  check('lrc text is read', (one?.text ?? '').contains('first'));

  final two = links[dual.filename];
  check('lrc wins when both exist', two?.path.endsWith('Dual.lrc') ?? false,
      two?.path);
  check(
      'the other match is reported',
      two?.duplicates.any((path) => path.endsWith('Dual.ttml')) ?? false,
      '${two?.duplicates}');

  final converted = links[ttmlOnly.filename];
  check('ttml only still links', converted != null, converted?.path);
  check(
      'ttml converts to LRC lines',
      (converted?.text ?? '').contains('[00:12.30]First line here'),
      converted?.text);
  check('ttml decodes entities',
      (converted?.text ?? '').contains('Second & last'));
  check(
      'ttml keeps line order',
      (converted?.text ?? '').indexOf('First') <
          (converted?.text ?? '').indexOf('Second'));

  final fromRoot = links[extraSong.filename];
  check(
      'configured lyrics folder is searched', fromRoot != null, fromRoot?.path);
  check('its text comes through',
      (fromRoot?.text ?? '').contains('from the extra root'));

  check('a song with no lyrics file is not linked',
      !links.containsKey(bare.filename));

  // The scan is what marks a row as having lyrics, including for libraries that
  // existed before the files did.
  final scanned = <Song>[];
  await for (final event in RustLibraryTasks.events(RustTaskRequest(
    command: 'scan',
    roots: [music.path],
    coversDir: covers.path,
    lyricsRoots: [extra.path],
  ))) {
    if (event is List<Song>) scanned.addAll(event);
    if (event is RustTaskError) check('scan completed', false, event.message);
  }
  final scannedBare =
      scanned.where((s) => s.filename == bare.filename).toList();
  final scannedSingle =
      scanned.where((s) => s.filename == single.filename).toList();
  check('scan finds every song', scanned.length == 5, '${scanned.length}');
  check('scan marks a song with a sidecar',
      scannedSingle.isNotEmpty && scannedSingle.first.hasLyrics);
  check('scan leaves a song without one alone',
      scannedBare.isNotEmpty && !scannedBare.first.hasLyrics);

  // Renaming follows the song, extension intact.
  final moved = await RustLibraryTasks.renameLyrics({
    p.join(music.path, 'Dual.lrc'): 'Renamed',
    p.join(music.path, 'Dual.ttml'): 'Renamed',
  });
  check('both sidecars are renamed', moved.length == 2, '$moved');
  check('the lrc kept its extension',
      File(p.join(music.path, 'Renamed.lrc')).existsSync());
  check('the ttml kept its extension',
      File(p.join(music.path, 'Renamed.ttml')).existsSync());
  check(
      'the old names are gone',
      !File(p.join(music.path, 'Dual.lrc')).existsSync() &&
          !File(p.join(music.path, 'Dual.ttml')).existsSync());

  final direct = await RustLibraryTasks.lyricsFileText(
      p.join(music.path, 'Track One.lrc'));
  check('one file can be read directly', (direct ?? '').contains('second'));

  _lines.add(
      _failures.isEmpty ? 'RESULT: ok' : 'RESULT: ${_failures.length} failed');
  File(p.join('build', 'lyrics_files_probe_result.txt'))
      .writeAsStringSync('${_lines.join('\n')}\n');
  print(_lines.last);
  if (_failures.isNotEmpty) exit(1);
}

const String _ttml = '''<?xml version="1.0" encoding="UTF-8"?>
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
  <body><div>
    <p begin="00:00:12.300" end="00:00:15.000">First <span begin="00:00:12.300">line</span> here</p>
    <p begin="00:00:15.100" end="00:00:18.000">Second &amp; last</p>
  </div></body>
</tt>
''';
