// SPDX-License-Identifier: GPL-3.0-only
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const int _mib = 1024 * 1024;

/// How a bucket reacts to age and size pressure.
enum CacheRetention {
  /// Tiny and expensive to rebuild; only an explicit clear removes it.
  permanent,

  /// Rebuildable; trimmed least-recently-used when over budget.
  evictable,

  /// Only meaningful within one run; wiped on launch.
  scratch,
}

/// The distinct stores the app writes under its cache root.
///
/// Budgets are per bucket, so one runaway kind of file (covers, streamed audio)
/// can never push everything else out.
enum CacheBucket {
  /// Library-referenced, so it is pruned with the library rather than by size.
  covers('covers', CacheRetention.permanent, 0),
  remoteArt('remote_art', CacheRetention.evictable, 96 * _mib),
  blurred('blurred', CacheRetention.evictable, 128 * _mib),
  notification('notification', CacheRetention.evictable, 32 * _mib),
  waveforms('waveforms', CacheRetention.evictable, 64 * _mib),
  beatMaps('beatmaps', CacheRetention.evictable, 64 * _mib),
  lyrics('lyrics', CacheRetention.evictable, 32 * _mib),
  palettes('palettes', CacheRetention.permanent, 0),
  youtube('youtube', CacheRetention.evictable, 32 * _mib),
  iosProxies('proxies', CacheRetention.scratch, 0),
  scratch('temp', CacheRetention.scratch, 0),
  onlineAudio('online_audio', CacheRetention.evictable, 1024 * _mib);

  const CacheBucket(this.dirName, this.retention, this.budgetBytes);

  final String dirName;
  final CacheRetention retention;
  final int budgetBytes;

  bool get isScratch => retention == CacheRetention.scratch;
  bool get isEvictable => retention == CacheRetention.evictable;
}

/// Stable hash behind every cache file name.
String cacheKeyFor(String value) => sha1.convert(utf8.encode(value)).toString();

/// Versioned so a change to how bars are produced invalidates every entry.
const String waveformCachePrefix = 'waveform_v3_';
const String waveformCacheExtension = '.wfm';

String waveformCacheName(String songFilename) =>
    '$waveformCachePrefix${cacheKeyFor(songFilename)}$waveformCacheExtension';

String beatMapCacheName(String songFilename) =>
    'beatmap_${cacheKeyFor(songFilename)}.json';

String blurredCacheName(String songFilename) =>
    'blurred_${cacheKeyFor(songFilename)}.jpg';

/// Key for a notification cover: derived from the cover file's name.
String notificationCoverKey(String coverPath) {
  final base = coverPath.split('/').last.split('\\').last;
  final sanitized = base.replaceAll(RegExp(r'[^\w\-]'), '_');
  if (sanitized.isEmpty || sanitized == '_') return 'cover';
  return sanitized;
}

String notificationCoverName(String coverPath) =>
    '${notificationCoverKey(coverPath)}.jpg';

String remoteLyricsCacheName(String filename) =>
    'remote_${cacheKeyFor(filename)}.lrc';

String richLyricsCacheName(String filename) =>
    'rich_${cacheKeyFor(filename)}.json';

String songLyricsCacheName(String url) => '${cacheKeyFor(url)}.json';

const String paletteIndexName = 'palettes.json';

String remoteArtCacheName(String url) => 'art_${cacheKeyFor(url)}.img';

/// Bars are stored as 8-bit heights: 2000 bars cost 2 KB instead of the ~36 KB
/// a JSON double list took, and they still look identical at bar width.
const List<int> waveformMagic = [0x57, 0x53, 0x50, 0x33];

/// Hard cap so a corrupt header cannot make us allocate wildly.
const int waveformBarLimit = 8192;

Uint8List encodeWaveformBars(List<double> bars) {
  final count = bars.length > waveformBarLimit ? waveformBarLimit : bars.length;
  final out = Uint8List(6 + count);
  out.setRange(0, 4, waveformMagic);
  out[4] = count & 0xff;
  out[5] = (count >> 8) & 0xff;
  for (var i = 0; i < count; i++) {
    final value = bars[i];
    if (value.isNaN || value <= 0) continue;
    out[6 + i] = value >= 1 ? 255 : (value * 255).round();
  }
  return out;
}

/// Empty when the bytes are not a current-format waveform, so callers fall back
/// to decoding the audio instead of drawing garbage.
List<double> decodeWaveformBars(Uint8List bytes) {
  if (bytes.length < 6) return const [];
  for (var i = 0; i < 4; i++) {
    if (bytes[i] != waveformMagic[i]) return const [];
  }
  final count = bytes[4] | (bytes[5] << 8);
  if (count == 0 || bytes.length < 6 + count) return const [];
  final bars = List<double>.filled(count, 0);
  for (var i = 0; i < count; i++) {
    bars[i] = bytes[6 + i] / 255;
  }
  return bars;
}

/// File and byte counts for one [CacheBucket].
class CacheBucketUsage {
  const CacheBucketUsage({required this.files, required this.bytes});

  final int files;
  final int bytes;

  static const empty = CacheBucketUsage(files: 0, bytes: 0);
}

/// One consistent snapshot of everything on disk.
class CacheUsage {
  const CacheUsage(this.buckets);

  final Map<CacheBucket, CacheBucketUsage> buckets;

  static const empty = CacheUsage(<CacheBucket, CacheBucketUsage>{});

  int bytesOf(CacheBucket bucket) => buckets[bucket]?.bytes ?? 0;
  int filesOf(CacheBucket bucket) => buckets[bucket]?.files ?? 0;

  int get totalBytes =>
      buckets.values.fold(0, (sum, usage) => sum + usage.bytes);

  int get totalFiles =>
      buckets.values.fold(0, (sum, usage) => sum + usage.files);
}

/// Outcome of a maintenance sweep.
class CacheMaintenanceReport {
  const CacheMaintenanceReport({
    this.orphansDeleted = 0,
    this.evictedFiles = 0,
    this.reclaimedBytes = 0,
    this.legacyCleaned = false,
  });

  final int orphansDeleted;
  final int evictedFiles;
  final int reclaimedBytes;
  final bool legacyCleaned;

  int get deletedFiles => orphansDeleted + evictedFiles;
  bool get freedAnything => reclaimedBytes > 0;
}
