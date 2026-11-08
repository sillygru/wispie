import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:wispie/data/rust/wispie_core.dart';
import 'package:wispie/domain/services/media_formats.dart';
import 'package:wispie/models/song.dart';

/// Exercises the native core against a synthetic library it builds itself.
///
/// Run: `dart run tool/rust_scan_probe.dart`
/// Artifact: `build/rust_scan_probe/report.txt`
void main() {
  final checks = <String>[];
  final failures = <String>[];
  final root = Directory(p.join('build', 'rust_scan_probe'));
  if (root.existsSync()) root.deleteSync(recursive: true);
  final library = Directory(p.join(root.path, 'library'))
    ..createSync(recursive: true);
  final covers = Directory(p.join(root.path, 'covers'))
    ..createSync(recursive: true);

  void check(String name, bool ok, [String detail = '']) {
    final line =
        '${ok ? 'PASS' : 'FAIL'}  $name${detail.isEmpty ? '' : '  ($detail)'}';
    checks.add(line);
    if (!ok) failures.add(line);
  }

  try {
    _writeFixtures(library, covers);
    final first = _scan(
      command: 'scan',
      roots: [library.path],
      excludedFolders: [p.join(library.path, 'excluded')],
      coversDir: covers.path,
      includeVideos: true,
      minFileSizeBytes: 1024,
    );

    final byName = <String, Map<String, dynamic>>{
      for (final song in first.songs) song['filename'] as String: song,
    };

    check('scan reports six songs', first.songs.length == 6,
        'got ${first.songs.length}');
    check('scan reports a completion event', first.done.isNotEmpty);
    check('scan did not cancel', first.done['cancelled'] == false);

    final a = byName['a.mp3'];
    check('tag title read', a?['title'] == 'Alpha', '${a?['title']}');
    check('tag artist read', a?['artist'] == 'Artist A', '${a?['artist']}');
    check('tag album read', a?['album'] == 'Album A', '${a?['album']}');
    check('duration read', ((a?['duration'] as num?) ?? 0) > 0.5,
        '${a?['duration']}');
    check('release year kept', _yearOf(a?['song_date_epoch_sec']) == 2019,
        '${a?['song_date_epoch_sec']}');

    final aCover = a?['cover_url'] as String?;
    check('embedded cover cached', _isHashCover(aCover), '$aCover');
    final decoded = _decodeCover(aCover);
    check('cover decodes', decoded != null);
    check(
        'oversized cover shrunk',
        decoded != null && decoded.width <= 1024 && decoded.height <= 1024,
        decoded == null ? 'none' : '${decoded.width}x${decoded.height}');
    check(
        'cover aspect kept',
        decoded != null && (decoded.width - 1024).abs() <= 1,
        decoded == null ? 'none' : '${decoded.width}');

    final b = byName['b.mp3'];
    check(
      'folder cover used',
      b?['cover_url'] == p.join(library.path, 'release', 'cover.jpg'),
      '${b?['cover_url']}',
    );

    final c = byName['c.mp3'];
    final cCover = c?['cover_url'] as String?;
    check('small jpeg cover cached', _isHashCover(cCover), '$cCover');
    check(
      'small jpeg stored verbatim',
      cCover != null && _bytes(cCover).join(',') == _smallJpeg.join(','),
    );

    final cached = byName['cached.mp3'];
    final cachedPath = p.join(covers.path, '${_sha1('cached.mp3')}.jpg');
    check('pre-existing cache honoured', cached?['cover_url'] == cachedPath,
        '${cached?['cover_url']}');

    final broken = byName['broken.mp3'];
    check('broken file still listed', broken != null);
    check('broken file keeps filename title', broken?['title'] == 'broken',
        '${broken?['title']}');
    check(
        'unreadable file counted',
        ((first.done['unreadable'] as num?) ?? 0) >= 1,
        '${first.done['unreadable']}');

    final video = byName['video.mp4'];
    check('video listed without tag read', video?['title'] == 'video',
        '${video?['title']}');
    check('video has no duration', video?['duration'] == null);
    check('video has no cover', video?['cover_url'] == null);

    check('excluded folder skipped', !byName.containsKey('d.mp3'));
    check('undersized file skipped', !byName.containsKey('small.mp3'));
    check('no unlistable roots', (first.done['unreachable'] as List).isEmpty);
    check(
        'progress reaches one',
        first.progress.isNotEmpty && first.progress.last >= 0.999,
        '${first.progress.isEmpty ? 'none' : first.progress.last}');

    final formatsRun = _scan(command: 'formats');
    check(
        'formats match Dart list',
        _sameSet(formatsRun.formats?['supported'], MediaFormats.supported),
        '${formatsRun.formats?['supported']}');
    check(
        'video formats match Dart list',
        _sameSet(formatsRun.formats?['video'], Song.videoExtensions),
        '${formatsRun.formats?['video']}');

    // A second scan with the same mtime must reuse the row, not re-read tags.
    File(p.join(library.path, 'a.mp3'))
        .setLastModifiedSync(DateTime.now().subtract(const Duration(days: 3)));
    _writeMp3(
      File(p.join(library.path, 'a.mp3')),
      title: 'Changed',
      artist: 'Someone Else',
      album: 'Elsewhere',
      year: 2024,
      picture: _bigPng,
    );
    final original = _mtimeOf(p.join(library.path, 'a.mp3'));
    File(p.join(library.path, 'a.mp3')).setLastModifiedSync(original);

    final watch = Stopwatch()..start();
    final second = _scan(
      command: 'scan',
      roots: [library.path],
      excludedFolders: [p.join(library.path, 'excluded')],
      coversDir: covers.path,
      includeVideos: true,
      minFileSizeBytes: 1024,
      existing: first.songs,
      playCounts: {'a.mp3': 7},
    );
    watch.stop();

    final reused = <String, Map<String, dynamic>>{
      for (final song in second.songs) song['filename'] as String: song,
    };
    check('rescan kept the unchanged row', reused['a.mp3']?['title'] == 'Alpha',
        '${reused['a.mp3']?['title']}');
    check('rescan applied play counts', reused['a.mp3']?['play_count'] == 7,
        '${reused['a.mp3']?['play_count']}');
    check('rescan kept the cover', reused['a.mp3']?['cover_url'] == aCover);

    // Import path: fast scan writes placeholders, the tasks fill them in.
    final fresh = Directory(p.join(root.path, 'fresh'))
      ..createSync(recursive: true);
    final freshCovers = Directory(p.join(root.path, 'fresh_covers'))
      ..createSync(recursive: true);
    _writeMp3(File(p.join(fresh.path, 'e.mp3')),
        title: 'Epsilon',
        artist: 'Artist F',
        album: 'Album F',
        year: 2018,
        picture: _smallJpeg);

    final fast = _scan(
      command: 'scan',
      roots: [fresh.path],
      coversDir: freshCovers.path,
      fastMode: true,
    );
    check('fast scan writes a placeholder row',
        fast.songs.single['title'] == 'e', '${fast.songs.single['title']}');
    check('fast scan extracts no art', fast.songs.single['cover_url'] == null);

    final covered = _task({
      'command': 'extract_covers',
      'coversDir': freshCovers.path,
      'songs': fast.songs,
    });
    final sweptCover = covered.songs.single['cover_url'] as String?;
    check(
        'cover sweep finds embedded art',
        sweptCover != null && p.basename(sweptCover).startsWith('c_'),
        '$sweptCover');

    final enriched = _task({
      'command': 'enrich',
      'coversDir': freshCovers.path,
      'songs': covered.songs,
    });
    check('enrich fills tags in', enriched.songs.single['title'] == 'Epsilon',
        '${enriched.songs.single['title']}');
    check('enrich keeps the cover',
        enriched.songs.single['cover_url'] == sweptCover);

    final facts = _task({
      'command': 'read_facts',
      'paths': [p.join(fresh.path, 'e.mp3')],
    });
    check('folder facts read tags', facts.facts.single['title'] == 'Epsilon',
        '${facts.facts.single['title']}');

    final rebuilt = _task({
      'command': 'rebuild_covers',
      'coversDir': freshCovers.path,
      'force': true,
      'songs': enriched.songs,
    });
    check('cover rebuild resolves audio art', rebuilt.covers.length == 1,
        '${rebuilt.covers.length}');

    // Folder listing keeps the Dart walk's guards: sorted, hidden skipped.
    final tree = Directory(p.join(root.path, 'tree'))
      ..createSync(recursive: true);
    final sub = Directory(p.join(tree.path, 'sub'))
      ..createSync(recursive: true);
    final hidden = Directory(p.join(tree.path, '.hidden'))
      ..createSync(recursive: true);
    _writeMp3(File(p.join(tree.path, 'top.mp3')),
        title: 'Top', artist: 'A', album: 'B', year: 2020);
    _writeMp3(File(p.join(sub.path, 'deep.mp3')),
        title: 'Deep', artist: 'A', album: 'B', year: 2020);
    _writeMp3(File(p.join(hidden.path, 'hidden.mp3')),
        title: 'Hidden', artist: 'A', album: 'B', year: 2020);
    File(p.join(tree.path, 'notes.txt')).writeAsStringSync('not media');

    final listed = _task({
      'command': 'list_media',
      'root': tree.path,
      'recursive': true,
    }).paths;
    check('folder listing finds media files', listed.length == 2,
        '${listed.length}');
    check('folder listing skips hidden folders',
        !listed.any((path) => path.contains('.hidden')));
    check('folder listing is sorted', _isSorted(listed));
    final shallow = _task({
      'command': 'list_media',
      'root': tree.path,
      'recursive': false,
    }).paths;
    check('folder listing honours recursive false', shallow.length == 1,
        '${shallow.length}');
    check(
        'folder listing tolerates a missing root',
        _task({'command': 'list_media', 'root': p.join(tree.path, 'nope')})
            .paths
            .isEmpty);

    // Compaction turns legacy cover names into content-addressed ones.
    final legacy = Directory(p.join(root.path, 'legacy_covers'))
      ..createSync(recursive: true);
    final legacyA = File(p.join(legacy.path, 'legacy_a.jpg'))
      ..writeAsBytesSync(_smallJpeg);
    final legacyB = File(p.join(legacy.path, 'legacy_b.jpg'))
      ..writeAsBytesSync(_smallJpeg);
    final keyed = File(p.join(legacy.path, 'c_${_sha1('keep')}.jpg'))
      ..writeAsBytesSync(_smallJpeg);
    final compacted = _task({
      'command': 'compact_covers',
      'coversDir': legacy.path,
      'paths': [legacyA.path, legacyB.path, keyed.path],
    }).compacted;
    check('compaction rewrote both legacy names', compacted.length == 2,
        '${compacted.length}');
    check(
        'compaction deduped identical art',
        compacted[legacyA.path] != null &&
            compacted[legacyA.path] == compacted[legacyB.path]);
    final compactedTarget = compacted[legacyA.path];
    check(
        'compaction target is content addressed',
        compactedTarget != null &&
            p.basename(compactedTarget).startsWith('c_') &&
            File(compactedTarget).existsSync(),
        '$compactedTarget');
    check('compaction leaves keyed covers alone',
        !compacted.containsKey(keyed.path));

    final report = StringBuffer()
      ..writeln('wispie rust core probe')
      ..writeln('library: ${library.path}')
      ..writeln('first scan: ${first.elapsed.inMilliseconds} ms')
      ..writeln('rescan: ${watch.elapsedMilliseconds} ms')
      ..writeln('')
      ..writeAll(checks.map((line) => '$line\n'))
      ..writeln('')
      ..writeln(
          failures.isEmpty ? 'ALL CHECKS PASSED' : '${failures.length} FAILED');
    root.childFile('report.txt').writeAsStringSync(report.toString());
    root.childFile('songs.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(first.songs));
    stdout.write(report);
  } catch (error, stack) {
    root.childFile('report.txt').writeAsStringSync('CRASH: $error\n$stack');
    stderr.writeln('probe crashed: $error\n$stack');
    exit(2);
  }

  if (failures.isNotEmpty) exit(1);
}

extension on Directory {
  File childFile(String name) => File(p.join(path, name));
}

class _ScanOutcome {
  _ScanOutcome(
      this.songs, this.done, this.progress, this.formats, this.elapsed);

  final List<Map<String, dynamic>> songs;
  final Map<String, dynamic> done;
  final List<double> progress;
  final Map<String, dynamic>? formats;
  final Duration elapsed;
}

_ScanOutcome _scan({
  required String command,
  List<String> roots = const [],
  List<String> excludedFolders = const [],
  String coversDir = '',
  bool includeVideos = false,
  int minFileSizeBytes = 0,
  bool fastMode = false,
  List<Map<String, dynamic>> existing = const [],
  Map<String, int> playCounts = const {},
}) {
  final songs = <Map<String, dynamic>>[];
  final progress = <double>[];
  var done = <String, dynamic>{};
  Map<String, dynamic>? formats;

  final watch = Stopwatch()..start();
  final code = WispieCore.run(
    {
      'command': command,
      'roots': roots,
      'excludedFolders': excludedFolders,
      'coversDir': coversDir,
      'includeVideos': includeVideos,
      'minFileSizeBytes': minFileSizeBytes,
      'fastMode': fastMode,
      'existing': existing,
      'playCounts': playCounts,
    },
    onEvent: (kind, payload) {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      switch (kind) {
        case 0:
          songs.addAll((decoded['songs'] as List).cast<Map<String, dynamic>>());
        case 1:
          final total = (decoded['total'] as num).toDouble();
          final doneCount = (decoded['done'] as num).toDouble();
          progress.add(total == 0 ? 1 : doneCount / total);
        case 2:
          done = decoded;
          formats = decoded['formats'] as Map<String, dynamic>?;
        case 3:
          throw StateError('native core error: ${decoded['message']}');
      }
    },
  );
  watch.stop();

  if (code != 0) throw StateError('native core exited with $code');
  return _ScanOutcome(songs, done, progress, formats, watch.elapsed);
}

class _TaskOutcome {
  _TaskOutcome({
    this.songs = const [],
    this.covers = const {},
    this.facts = const [],
    this.paths = const [],
    this.compacted = const {},
  });

  final List<Map<String, dynamic>> songs;
  final Map<String, String> covers;
  final List<Map<String, dynamic>> facts;
  final List<String> paths;
  final Map<String, String> compacted;
}

_TaskOutcome _task(Map<String, Object?> request) {
  final songs = <Map<String, dynamic>>[];
  final covers = <String, String>{};
  final facts = <Map<String, dynamic>>[];
  final paths = <String>[];
  final compacted = <String, String>{};

  final code = WispieCore.run(request, onEvent: (kind, payload) {
    if (kind != WispieCore.eventItems) return;
    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    if (decoded['songs'] case final List<dynamic> raw) {
      songs.addAll(raw.cast<Map<String, dynamic>>());
    } else if (decoded['covers'] case final Map<String, dynamic> raw) {
      covers.addAll(Map<String, String>.from(raw));
    } else if (decoded['facts'] case final List<dynamic> raw) {
      facts.addAll(raw.cast<Map<String, dynamic>>());
    } else if (decoded['paths'] case final List<dynamic> raw) {
      paths.addAll(raw.cast<String>());
    } else if (decoded['compacted'] case final Map<String, dynamic> raw) {
      compacted.addAll(Map<String, String>.from(raw));
    }
  });
  if (code != 0) throw StateError('task exited with $code');
  return _TaskOutcome(
    songs: songs,
    covers: covers,
    facts: facts,
    paths: paths,
    compacted: compacted,
  );
}

bool _isSorted(List<String> values) {
  for (var i = 1; i < values.length; i++) {
    if (values[i - 1].compareTo(values[i]) > 0) return false;
  }
  return true;
}

bool _sameSet(Object? raw, Set<String> expected) {
  if (raw is! List) return false;
  final actual = raw.cast<String>().toSet();
  return actual.length == expected.length && actual.containsAll(expected);
}

bool _isHashCover(String? path) {
  if (path == null) return false;
  final name = p.basename(path);
  return path.startsWith(p.join('build', 'rust_scan_probe', 'covers')) &&
      name.startsWith('c_');
}

int? _yearOf(Object? epochSeconds) {
  if (epochSeconds is! num) return null;
  return DateTime.fromMillisecondsSinceEpoch(
    (epochSeconds * 1000).round(),
    isUtc: false,
  ).year;
}

Uint8List _bytes(String path) => File(path).readAsBytesSync();

img.Image? _decodeCover(String? path) {
  if (path == null || !File(path).existsSync()) return null;
  return img.decodeImage(_bytes(path));
}

DateTime _mtimeOf(String path) => File(path).lastModifiedSync();

String _sha1(String value) => sha1.convert(utf8.encode(value)).toString();

Uint8List? _bigPngCache;
Uint8List get _bigPng => _bigPngCache ??= _image(1200, 900, png: true);
Uint8List? _smallJpegCache;
Uint8List get _smallJpeg => _smallJpegCache ??= _image(200, 200, png: false);

Uint8List _image(int width, int height, {required bool png}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(30, 120, 200));
  return Uint8List.fromList(
      png ? img.encodePng(image) : img.encodeJpg(image, quality: 92));
}

