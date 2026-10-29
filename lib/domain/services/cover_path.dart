/// The single place that decides whether a stored cover URL points at
/// artwork this process can read, and what filesystem path it resolves to.
///
/// Cover URLs reach the UI from several sources — extracted files in the
/// covers cache, `file://` URIs, Android MediaStore `content://` rows and
/// occasionally remote URLs — and each consumer used to re-derive the same
/// prefix checks and `Uri.parse().toFilePath()` dance.
class CoverPath {
  const CoverPath._();

  /// True when [value] names local artwork: a plain path, a Windows path, a
  /// `file://` URI or a `content://` MediaStore URI.
  static bool isLocal(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    return trimmed.startsWith('/') ||
        trimmed.startsWith('C:\\') ||
        trimmed.startsWith('file://') ||
        trimmed.startsWith('content://');
  }

  /// Strips a `file://` scheme so the result can be handed to `File`.
  /// Unparseable URIs are returned untouched, matching what the per-widget
  /// resolvers did before this class existed.
  static String normalize(String value) {
    if (!value.toLowerCase().startsWith('file://')) return value;
    try {
      return Uri.parse(value).toFilePath();
    } on FormatException {
      return value;
    } on UnsupportedError {
      return value;
    }
  }

  /// A rendition of a remote thumbnail suited to [wanted] device pixels on a
  /// side, or null when the URL names no size or is already big enough.
  ///
  /// YouTube stills come in fixed names: `mqdefault`, `hqdefault`, `sddefault`
  /// and `maxresdefault` are one frame at 320, 480, 640 and 1280 wide, so the
  /// nearest name at or above [wanted] is the sharpest one worth downloading. A
  /// 52px list row has no use for a 1280px still, and a full-size player cover
  /// has nothing to gain from a 320px one. Google's CDNs (`yt3`, `lh3`) take the
  /// size as a `=wN-hN` / `=sN` suffix instead, which the catalogue's own
  /// thumbnails use.
  static String? sharperUrl(String url, {int wanted = 720}) {
    final still = RegExp(
      r'^https?://i\.ytimg\.com/vi/([A-Za-z0-9_-]+)/(mq|hq|sd|maxres)default(\.\w+)(\?.*)?$',
    ).firstMatch(url);
    if (still != null) {
      const ladder = ['mq', 'hq', 'sd', 'maxres'];
      final current = ladder.indexOf(still.group(2) ?? 'mq');
      final target = wanted <= 320
          ? 0
          : wanted <= 480
              ? 1
              : wanted <= 640
                  ? 2
                  : 3;
      if (target <= current) return null;
      return 'https://i.ytimg.com/vi/${still.group(1)}/'
          '${ladder[target]}default${still.group(3)}${still.group(4) ?? ''}';
    }

    final target = wanted.clamp(120, 720);
    final boxed = RegExp(r'=w(\d+)-h(\d+)').firstMatch(url);
    if (boxed != null) {
      final width = int.tryParse(boxed.group(1) ?? '') ?? 0;
      if (width >= target) return null;
      return url.replaceRange(boxed.start, boxed.end, '=w$target-h$target');
    }

    final square = RegExp(r'=s(\d+)(?=-|$)').firstMatch(url);
    if (square != null) {
      final size = int.tryParse(square.group(1) ?? '') ?? 0;
      if (size >= target) return null;
      return url.replaceRange(square.start, square.end, '=s$target');
    }
    return null;
  }

  /// The YouTube still rendition that is just big enough for [wanted] device
  /// pixels, rounded **down** as well as up.
  ///
  /// [sharperUrl] only ever upgrades, which is right when a list row was handed
  /// a 480px still: it should not pay for 1280. This is the other half of that
  /// bargain — a row handed a 480px still for a 156px box downloads the 320px
  /// one instead. Anything that is not a sized still returns null.
  static String? renditionUrl(String url, {int wanted = 320}) {
    final still = RegExp(
      r'^https?://i\.ytimg\.com/vi/([A-Za-z0-9_-]+)/(mq|hq|sd|maxres)default(\.\w+)(\?.*)?$',
    ).firstMatch(url);
    if (still == null) return sharperUrl(url, wanted: wanted);

    const ladder = ['mq', 'hq', 'sd', 'maxres'];
    final int target = wanted <= 320
        ? 0
        : wanted <= 480
            ? 1
            : wanted <= 640
                ? 2
                : 3;
    final current = ladder.indexOf(still.group(2) ?? 'mq');
    if (current == target) return null;
    return 'https://i.ytimg.com/vi/${still.group(1)}/'
        '${ladder[target]}default${still.group(3)}${still.group(4) ?? ''}';
  }

  /// [isLocal] narrowed to paths that can be opened as a `File`, with any
  /// `file://` scheme stripped. Null for remote URLs and for `content://`
  /// URIs, which have no filesystem path.
  static String? toLocalPath(String? value) {
    if (!isLocal(value)) return null;
    final trimmed = value!.trim();
    if (trimmed.startsWith('content://')) return null;
    return normalize(trimmed);
  }
}
