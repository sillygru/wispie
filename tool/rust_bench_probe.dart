import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart' as amr;
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:wispie/data/rust/wispie_core.dart';
import 'package:wispie/domain/services/song_folder_reader.dart';
import 'package:wispie/domain/services/song_match_planner.dart';
import 'package:wispie/services/folder_scan_service.dart';

/// Times the native core against the Dart code it replaces, on one fixture set.
///
/// The Dart side mirrors the per-file work the app's own paths do (tag parse,
/// cover decode/resize/encode, hashing), in a single isolate, which is how the
/// app runs those paths when the native core is absent.
///
/// Run:
///   WISPIE_CORE_LIB=rust/target/release/libwispie_core.dylib \
///     dart run tool/rust_bench_probe.dart
/// Artifact: `build/rust_bench/report.md`
Future<void> main() async {
  final failures = <String>[];
  final cases = <_Case>[];

  void check(String name, bool ok, [String detail = '']) {
    if (!ok) failures.add('$name${detail.isEmpty ? '' : '  ($detail)'}');
  }

  final root = Directory(p.join('build', 'rust_bench'));
  if (root.existsSync()) root.deleteSync(recursive: true);

  // Two shapes on purpose: art-heavy files exercise decode/resize/encode, a
  // wide tag-only folder exercises the import compare that reads a library.
  final library = Directory(p.join(root.path, 'library'))
    ..createSync(recursive: true);
  final covers = [for (var i = 0; i < _artFiles; i++) _coverBytes(i)];
  final artPaths = <String>[];
  for (var i = 0; i < _artFiles; i++) {
    final file =
        File(p.join(library.path, 'art_${i.toString().padLeft(3, '0')}.mp3'));
    _writeMp3(
      file,
      title: 'Title $i',
      artist: 'Artist ${i % 7}',
      album: 'Album ${i % 11}',
      year: 1990 + i % 30,
      picture: covers[i],
    );
    artPaths.add(file.path);
  }

  final bulk = Directory(p.join(root.path, 'bulk'))
    ..createSync(recursive: true);
  final bulkPaths = <String>[];
  for (var i = 0; i < _bulkFiles; i++) {
    final file =
        File(p.join(bulk.path, 'bulk_${i.toString().padLeft(4, '0')}.mp3'));
    _writeMp3(
      file,
      title: 'Bulk $i',
      artist: 'Artist ${i % 7}',
      album: 'Album ${i % 11}',
      year: 1990 + i % 30,
    );
    bulkPaths.add(file.path);
  }

  final dartCovers = Directory(p.join(root.path, 'covers_dart'))
    ..createSync(recursive: true);
  final rustCovers = Directory(p.join(root.path, 'covers_rust'))
    ..createSync(recursive: true);

  // 1. First analyze: read tags and cache art for every file.
  var dartRows = <_Row>[];
  final dartScanUs =
      _time(() => dartRows = _dartScan(artPaths, dartCovers.path));
  var rustRows = <Map<String, dynamic>>[];
  final rustScanUs = _time(() => rustRows = _native({
        'command': 'scan',
        'roots': [library.path],
        'coversDir': rustCovers.path,
        'includeVideos': false,
        'minFileSizeBytes': 0,
        'batchSize': 200,
      }).songs);
  cases.add(
      _Case('scan: tags + cover cache', dartScanUs, rustScanUs, _artFiles));
  check(
      'scan: a row per file on both sides',
      dartRows.length == _artFiles && rustRows.length == _artFiles,
      '${dartRows.length} vs ${rustRows.length}');
  check(
      'scan: titles agree',
      _join([for (final row in dartRows) row.title]) ==
          _join([for (final row in rustRows) row['title'] as String? ?? '']));
  check(
      'scan: art cached on both sides',
      dartRows.every((row) => row.coverPath != null) &&
          rustRows.every((row) => (row['cover_url'] as String?) != null));
  check('scan: cached art decodes',
      rustRows.every((row) => _decodes(row['cover_url'] as String?)));

  // 2. Import compare: what a folder says about itself, no art, no writes.
  var dartFacts = <FolderSongRef>[];
  final dartFactsUs =
      _time(() => dartFacts = SongFolderReader.readFactsSync(bulkPaths));
  var rustFacts = <Map<String, dynamic>>[];
  final rustFactsUs = _time(() =>
      rustFacts = _native({'command': 'read_facts', 'paths': bulkPaths}).facts);
  cases
      .add(_Case('import: folder facts', dartFactsUs, rustFactsUs, _bulkFiles));
  check(
      'facts: a row per file on both sides',
      dartFacts.length == _bulkFiles && rustFacts.length == _bulkFiles,
      '${dartFacts.length} vs ${rustFacts.length}');
  check(
      'facts: titles agree',
      _join([for (final row in dartFacts) row.title ?? '']) ==
          _join([for (final row in rustFacts) row['title'] as String? ?? '']));
  check('facts: artist and album agree', _factsAgree(dartFacts, rustFacts));
  check('facts: durations agree', _durationsAgree(dartFacts, rustFacts));

  // 3. Enrichment: the fast scan left placeholders, fill them in.
  final placeholders = [for (final path in bulkPaths) _placeholder(path)];
  var dartEnriched = <Map<String, dynamic>>[];
  final dartEnrichUs = _time(() => dartEnriched = _dartEnrich(placeholders));
  var rustEnriched = <Map<String, dynamic>>[];
  final rustEnrichUs = _time(() => rustEnriched =
      _native({'command': 'enrich', 'songs': placeholders}).songs);
  cases.add(_Case(
      'import: enrich placeholders', dartEnrichUs, rustEnrichUs, _bulkFiles));
  check(
      'enrich: a row per file on both sides',
      dartEnriched.length == _bulkFiles && rustEnriched.length == _bulkFiles,
      '${dartEnriched.length} vs ${rustEnriched.length}');
  check(
      'enrich: titles agree',
      _join([for (final row in dartEnriched) row['title'] as String? ?? '']) ==
          _join(
              [for (final row in rustEnriched) row['title'] as String? ?? '']));

  // 4. Cover cache compaction: rewrite legacy names to content keys.
  final legacyDart = _legacyCovers(
      Directory(p.join(root.path, 'legacy_dart'))..createSync(recursive: true),
      covers);
  final legacyRust = _legacyCovers(
      Directory(p.join(root.path, 'legacy_rust'))..createSync(recursive: true),
      covers);
  var dartCompacted = <String, String>{};
  final dartCompactUs = _time(
      () => dartCompacted = _dartCompact(legacyDart, legacyDart.first.parent));
  var rustCompacted = <String, String>{};
  final rustCompactUs = _time(() => rustCompacted = _native({
        'command': 'compact_covers',
        'coversDir': legacyRust.first.parent.path,
        'paths': [for (final file in legacyRust) file.path],
      }).compacted);
  cases.add(
      _Case('cover cache compaction', dartCompactUs, rustCompactUs, _artFiles));
  check(
      'compaction: every legacy file rewritten',
      dartCompacted.length == _artFiles && rustCompacted.length == _artFiles,
      '${dartCompacted.length} vs ${rustCompacted.length}');
  String mapping(Map<String, String> compacted) => _join([
        for (final entry in compacted.entries)
          '${p.basename(entry.key)}=${p.basename(entry.value)}',
      ]..sort());
  check('compaction: same mapping on both sides',
      mapping(dartCompacted) == mapping(rustCompacted));
  check(
      'compaction: targets are content addressed',
      rustCompacted.values
          .every((target) => p.basename(target).startsWith('c_')));

  // 5. The wrapper the app calls must answer like the Dart reader.
  final wrappedFiles = await FolderScanService.listMediaFiles(bulk.path);
  final sample = bulkPaths.take(5).toList();
  final wrappedFacts = await FolderScanService.readFacts(sample);
  final referenceFacts = SongFolderReader.readFactsSync(sample);
  check('wrapper: lists the same files', wrappedFiles.length == _bulkFiles,
      '${wrappedFiles.length}');
  check(
      'wrapper: reads the same tags',
      _join([for (final row in wrappedFacts) row.title ?? '']) ==
          _join([for (final row in referenceFacts) row.title ?? '']));
  check(
      'wrapper: keeps the path and length',
      wrappedFacts.every((row) => row.path.isNotEmpty) &&
          wrappedFacts.first.duration != null);

  for (final item in cases) {
    check(
        '${item.name}: native is not slower',
        item.rustMicros <= item.dartMicros * 1.05,
        '${item.dartMillis} vs ${item.rustMillis}');
  }

  final report = StringBuffer()
    ..writeln('# Native core vs Dart')
    ..writeln()
    ..writeln('Generated by `dart run tool/rust_bench_probe.dart`.')
    ..writeln()
    ..writeln('- platform: ${Platform.operatingSystem}, '
        'dart ${Platform.version.split(' ').first}')
    ..writeln('- input: $_artFiles mp3 files with a 1200x900 JPEG cover each, '
        'plus $_bulkFiles tag-only mp3 files')
    ..writeln('- one run per side, cold caches, JSON decoding included')
    ..writeln()
    ..writeln(
        '| Case | Dart | Native | Speedup | Dart files/s | Native files/s |')
    ..writeln('| --- | ---: | ---: | ---: | ---: | ---: |');
  for (final item in cases) {
    report.writeln('| ${item.name} | ${item.files} | ${item.dartMillis} '
        '| ${item.rustMillis} | ${item.speedup.toStringAsFixed(1)}x '
        '| ${item.dartPerSecond.round()} | ${item.rustPerSecond.round()} |');
  }
  report
    ..writeln()
    ..writeln(failures.isEmpty
        ? 'All checks passed.'
        : '${failures.length} checks failed:')
    ..writeln()
    ..writeln([for (final failure in failures) '- $failure'].join('\n'));

  final artifact = File(p.join(root.path, 'report.md'));
  artifact.writeAsStringSync(report.toString());

  stdout.write(report.toString());
  stdout.writeln('Report: ${artifact.path}');

  exitCode = failures.isEmpty ? 0 : 1;
}

