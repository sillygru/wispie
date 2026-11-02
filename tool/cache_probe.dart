// SPDX-License-Identifier: GPL-3.0-only
//
// Probe for the wispie cache: file naming, budgets, the binary waveform format
// and the migration off the old `gru_cache_v3` layout.
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

void _checkWaveforms() {
  final bars = List<double>.generate(
    2000,
    (i) => (0.5 + 0.5 * math.sin(i / 12)).clamp(0.0, 1.0),
  );
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
    await write('notification_cover_cache/n1.jpg', 'notif');
    await write('lyrics_cache/remote_a.lrc', 'lyrics');
    await write('lyrics_cache/rich_a.json', '{}');
    await write('lyrics_cache/hash.json', '{}');
    await write('waveform_v2_abc.json', '[0.5,0.5]');
    await write('beatmap_abc.json', '{}');
    await write('ios_media_proxy/proxy.mp4', 'proxy');
    await write('youtube_abc.json', '{}');

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
    final result = await migrateLegacyCacheLayout(
      supportPath: support.path,
      cacheRootPath: root,
    );

    bool exists(String relative) => File(p.join(root, relative)).existsSync();

    check('migration reports the legacy layout', result.legacyFound,
        detail: result.moved);
    check('blurred backdrops move into their bucket', exists('blurred/b1.jpg'));
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
          exists('blurred/b1.jpg') &&
          exists('lyrics/rich_a.json'),
      detail: second.moved,
    );
  } finally {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  }
}

double _maxError(List<double> expected, List<double> actual) {
  var worst = 0.0;
  for (var i = 0; i < expected.length && i < actual.length; i++) {
    final delta = (expected[i] - actual[i]).abs();
    if (delta > worst) worst = delta;
  }
  return worst;
}
