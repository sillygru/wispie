import 'package:path/path.dart' as p;

/// Which files the app treats as playable media.
///
/// One list, in the pure layer, because three different readers ask this
/// question — the scanner that builds the library, the pre-scan storage probe,
/// and the folder reader that compares a folder against the library — and a
/// file that one of them recognises as a song and another does not is a bug
/// with no visible cause.
class MediaFormats {
  const MediaFormats._();

  static const Set<String> supported = {
    '.mp3',
    '.m4a',
    '.wav',
    '.flac',
    '.ogg',
    '.wma',
    '.aac',
    '.m4b',
    '.mp4',
    '.opus',
    '.m4v',
    '.mov',
    '.mkv',
    '.webm',
    '.avi',
    '.3gp',
  };

  /// Whether [path] is a media file the app would index.
  static bool isSupportedPath(String path) =>
      supported.contains(p.extension(path).toLowerCase());
}
