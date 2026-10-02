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
