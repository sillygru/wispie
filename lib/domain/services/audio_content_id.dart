import 'dart:convert';

import '../../data/rust/wispie_core.dart';

/// A content id names the audio of a file, not its name, tags, cover art or
/// container padding. Two files with the same id carry the same encoded audio,
/// so it survives renames, moves, retagging and copies between devices.
///
/// Format: `<kind>:<32 hex chars>`, derived by the native core from the
/// container's own audio region (FLAC STREAMINFO MD5, MP3 frame region, MP4
/// `mdat`, Ogg page bodies, WAV/AIFF data chunks, or the whole file).
String? computeContentIdSync(String path) =>
    probeFilesSync([path], {path}).first.contentId;

Future<String?> computeContentId(String path) async =>
    computeContentIdSync(path);

/// Result of probing one file on disk.
class FileProbe {
  final String path;
  final bool exists;
  final double? mtime;
  final String? contentId;
  const FileProbe(this.path, this.exists, this.mtime, this.contentId);
}

/// Stats every path and hashes those in [hashPaths]. Runs inside an isolate.
List<FileProbe> probeFilesSync(List<String> paths, Set<String> hashPaths) {
  Map<String, dynamic>? reply;
  final code = WispieCore.run(
    {
      'command': 'content_ids',
      'paths': paths,
      'hashPaths': hashPaths.toList(growable: false),
    },
    onEvent: (kind, payload) {
      if (kind == WispieCore.eventItems) {
        reply = jsonDecode(payload) as Map<String, dynamic>;
      }
    },
  );
  if (code != 0 || reply == null) {
    throw StateError('content id probe failed ($code)');
  }
  return [
    for (final row in reply!['files'] as List)
      FileProbe(
        (row as Map<String, dynamic>)['path'] as String,
        row['exists'] as bool,
        (row['mtime'] as num?)?.toDouble(),
        row['contentId'] as String?,
      ),
  ];
}

Future<List<FileProbe>> probeFiles(
        List<String> paths, Set<String> hashPaths) async =>
    probeFilesSync(paths, hashPaths);
