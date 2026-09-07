import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

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
class StorageProbeService {
  static const int _listCap = 40;
  static const int _readSampleSize = 5;

  static const Set<String> _supportedExtensions = {
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

  static bool isSupportedMediaPath(String path) =>
      _supportedExtensions.contains(p.extension(path).toLowerCase());

  Future<FolderProbe> probeFolder(String path) async {
    final dir = Directory(path);
    bool exists = false;
    try {
      exists = await dir.exists();
    } on FileSystemException catch (e) {
      return FolderProbe(
        path: path,
        folderExists: false,
        listed: false,
        listError: '${e.runtimeType}: ${e.message}',
        filesFound: 0,
        filesSampled: 0,
        filesReadable: 0,
      );
    }
    if (!exists) {
      return FolderProbe(
        path: path,
        folderExists: false,
        listed: false,
        listError: 'directory does not exist',
        filesFound: 0,
        filesSampled: 0,
        filesReadable: 0,
      );
    }

    final List<File> candidates = [];
    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && isSupportedMediaPath(entity.path)) {
          candidates.add(entity);
          if (candidates.length >= _listCap) break;
        }
      }
    } on FileSystemException catch (e) {
      debugPrint('StorageProbe: cannot list $path: $e');
      return FolderProbe(
        path: path,
        folderExists: true,
        listed: false,
        listError: '${e.runtimeType}: ${e.message}',
        filesFound: 0,
        filesSampled: 0,
        filesReadable: 0,
      );
    }

    if (candidates.isEmpty) {
      return FolderProbe(
        path: path,
        folderExists: true,
        listed: true,
        filesFound: 0,
        filesSampled: 0,
        filesReadable: 0,
      );
    }

    int readable = 0;
    String? readError;
    final sample = candidates.take(_readSampleSize).toList();
    for (final file in sample) {
      RandomAccessFile? raf;
      try {
        raf = await file.open(mode: FileMode.read);
        await raf.readByte();
        readable++;
      } on FileSystemException catch (e) {
        readError ??= '${e.runtimeType}: ${e.message} (${file.path})';
      } on OSError catch (e) {
        readError ??= 'OSError: ${e.message} (${file.path})';
      } finally {
        try {
          await raf?.close();
        } on FileSystemException catch (e) {
          debugPrint('StorageProbe: failed to close ${file.path}: $e');
        }
      }
    }

    return FolderProbe(
      path: path,
      folderExists: true,
      listed: true,
      filesFound: candidates.length,
      filesSampled: sample.length,
      filesReadable: readable,
      readError: readError,
    );
  }
}
