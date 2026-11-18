/// The single place that decides whether a stored cover URL points at artwork
/// this process can read, and what rendition to download.
///
/// The rules (which schemes are local, which YouTube/CDN URL carries which
/// size) live in the native core. The small result cache here is an adapter
/// detail: artwork tiles rebuild while scrolling, and the same URL is asked for
/// many times per second.
library;

import '../../data/rust/wispie_core.dart';

class CoverPath {
  const CoverPath._();

  static const int _cacheLimit = 512;
  static final Map<String, String?> _sharperCache = {};
  static final Map<String, String?> _renditionCache = {};
  static final Map<String, String> _normalizeCache = {};

  /// True when [value] names local artwork: a plain path, a Windows path, a
  /// `file://` URI or a `content://` MediaStore URI.
  static bool isLocal(String? value) {
    if (value == null) return false;
    return WispieCore.coverPath(value, wanted: 0, mode: 3) == '1';
  }

  /// Strips a `file://` scheme so the result can be handed to `File`.
  static String normalize(String value) {
    final hit = _normalizeCache[value];
    if (hit != null) return hit;
    final result = WispieCore.coverPath(value, wanted: 0, mode: 2) ?? value;
    if (_normalizeCache.length >= _cacheLimit) _normalizeCache.clear();
    _normalizeCache[value] = result;
    return result;
  }

  /// A rendition of a remote thumbnail suited to [wanted] device pixels on a
  /// side, or null when the URL names no size or is already big enough.
  static String? sharperUrl(String url, {int wanted = 720}) =>
      _cached(_sharperCache, '$wanted|$url', () {
        final value = WispieCore.coverPath(url, wanted: wanted, mode: 0);
        return value;
      });

  /// The YouTube still rendition that is just big enough for [wanted] device
  /// pixels, rounded down as well as up.
  static String? renditionUrl(String url, {int wanted = 320}) =>
      _cached(_renditionCache, '$wanted|$url', () {
        return WispieCore.coverPath(url, wanted: wanted, mode: 1);
      });

  /// [isLocal] narrowed to paths that can be opened as a `File`.
  static String? toLocalPath(String? value) {
    if (value == null) return null;
    return WispieCore.coverPath(value, wanted: 0, mode: 4);
  }

  static String? _cached(
    Map<String, String?> cache,
    String key,
    String? Function() compute,
  ) {
    if (cache.containsKey(key)) return cache[key];
    final result = compute();
    if (cache.length >= _cacheLimit) cache.clear();
    cache[key] = result;
    return result;
  }
}