void _writeFixtures(Directory library, Directory covers) {
  _writeMp3(File(p.join(library.path, 'a.mp3')),
      title: 'Alpha',
      artist: 'Artist A',
      album: 'Album A',
      year: 2019,
      picture: _bigPng);
  final release = Directory(p.join(library.path, 'release'))
    ..createSync(recursive: true);
  _writeMp3(File(p.join(release.path, 'b.mp3')),
      title: 'Beta', artist: 'Artist B', album: 'Album B', year: 2020);
  _writeMp3(File(p.join(library.path, 'cached.mp3')),
      title: 'Cached', artist: 'Artist C', album: 'Album C', year: 2021);

  final nested = Directory(p.join(library.path, 'nested'))
    ..createSync(recursive: true);
  _writeMp3(File(p.join(nested.path, 'c.mp3')),
      title: 'Gamma',
      artist: 'Artist D',
      album: 'Album D',
      year: 2022,
      picture: _smallJpeg);
  File(p.join(nested.path, 'broken.mp3')).writeAsBytesSync(
      List<int>.generate(4096, (index) => (index * 37) % 251));

  final excluded = Directory(p.join(library.path, 'excluded'))
    ..createSync(recursive: true);
  _writeMp3(File(p.join(excluded.path, 'd.mp3')),
      title: 'Delta', artist: 'Artist E', album: 'Album E', year: 2023);

  File(p.join(library.path, 'video.mp4'))
      .writeAsBytesSync(List<int>.filled(2048, 7));
  File(p.join(library.path, 'small.mp3'))
      .writeAsBytesSync(List<int>.filled(64, 0));
  File(p.join(release.path, 'cover.jpg')).writeAsBytesSync(_smallJpeg);
  File(p.join(covers.path, '${_sha1('cached.mp3')}.jpg'))
      .writeAsBytesSync(_smallJpeg);
}