const int _artFiles = 20;
const int _bulkFiles = 400;
const int _maxDimension = 1024;
const int _jpegQuality = 88;
const int _fastPathBytes = 250 * 1024;

class _Case {
  _Case(this.name, this.dartMicros, this.rustMicros, this.files);

  final String name;
  final int dartMicros;
  final int rustMicros;
  final int files;

  double get speedup => rustMicros == 0 ? 0 : dartMicros / rustMicros;
  double get dartPerSecond =>
      dartMicros == 0 ? 0 : files * 1000000 / dartMicros;
  double get rustPerSecond =>
      rustMicros == 0 ? 0 : files * 1000000 / rustMicros;
  String get dartMillis => _ms(dartMicros);
  String get rustMillis => _ms(rustMicros);
}

class _Row {
  _Row(this.title, this.coverPath);

  final String title;
  final String? coverPath;
}

class _NativeResult {
  _NativeResult(this.songs, this.facts, this.paths, this.compacted);

  final List<Map<String, dynamic>> songs;
  final List<Map<String, dynamic>> facts;
  final List<String> paths;
  final Map<String, String> compacted;
}

_NativeResult _native(Map<String, Object?> request) {
  final songs = <Map<String, dynamic>>[];
  final facts = <Map<String, dynamic>>[];
  final paths = <String>[];
  final compacted = <String, String>{};

  final code = WispieCore.run(request, onEvent: (kind, payload) {
    if (kind != WispieCore.eventItems) return;
    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    if (decoded['songs'] case final List<dynamic> raw) {
      songs.addAll(raw.cast<Map<String, dynamic>>());
    } else if (decoded['facts'] case final List<dynamic> raw) {
      facts.addAll(raw.cast<Map<String, dynamic>>());
    } else if (decoded['paths'] case final List<dynamic> raw) {
      paths.addAll(raw.cast<String>());
    } else if (decoded['compacted'] case final Map<String, dynamic> raw) {
      compacted.addAll(Map<String, String>.from(raw));
    }
  });
  if (code != 0) throw StateError('native task exited with $code');
  return _NativeResult(songs, facts, paths, compacted);
}

