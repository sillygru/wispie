import 'dart:async';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart' as amr;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../models/song.dart';
import 'scanner_service.dart';

/// One audio file handed to the app through Android Open-with (VIEW) or
/// Share (SEND). Local content arrives as a staged cache copy — the OS read
/// grant does not survive the intent — while http(s) links stream directly.
class OpenedAudioFile {
  final String? path;
  final String? remoteUrl;
  final String displayName;
  final String? mimeType;

  const OpenedAudioFile({
    this.path,
    this.remoteUrl,
    required this.displayName,
    this.mimeType,
  });

  /// The URL the player can open: staged file path or remote link.
  String get playableUrl => remoteUrl ?? path ?? '';

  bool get isRemote => remoteUrl != null && remoteUrl!.isNotEmpty;

  bool get isPlayable =>
      isRemote ||
      (path != null && path!.isNotEmpty && File(path!).existsSync());
}

/// Parses the `wispie/open-file` channel payload into validated files.
///
/// Pure and channel-free so it stays unit-testable. Malformed entries are
/// skipped rather than failing the whole batch.
List<OpenedAudioFile> parseOpenedAudioFiles(dynamic payload) {
  if (payload is! List) return const [];
  final files = <OpenedAudioFile>[];
  for (final entry in payload) {
    if (entry is! Map) continue;
    final path = entry['path'] as String?;
    final remoteUrl = entry['remoteUrl'] as String?;
    final displayName = (entry['displayName'] as String?)?.trim() ?? '';
    if (displayName.isEmpty) continue;
    if (!ScannerService.isSupportedMediaPath(displayName)) continue;
    if ((path == null || path.isEmpty) &&
        (remoteUrl == null || remoteUrl.isEmpty)) {
      continue;
    }
    files.add(OpenedAudioFile(
      path: path,
      remoteUrl: remoteUrl,
      displayName: displayName,
      mimeType: entry['mimeType'] as String?,
    ));
  }
  return files;
}

/// Builds a library-independent [Song] for an opened file.
///
/// The filename is namespaced with `external::` on purpose: it is the primary
/// key for all user data, and a transient cache copy must never collide with
/// (or inherit favorites/stats from) a real library entry. Playback, covers
/// and queueing only need [Song.url], which points at the staged copy.
Song transientSongForOpenedFile(OpenedAudioFile file) {
  final fallbackTitle = p.basenameWithoutExtension(file.displayName);
  final playableUrl = file.playableUrl;
  final filename = 'external::$playableUrl';

  if (!file.isRemote && file.path != null) {
    try {
      final metadata = amr.readMetadata(File(file.path!));
      return Song(
        title: metadata.title?.trim().isNotEmpty == true
            ? metadata.title!
            : fallbackTitle,
        artist: metadata.artist?.trim().isNotEmpty == true
            ? metadata.artist!
            : 'Unknown Artist',
        album: metadata.album?.trim().isNotEmpty == true
            ? metadata.album!
            : 'Unknown Album',
        filename: filename,
        url: playableUrl,
        duration: metadata.duration,
      );
    } catch (_) {
      // Unreadable tags fall through to the filename-based song below.
    }
  }

  return Song(
    title: fallbackTitle,
    artist: 'Unknown Artist',
    album: 'Unknown Album',
    filename: filename,
    url: playableUrl,
  );
}

/// Thin wrapper around the native `wispie/open-file` channel.
///
/// Cold start (tapped while closed) is a pull via [drainInitialFiles]; warm
/// start (tapped while running) is a push delivered to [onFiles]. Register
/// the push handler before draining so a file arriving in between is not lost
/// or delivered twice — the native side removes pushed files from its queue.
class OpenFileService {
  static const MethodChannel _channel = MethodChannel('wispie/open-file');

  bool _handlerRegistered = false;

  /// Registers the warm-start push handler. Safe to call more than once.
  void registerPushHandler(
      FutureOr<void> Function(List<OpenedAudioFile>) onFiles) {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOpenFiles') {
        final files = parseOpenedAudioFiles(call.arguments);
        if (files.isNotEmpty) await onFiles(files);
      }
    });
  }

  /// Pulls files staged from a cold-start intent. Returns empty on non-Android
  /// platforms, where the channel has no implementation.
  Future<List<OpenedAudioFile>> drainInitialFiles() async {
    if (!Platform.isAndroid) return const [];
    try {
      final payload = await _channel.invokeMethod<List<dynamic>>(
        'getInitialOpenFiles',
      );
      return parseOpenedAudioFiles(payload);
    } on MissingPluginException catch (e) {
      debugPrint('OpenFileService: no native implementation: $e');
      return const [];
    } on PlatformException catch (e) {
      debugPrint('OpenFileService: drain failed: $e');
      return const [];
    }
  }
}