void _writeMp3(
  File file, {
  required String title,
  required String artist,
  required String album,
  required int year,
  Uint8List? picture,
}) {
  final frames = <List<int>>[
    _textFrame('TIT2', title),
    _textFrame('TPE1', artist),
    _textFrame('TALB', album),
    _textFrame('TDRC', '$year'),
  ];
  if (picture != null) {
    frames.add(_apicFrame(picture));
  }

  final body = <int>[for (final frame in frames) ...frame];
  final tag = <int>[
    ...ascii.encode('ID3'),
    0x04,
    0x00,
    0x00,
    ..._syncsafe(body.length),
    ...body,
  ];
  file.writeAsBytesSync([...tag, ..._silentAudio()]);
}

List<int> _syncsafe(int value) => [
      (value >> 21) & 0x7F,
      (value >> 14) & 0x7F,
      (value >> 7) & 0x7F,
      value & 0x7F,
    ];

List<int> _frame(String id, List<int> body) => [
      ...ascii.encode(id),
      ..._syncsafe(body.length),
      0x00,
      0x00,
      ...body,
    ];

List<int> _textFrame(String id, String value) =>
    _frame(id, [0x03, ...utf8.encode(value)]);

List<int> _apicFrame(Uint8List image) => _frame('APIC', [
      0x03,
      ...latin1.encode('image/png'),
      0x00,
      0x03,
      0x00,
      ...image,
    ]);

/// Silent MPEG-1 Layer III frames: 128 kbps, 44.1 kHz, 417 bytes each.
List<int> _silentAudio({int count = 40}) {
  final frame = Uint8List(417)..setAll(0, [0xFF, 0xFB, 0x90, 0x64]);
  return [for (var i = 0; i < count; i++) ...frame];
}