int _time(void Function() body) {
  final watch = Stopwatch()..start();
  body();
  watch.stop();
  return watch.elapsedMicroseconds;
}

String _ms(int micros) => '${(micros / 1000).toStringAsFixed(1)} ms';

String _join(Iterable<String> values) => values.join('|');

bool _decodes(String? path) {
  if (path == null) return false;
  final file = File(path);
  if (!file.existsSync() || file.lengthSync() == 0) return false;
  return img.decodeImage(file.readAsBytesSync()) != null;
}

bool _factsAgree(List<FolderSongRef> dart, List<Map<String, dynamic>> rust) {
  for (var i = 0; i < dart.length; i++) {
    if ((dart[i].artist ?? '') != (rust[i]['artist'] as String? ?? '')) {
      return false;
    }
    if ((dart[i].album ?? '') != (rust[i]['album'] as String? ?? '')) {
      return false;
    }
  }
  return true;
}

bool _durationsAgree(
    List<FolderSongRef> dart, List<Map<String, dynamic>> rust) {
  for (var i = 0; i < dart.length; i++) {
    final expected = (dart[i].duration?.inMilliseconds ?? 0) / 1000;
    final actual = (rust[i]['duration'] as num?)?.toDouble() ?? 0;
    if ((expected - actual).abs() > 0.25) {
      return false;
    }
  }
  return true;
}

