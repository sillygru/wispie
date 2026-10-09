import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Fractional insets of baked-in black bars around a cover's artwork.
class CoverTrim {
  final double left, top, right, bottom;

  /// Source width / height, so the crop fractions map onto the real image.
  final double aspect;

  const CoverTrim(this.left, this.top, this.right, this.bottom,
      [this.aspect = 1]);

  static const none = CoverTrim(0, 0, 0, 0);

  bool get isNone => left + top + right + bottom == 0;
}

/// Hides letterbox/pillarbox bars baked into cover files, so list thumbnails
/// match the auto-fit look without rewriting any metadata.
///
/// Detection decodes a 64px-wide copy on the engine's decode thread and is
/// memoized per path, so each cover is analysed at most once per session.
class CoverBorderTrim extends StatefulWidget {
  final String path;
  final double? width;
  final double? height;
  final Widget child;

  const CoverBorderTrim({
    super.key,
    required this.path,
    required this.child,
    this.width,
    this.height,
  });

  static final Map<String, CoverTrim> _cache = {};
  static final Map<String, Future<CoverTrim>> _pending = {};
  static final Queue<Completer<void>> _waiters = Queue();
  static int _active = 0;
  static const int _maxConcurrent = 2;
  static const int _sampleWidth = 64;
  static const int _darkThreshold = 45;

  /// Drops the memoized result after the cover file at [path] is replaced.
  static void forget(String path) => _cache.remove(path);

  static Future<CoverTrim> _resolve(String path) {
    final cached = _cache[path];
    if (cached != null) return SynchronousFuture(cached);
    return _pending[path] ??= _analyse(path).then((t) {
      _cache[path] = t;
      return t;
    }).whenComplete(() => _pending.remove(path));
  }

  static Future<CoverTrim> _analyse(String path) async {
    if (_active >= _maxConcurrent) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _active++;
    try {
      final bytes = await File(path).readAsBytes();
      final codec =
          await ui.instantiateImageCodec(bytes, targetWidth: _sampleWidth);
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      final w = image.width, h = image.height;
      final data = await image.toByteData();
      image.dispose();
      if (data == null || w == 0 || h == 0) return CoverTrim.none;
      return _detect(data, w, h);
    } catch (_) {
      return CoverTrim.none;
    } finally {
      _active--;
      if (_waiters.isNotEmpty) _waiters.removeFirst().complete();
    }
  }

  static CoverTrim _detect(ByteData data, int w, int h) {
    bool lit(int x, int y) {
      final i = (y * w + x) * 4;
      return data.getUint8(i) > _darkThreshold ||
          data.getUint8(i + 1) > _darkThreshold ||
          data.getUint8(i + 2) > _darkThreshold;
    }

    var minX = w, minY = h, maxX = -1, maxY = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!lit(x, y)) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < 0) return CoverTrim.none;

    final l = minX / w, r = (w - 1 - maxX) / w;
    final t = minY / h, b = (h - 1 - maxY) / h;
    // Only trim clean bars on one axis: a dark cover with a small bright
    // motif has insets on every side and must be left alone.
    const bar = 0.03, flush = 0.02;
    if (l >= bar && r >= bar && t <= flush && b <= flush) {
      return CoverTrim(l, 0, r, 0, w / h);
    }
    if (t >= bar && b >= bar && l <= flush && r <= flush) {
      return CoverTrim(0, t, 0, b, w / h);
    }
    return CoverTrim.none;
  }

  @override
  State<CoverBorderTrim> createState() => _CoverBorderTrimState();
}

class _CoverBorderTrimState extends State<CoverBorderTrim> {
  CoverTrim? _trim;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CoverBorderTrim oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  void _load() {
    final path = widget.path;
    _trim = CoverBorderTrim._cache[path];
    if (_trim != null) return;
    CoverBorderTrim._resolve(path).then((t) {
      if (mounted && widget.path == path && !t.isNone) {
        setState(() => _trim = t);
      }
    });
  }

  static double _align(double a, double b) =>
      a + b == 0 ? 0 : 2 * a / (a + b) - 1;

  @override
  Widget build(BuildContext context) {
    final t = _trim;
    if (t == null || t.isNone) return widget.child;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: ClipRect(
            child: Align(
              alignment:
                  Alignment(_align(t.left, t.right), _align(t.top, t.bottom)),
              widthFactor: 1 - t.left - t.right,
              heightFactor: 1 - t.top - t.bottom,
              // Unit box; the image fills it, so factors map to image fractions.
              child: SizedBox(
                width: 100 * t.aspect,
                height: 100,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
