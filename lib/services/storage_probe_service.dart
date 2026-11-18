import 'dart:isolate';

import '../domain/services/media_formats.dart';
import '../domain/services/native_accel.dart';

/// Outcome of probing one music folder before a full scan.
class FolderProbe {
  final String path;
  final bool folderExists;
  final bool listed;
  final String? listError;
  final int filesFound;
  final int filesSampled;
  final int filesReadable;
  final String? readError;

  const FolderProbe({
    required this.path,
    required this.folderExists,
    required this.listed,
    this.listError,
    required this.filesFound,
    required this.filesSampled,
    required this.filesReadable,
    this.readError,
  });

  bool get fullyReadable =>
      listed &&
      filesFound > 0 &&
      filesSampled > 0 &&
      filesReadable == filesSampled;

  bool get nothingReadable =>
      listed && filesFound > 0 && filesSampled > 0 && filesReadable == 0;

  Map<String, String> toMap() => {
        'path': path,
        'exists': folderExists.toString(),
        'listed': listed.toString(),
        if (listError != null) 'listError': listError!,
        'filesFound': filesFound.toString(),
        'sampled': filesSampled.toString(),
        'readable': filesReadable.toString(),
        if (readError != null) 'readError': readError!,
      };
}

/// Lightweight pre-scan check: can we list this folder and actually read bytes
/// from a few files? Distinguishes "empty folder" from "permission denied",
/// which a bare file count cannot.
///
/// The walk runs in the native core; this only maps its reply.
class StorageProbeService {
  /// Same list the scanner indexes by, so a folder cannot probe clean and then
  /// scan empty (or the reverse).
  static bool isSupportedMediaPath(String path) =>
      MediaFormats.isSupportedPath(path);

  Future<FolderProbe> probeFolder(String path) async {
    // Off the UI isolate: the walk and the sample reads are blocking file I/O.
    final reply = await Isolate.run(() => NativeAccel.storageProbe(path));
    return FolderProbe(
      path: reply['path'] as String? ?? path,
      folderExists: reply['exists'] == true,
      listed: reply['listed'] == true,
      listError: reply['listError'] as String?,
      filesFound: (reply['filesFound'] as num?)?.toInt() ?? 0,
      filesSampled: (reply['sampled'] as num?)?.toInt() ?? 0,
      filesReadable: (reply['readable'] as num?)?.toInt() ?? 0,
      readError: reply['readError'] as String?,
    );
  }
}