List<_Row> _dartScan(List<String> paths, String coversDir) {
  final rows = <_Row>[];
  for (final path in paths) {
    String? title;
    String? cover;
    try {
      final metadata = amr.readMetadata(File(path), getImage: true);
      title = metadata.title;
      if (metadata.pictures.isNotEmpty) {
        cover = _dartSaveCover(
            Uint8List.fromList(metadata.pictures.first.bytes), coversDir);
      }
    } catch (_) {
      // An unreadable file becomes a placeholder row, as the scanner does.
    }
    rows.add(_Row(title ?? p.basenameWithoutExtension(path), cover));
  }
  return rows;
}

List<Map<String, dynamic>> _dartEnrich(List<Map<String, dynamic>> rows) {
  final out = <Map<String, dynamic>>[];
  for (final row in rows) {
    try {
      final metadata =
          amr.readMetadata(File(row['url'] as String), getImage: false);
      out.add({
        ...row,
        'title': metadata.title ?? row['title'],
        'artist': metadata.artist ?? row['artist'],
        'album': metadata.album ?? row['album'],
        'duration': metadata.duration == null
            ? null
            : metadata.duration!.inMilliseconds / 1000,
      });
    } catch (_) {
      out.add(row);
    }
  }
  return out;
}

Map<String, String> _dartCompact(List<File> files, Directory coversDir) {
  final out = <String, String>{};
  for (final file in files) {
    final saved = _dartSaveCover(file.readAsBytesSync(), coversDir.path);
    if (saved != null && saved != file.path) out[file.path] = saved;
  }
  return out;
}

/// The same contract `CoverOptimizer.saveOptimizedCover` implements.
String? _dartSaveCover(Uint8List bytes, String coversDir) {
  if (bytes.isEmpty) return null;
  final key = 'c_${sha1.convert(bytes)}';
  for (final extension in const ['.jpg', '.webp', '.png', '.jpeg']) {
    final existing = File(p.join(coversDir, '$key$extension'));
    if (existing.existsSync() && existing.lengthSync() > 0) {
      return existing.path;
    }
  }

  final decoded = img.decodeImage(bytes);
  final target = p.join(coversDir, '$key.jpg');
  if (decoded == null) {
    _writeAtomic(target, bytes);
    return target;
  }

  final oversized =
      decoded.width > _maxDimension || decoded.height > _maxDimension;
  if (!oversized && bytes.length <= _fastPathBytes) {
    _writeAtomic(target, bytes);
    return target;
  }

  var toEncode = decoded;
  if (oversized) {
    final wider = decoded.width >= decoded.height;
    final width = wider
        ? _maxDimension
        : (decoded.width * _maxDimension / decoded.height).round();
    final height = wider
        ? (decoded.height * _maxDimension / decoded.width).round()
        : _maxDimension;
    toEncode = img.copyResize(decoded,
        width: width, height: height, interpolation: img.Interpolation.cubic);
  }

  _writeAtomic(target,
      Uint8List.fromList(img.encodeJpg(toEncode, quality: _jpegQuality)));
  return target;
}

void _writeAtomic(String target, Uint8List bytes) {
  final temp = File('$target.tmp_${DateTime.now().microsecondsSinceEpoch}');
  temp.writeAsBytesSync(bytes);
  try {
    temp.renameSync(target);
  } catch (_) {
    if (!File(target).existsSync()) rethrow;
  }
}

Map<String, dynamic> _placeholder(String path) => {
      'title': p.basenameWithoutExtension(path),
      'artist': 'Unknown Artist',
      'album': 'Unknown Album',
      'filename': p.basename(path),
      'url': path,
      'has_lyrics': false,
      'play_count': 0,
    };

List<File> _legacyCovers(Directory directory, List<Uint8List> covers) => [
      for (var i = 0; i < covers.length; i++)
        File(p.join(directory.path, 'legacy_$i.jpg'))
          ..writeAsBytesSync(covers[i]),
    ];

Uint8List _coverBytes(int index) {
  final image = img.Image(width: 1200, height: 900);
  img.fill(
    image,
    color: img.ColorRgb8(
      (index * 7) % 255,
      (index * 13) % 255,
      (index * 29) % 255,
    ),
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
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
  if (picture != null) frames.add(_apicFrame(picture));

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
      ...latin1.encode('image/jpeg'),
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
