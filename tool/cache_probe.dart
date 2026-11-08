// SPDX-License-Identifier: GPL-3.0-only
//
// Probe for the wispie cache: file naming, budgets, the binary waveform format,
// atomic waveform writes and the migration off the old `gru_cache_v3` layout.
//
//   dart run tool/cache_probe.dart
//
// Artifact: build/cache_probe.json (exit code 1 on any failure).

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:wispie/domain/services/cache_migration.dart';
import 'package:wispie/domain/services/cache_policy.dart';

final List<Map<String, Object?>> _results = [];
int _passed = 0;
int _failed = 0;

void check(String name, bool condition, {Object? detail}) {
  if (condition) {
    _passed++;
    _results.add({'check': name, 'ok': true});
    stdout.writeln('  ok   $name');
  } else {
    _failed++;
    _results.add({'check': name, 'ok': false, 'detail': detail?.toString()});
    stdout.writeln('  FAIL $name${detail == null ? '' : ' -> $detail'}');
  }
}

Future<void> main() async {
  _checkWaveforms();
  _checkWaveformFiles();
  _checkNames();
  _checkBuckets();
  _checkGate();
  await _checkMigration();

  final artifact = {
    'passed': _passed,
    'failed': _failed,
    'checks': _results,
  };
  final dir = Directory('build');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('build/cache_probe.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(artifact));

  stdout.writeln('\n$_passed passed, $_failed failed');
  stdout.writeln('artifact: build/cache_probe.json');
  if (_failed > 0) exitCode = 1;
}

List<double> _probeBars() => List<double>.generate(
      waveformBarCount,
      (i) => (0.5 + 0.5 * math.sin(i / 12)).clamp(0.0, 1.0),
    );

void _checkWaveforms() {
  final bars = _probeBars();
  final encoded = encodeWaveformBars(bars);
  final decoded = decodeWaveformBars(encoded);
  final jsonBytes = utf8.encode(jsonEncode(bars)).length;

  check('waveform roundtrip keeps every bar', decoded.length == bars.length,
      detail: '${decoded.length} bars');
  check(
    'waveform roundtrip stays within one step',
    _maxError(bars, decoded) <= 1 / 255,
    detail: _maxError(bars, decoded),
  );
  check(
    'binary waveform is a fraction of the JSON it replaced',
    encoded.length * 8 < jsonBytes,
    detail: '${encoded.length}B vs ${jsonBytes}B',
  );

  final zero = encodeWaveformBars(List<double>.filled(64, 0));
  check('zero bars stay zero', decodeWaveformBars(zero).every((v) => v == 0));
  check(
    'out-of-range values clamp instead of wrapping',
    decodeWaveformBars(encodeWaveformBars([-1, 0.5, 2]))[0] == 0 &&
        decodeWaveformBars(encodeWaveformBars([-1, 0.5, 2]))[2] == 1,
  );

  check('old JSON payload is rejected',
      decodeWaveformBars(Uint8List.fromList(utf8.encode('[0.1,0.2]'))).isEmpty);
  check('truncated payload is rejected',
      decodeWaveformBars(encoded.sublist(0, encoded.length - 4)).isEmpty);
  check('empty payload is rejected', decodeWaveformBars(Uint8List(0)).isEmpty);
}

/// The waveform cache file is staged then renamed, and an entry that is not a
/// whole waveform is never read (or written) as one.
void _checkWaveformFiles() {
  final dir = Directory.systemTemp.createTempSync('wispie_waveform_probe_');
  try {
    final bars = _probeBars();
    final path =
        p.join(dir.path, 'waveforms', '${waveformCachePrefix}probe.wfm');

    check('a complete waveform is written', writeWaveformCacheFile(path, bars));
    check('a written waveform reads back whole',
        readWaveformCacheFile(path)?.length == waveformBarCount);
    check('a write leaves no staging file',
        !File('$path$cacheStagingSuffix').existsSync());

    final before = File(path).readAsBytesSync();
    check('an incomplete waveform is refused',
        !writeWaveformCacheFile(path, bars.sublist(0, 400)));
    check(
      'a refused write leaves the previous entry intact',
      _sameBytes(File(path).readAsBytesSync(), before),
    );

    final replacement = List<double>.filled(waveformBarCount, 1.0);
    check(
      'a rewrite replaces the entry in one step',
      writeWaveformCacheFile(path, replacement) &&
          readWaveformCacheFile(path)!.every((v) => v == 1),
    );

    final truncated = File(p.join(dir.path, 'truncated.wfm'))
      ..writeAsBytesSync(encodeWaveformBars(bars).sublist(0, 120));
    check('a truncated entry is rejected',
        readWaveformCacheFile(truncated.path) == null);

    final short = File(p.join(dir.path, 'short.wfm'))
      ..writeAsBytesSync(encodeWaveformBars(bars.sublist(0, 900)));
    check('an entry with too few bars is rejected',
        readWaveformCacheFile(short.path) == null);

    final retired = File(p.join(dir.path, 'retired.wfm'))
      ..writeAsStringSync('[0.1,0.2,0.3]');
    check('a retired JSON entry is rejected',
        readWaveformCacheFile(retired.path) == null);

    check('a staging leftover is not read as a waveform',
        readWaveformCacheFile('$path$cacheStagingSuffix') == null);
    check('a missing entry reads as null',
        readWaveformCacheFile(p.join(dir.path, 'absent.wfm')) == null);

    final emptied = File(p.join(dir.path, 'empty.wfm'))
      ..writeAsBytesSync(Uint8List(0));
    check('an emptied waveform is rejected',
        readWaveformCacheFile(emptied.path) == null);
  } finally {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

void _checkNames() {
  check(
    'waveform names are versioned and stable',
    waveformCacheName('a.flac') == waveformCacheName('a.flac') &&
        waveformCacheName('a.flac').startsWith('waveform_v3_') &&
        waveformCacheName('a.flac').endsWith('.wfm'),
    detail: waveformCacheName('a.flac'),
  );
  check('waveform names differ per song',
      waveformCacheName('a.flac') != waveformCacheName('b.flac'));
  check(
    'beat map and blur names differ per song',
    beatMapCacheName('a') != beatMapCacheName('b') &&
        blurredCacheName('a') != blurredCacheName('b'),
  );
  check(
    'lyrics names differ per field',
    {
          songLyricsCacheName('a'),
          richLyricsCacheName('a'),
          remoteLyricsCacheName('a'),
        }.length ==
        3,
  );
  check(
    'notification keys are filesystem safe',
    notificationCoverKey('/tmp/covers/c_0123 ab.jpg') == 'c_0123_ab_jpg',
    detail: notificationCoverKey('/tmp/covers/c_0123 ab.jpg'),
  );
  check(
    'notification key is never empty or a path',
    notificationCoverKey('') == 'cover' &&
        ['...', '??', ' a ', 'x/y'].every((key) {
          final value = notificationCoverKey(key);
          return value.isNotEmpty && !value.contains('/');
        }),
  );
}

void _checkBuckets() {
  check('covers are never size-evicted',
      !CacheBucket.covers.isEvictable && CacheBucket.covers.budgetBytes == 0);
  check(
    'every evictable bucket has a budget',
    CacheBucket.values
        .where((b) => b.isEvictable)
        .every((b) => b.budgetBytes >= 16 * 1024 * 1024),
    detail: [
      for (final bucket in CacheBucket.values)
        '${bucket.name}:${bucket.budgetBytes}',
    ],
  );
  final totalBudget = CacheBucket.values
      .fold<int>(0, (sum, bucket) => sum + bucket.budgetBytes);
  check('total budget stays under 2 GiB', totalBudget <= 2 * 1024 * 1024 * 1024,
      detail: totalBudget);
  check('scratch buckets are scratch',
      CacheBucket.scratch.isScratch && CacheBucket.iosProxies.isScratch);
  check('palettes survive eviction',
      CacheBucket.palettes.retention == CacheRetention.permanent);
}

void _checkGate() {
  check('a fresh install runs the layout migration',
      needsCacheLayoutMigration(null));
  check('an older layout version still migrates',
      needsCacheLayoutMigration(cacheLayoutVersion - 1));
  check(
    'an already-migrated install skips the pass',
    !needsCacheLayoutMigration(cacheLayoutVersion) &&
        !needsCacheLayoutMigration(cacheLayoutVersion + 1),
  );
}

Future<void> _checkMigration() async {
  final sandbox = await Directory.systemTemp.createTemp('wispie_cache_probe_');
  try {
    final support = Directory(p.join(sandbox.path, 'support'));
    final legacy = Directory(p.join(support.path, 'gru_cache_v3'));
    final palettesJson = jsonEncode({'version': 2, 'entries': {}});

    Future<void> write(String relative, String content) async {
      final file = File(p.join(legacy.path, relative));
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    }

    await write('blurred_cache/b1.jpg', 'blur');
    await write('blurred_cache/nested/b2.jpg', 'blur');
    await write('notification_cover_cache/n1.jpg', 'notif');
    await write('lyrics_cache/remote_a.lrc', 'lyrics');
    await write('lyrics_cache/rich_a.json', '{}');
    await write('lyrics_cache/hash.json', '{}');
    await write('waveform_v2_abc.json', '[0.5,0.5]');
    await write('beatmap_abc.json', '{}');
    await write('ios_media_proxy/proxy.mp4', 'proxy');
    await write('youtube_abc.json', '{}');
    await write('unknown_thing.bin', 'junk');

    await File(p.join(support.path, 'palette_cache.json'))
        .writeAsString(palettesJson);
    await File(p.join(support.path, 'youtube_feed.json')).writeAsString('{}');
    await Directory(p.join(support.path, 'artwork_cache'))
        .create(recursive: true);
    await File(p.join(support.path, 'artwork_cache', 'art_1.img'))
        .writeAsString('art');
    await Directory(p.join(support.path, 'palettes')).create(recursive: true);
    await Directory(p.join(support.path, 'waveform_temp'))
        .create(recursive: true);
    await File(p.join(support.path, 'waveform_temp', 'junk.raw'))
        .writeAsString('raw');
    await Directory(p.join(support.path, 'beat_analysis_temp'))
        .create(recursive: true);

    final root = p.join(support.path, 'wispie_cache');
    final waveformDir = Directory(p.join(root, 'waveforms'));
    await waveformDir.create(recursive: true);
    final keptWaveform = p.join(waveformDir.path, 'waveform_v3_keep.wfm');
    await File(keptWaveform).writeAsString('keep');
    final stagedWaveform =
        p.join(waveformDir.path, 'waveform_v3_x.wfm$cacheStagingSuffix');
    await File(stagedWaveform).writeAsString('partial');

    final result = await migrateLegacyCacheLayout(
      supportPath: support.path,
      cacheRootPath: root,
    );

    bool exists(String relative) => File(p.join(root, relative)).existsSync();

    check('migration reports the legacy layout', result.legacyFound,
        detail: result);
    check('a clean pass reports no failures', result.complete, detail: result);
    check('blurred backdrops move into their bucket',
        exists('blurred/b1.jpg') && exists('blurred/nested/b2.jpg'));
    check('notification art moves into its bucket',
        exists('notification/n1.jpg'));
    check(
      'every lyrics file moves into the lyrics bucket',
      exists('lyrics/remote_a.lrc') &&
          exists('lyrics/rich_a.json') &&
          exists('lyrics/hash.json'),
    );
    check('beat maps move into their bucket',
        exists('beatmaps/beatmap_abc.json'));
    check('cached pages move into their bucket',
        exists('youtube/youtube_abc.json') && exists('youtube/feed.json'));
    check('downloaded artwork moves into its bucket',
        exists('remote_art/art_1.img'));
    check(
      'the palette index moves and keeps its version',
      exists('palettes/palettes.json') &&
          File(p.join(root, 'palettes/palettes.json')).readAsStringSync() ==
              palettesJson,
    );
    check('retired JSON waveforms are dropped',
        !exists('waveforms/waveform_v2_abc.json') && result.dropped >= 1,
        detail: result.dropped);
    check(
        'a usable waveform survives the pass', File(keptWaveform).existsSync());
    check('an interrupted write is cleaned out',
        !File(stagedWaveform).existsSync());
    check(
      'the legacy tree is gone',
      !legacy.existsSync() &&
          !Directory(p.join(support.path, 'artwork_cache')).existsSync() &&
          !Directory(p.join(support.path, 'palettes')).existsSync() &&
          !Directory(p.join(support.path, 'waveform_temp')).existsSync() &&
          !Directory(p.join(support.path, 'beat_analysis_temp')).existsSync() &&
          !File(p.join(support.path, 'palette_cache.json')).existsSync() &&
          !File(p.join(support.path, 'youtube_feed.json')).existsSync(),
    );
    check(
        'scratch proxies are not carried over',
        !Directory(p.join(root, 'proxies')).existsSync() ||
            Directory(p.join(root, 'proxies')).listSync().isEmpty);

    final second = await migrateLegacyCacheLayout(
      supportPath: support.path,
      cacheRootPath: root,
    );
    check(
      'a second launch migrates nothing and loses nothing',
      !second.legacyFound &&
          second.complete &&
          exists('blurred/b1.jpg') &&
          exists('lyrics/rich_a.json'),
      detail: second,
    );

    // A move that cannot finish must keep its source and ask for a retry.
    final blockedSupport = Directory(p.join(sandbox.path, 'blocked_support'));
    final blockedLegacy = Directory(
      p.join(blockedSupport.path, 'gru_cache_v3', 'lyrics_cache'),
    );
    await blockedLegacy.create(recursive: true);
    final stuckFile = File(p.join(blockedLegacy.path, 'stuck.json'));
    await stuckFile.writeAsString('{}');
    final blockedRoot = p.join(blockedSupport.path, 'wispie_cache');
    final blocker = Directory(p.join(blockedRoot, 'lyrics', 'stuck.json'));
    await blocker.create(recursive: true);

    final blocked = await migrateLegacyCacheLayout(
      supportPath: blockedSupport.path,
      cacheRootPath: blockedRoot,
    );
    check('a failed move is reported', blocked.failed > 0 && !blocked.complete,
        detail: blocked);
    check('a failed move keeps its source file', stuckFile.existsSync());
    check('a failed move keeps the legacy tree',
        Directory(p.join(blockedSupport.path, 'gru_cache_v3')).existsSync());

    await blocker.delete(recursive: true);
    final retried = await migrateLegacyCacheLayout(
      supportPath: blockedSupport.path,
      cacheRootPath: blockedRoot,
    );
    check(
      'the retry finishes what the failed pass could not',
      retried.complete &&
          !Directory(p.join(blockedSupport.path, 'gru_cache_v3'))
              .existsSync() &&
          File(p.join(blockedRoot, 'lyrics', 'stuck.json')).existsSync(),
      detail: retried,
    );
  } finally {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  }
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

double _maxError(List<double> expected, List<double> actual) {
  var worst = 0.0;
  for (var i = 0; i < expected.length && i < actual.length; i++) {
    final delta = (expected[i] - actual[i]).abs();
    if (delta > worst) worst = delta;
  }
  return worst;
}
