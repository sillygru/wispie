// SPDX-License-Identifier: GPL-3.0-only
import 'dart:convert';
import 'dart:io';
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

/// Bars every cached waveform holds. Fewer means a decode that ended early or
/// a file that was cut short, so both are treated as missing and rebuilt.
const int waveformBarCount = 2000;

/// Suffix of a cache file that is still being replaced.
const String cacheStagingSuffix = '.part';

/// True for a file this build can read as a waveform.
bool isWaveformCacheFileName(String name) =>
    name.startsWith(waveformCachePrefix) &&
    name.endsWith(waveformCacheExtension);

/// True for the JSON waveform entries the binary format replaced.
bool isRetiredWaveformCacheName(String name) =>
    name.startsWith('waveform_') && name.endsWith('.json');

bool isCompleteWaveformBars(List<double> bars) =>
    bars.length >= waveformBarCount;

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

/// Writes [samples] as the waveform at [path], refusing an incomplete list.
/// Staged then renamed, so a reader never sees a truncated entry.
bool writeWaveformCacheFile(String path, List<double> samples) {
  if (!isCompleteWaveformBars(samples)) return false;

  final target = File(path);
  final staging = File('$path$cacheStagingSuffix');
  final bytes = encodeWaveformBars(samples);
  try {
    target.parent.createSync(recursive: true);
    // A leftover from an interrupted write would otherwise be appended to.
    if (staging.existsSync()) staging.deleteSync();
    staging.writeAsBytesSync(bytes, flush: true);
    if (staging.lengthSync() != bytes.length) {
      staging.deleteSync();
      return false;
    }
    _replaceWithStaging(staging, target);
    return true;
  } on Object {
    try {
      if (staging.existsSync()) staging.deleteSync();
    } on Object {
      // The next sweep drops a staging file that will not delete.
    }
    return false;
  }
}

/// Renames [staging] over [target]. Windows refuses to replace an existing file
/// with a rename, so an old copy is removed first there and nowhere else.
void _replaceWithStaging(File staging, File target) {
  try {
    staging.renameSync(target.path);
    return;
  } on FileSystemException {
    if (target.existsSync()) target.deleteSync();
  }
  staging.renameSync(target.path);
}

/// Bars from the cache file at [path], or null when it is missing, retired or
/// truncated, which makes the caller decode again and repair the entry.
List<double>? readWaveformCacheFile(String path) {
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    final bars = decodeWaveformBars(file.readAsBytesSync());
    return isCompleteWaveformBars(bars) ? bars : null;
  } on Object {
    return null;
  }
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
