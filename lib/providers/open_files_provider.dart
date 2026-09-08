import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../models/song.dart';
import '../services/open_file_service.dart';
import '../services/scanner_service.dart';
import 'providers.dart';

/// Files opened via Android Open-with / Share.
///
/// Each file first plays immediately: as its real library entry when the file
/// is already in the library (covers, stats, lyrics and favorites intact), or
/// as a registered transient staged copy otherwise. [pendingImport] offers
/// only the genuinely-new local files for a permanent import.
class OpenFilesState {
  final List<OpenedAudioFile> pendingImport;
  final bool isImporting;
  final String? error;

  const OpenFilesState({
    this.pendingImport = const [],
    this.isImporting = false,
    this.error,
  });

  bool get hasPending => pendingImport.isNotEmpty;

  String get bannerLabel {
    if (pendingImport.isEmpty) return '';
    if (pendingImport.length == 1) {
      return 'Playing ${pendingImport.first.displayName}';
    }
    return 'Playing ${pendingImport.length} shared tracks';
  }

  OpenFilesState copyWith({
    List<OpenedAudioFile>? pendingImport,
    bool? isImporting,
    String? error,
  }) {
    return OpenFilesState(
      pendingImport: pendingImport ?? this.pendingImport,
      isImporting: isImporting ?? this.isImporting,
      error: error,
    );
  }
}

class OpenFilesNotifier extends Notifier<OpenFilesState> {
  final OpenFileService _service = OpenFileService();
  bool _initialized = false;

  @override
  OpenFilesState build() => const OpenFilesState();

  /// Starts listening for opened files. Safe to call more than once; only
  /// wired from [MainScreen], so intents wait in the native queue until setup
  /// is complete and the library UI exists to play into.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _service.registerPushHandler(_handleIncoming);
    final initial = await _service.drainInitialFiles();
    if (initial.isNotEmpty) await _handleIncoming(initial);
  }

  Future<void> _handleIncoming(List<OpenedAudioFile> files) async {
    final playable = files.where((f) => f.isPlayable).toList();
    if (playable.isEmpty) return;

    final known = state.pendingImport.map((f) => f.playableUrl).toSet();
    final fresh =
        playable.where((f) => !known.contains(f.playableUrl)).toList();
    if (fresh.isEmpty) return;

    final manager = ref.read(audioPlayerManagerProvider);
    final library = ref.read(songsProvider).value ?? const <Song>[];

    // An already-imported file plays as its library entry, so the player
    // screen, cover, stats and favorites all behave exactly as if the user
    // had tapped the song inside the app.
    final songs = <Song>[];
    final filesByUrl = <String, OpenedAudioFile>{};
    final matchedUrls = <String>{};
    for (final file in fresh) {
      final librarySong = matchLibrarySong(file, library);
      final song = librarySong ?? transientSongForOpenedFile(file);
      songs.add(song);
      filesByUrl[song.url] = file;
      if (librarySong != null) matchedUrls.add(file.playableUrl);
    }

    // Genuinely-new files play as registered transients, so now-playing,
    // queue reconcile and cover lookups resolve them like library songs.
    // Their covers are extracted up front: the transient starts without one.
    for (var i = 0; i < songs.length; i++) {
      final song = songs[i];
      if (!isExternalSongFilename(song.filename) || song.coverUrl != null) {
        continue;
      }
      final file = filesByUrl[song.url];
      if (file == null || file.isRemote) continue;
      try {
        final cover = await ScannerService.extractCoverOnDemand(song);
        if (cover != null) songs[i] = song.copyWith(coverUrl: cover);
      } catch (e) {
        debugPrint('OpenFiles: cover extraction failed for ${song.url}: $e');
      }
    }
    manager.ensureKnownSongs(songs);

    // Only genuinely-new local files join the import offer. Earlier offers
    // stay until imported or dismissed; already-library files never do.
    final importable = fresh
        .where((f) =>
            !f.isRemote &&
            f.path != null &&
            !matchedUrls.contains(f.playableUrl))
        .toList();
    state = state.copyWith(
      pendingImport: [...state.pendingImport, ...importable],
      error: null,
    );

    try {
      await manager.playSong(songs.first, contextQueue: songs);
    } on FileSystemException catch (e) {
      debugPrint('OpenFiles: playback failed, file unreadable: $e');
      state =
          state.copyWith(error: 'Could not play ${fresh.first.displayName}');
    } catch (e) {
      debugPrint('OpenFiles: playback failed: $e');
      state =
          state.copyWith(error: 'Could not play ${fresh.first.displayName}');
    }
  }

  /// Copies staged files into the first library folder and rescans, so they
  /// become permanent library entries with stats, covers and lyrics.
  /// Streamed links have no file to import and are left pending-free.
  Future<void> importToLibrary() async {
    final local = state.pendingImport
        .where((f) => !f.isRemote && f.path != null)
        .toList();
    if (local.isEmpty || state.isImporting) return;
    state = state.copyWith(isImporting: true, error: null);
    try {
      final folders = await ref.read(storageServiceProvider).getMusicFolders();
      final target = _writableFolder(folders);
      if (target == null) {
        state = state.copyWith(
          isImporting: false,
          error: 'No library folder available for import',
        );
        return;
      }
      var imported = 0;
      for (final file in local) {
        try {
          final dest = _uniqueDest(target, p.basename(file.path!));
          await File(file.path!).copy(dest.path);
          imported++;
        } on FileSystemException catch (e) {
          debugPrint('OpenFiles: import copy failed for ${file.path}: $e');
        } on IOException catch (e) {
          debugPrint('OpenFiles: import copy failed for ${file.path}: $e');
        }
      }
      if (imported == 0) {
        state = state.copyWith(
          isImporting: false,
          error: 'Import failed — the files could not be copied',
        );
        return;
      }
      await ref.read(songsProvider.notifier).refresh();
      final remaining = state.pendingImport
          .where((f) => f.isRemote || f.path == null || !local.contains(f))
          .toList();
      state = state.copyWith(pendingImport: remaining, isImporting: false);
    } catch (e) {
      debugPrint('OpenFiles: import failed: $e');
      state = state.copyWith(isImporting: false, error: 'Import failed');
    }
  }

  void dismiss() {
    state = const OpenFilesState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  /// First configured folder that exists on disk as a plain directory.
  /// SAF-only (treeUri) folders are skipped: copying into them needs the
  /// document provider, not a raw file copy.
  String? _writableFolder(List<Map<String, String>> folders) {
    for (final folder in folders) {
      final path = folder['path'];
      if (path == null || path.isEmpty) continue;
      try {
        if (Directory(path).existsSync()) return path;
      } on FileSystemException {
        continue;
      }
    }
    return null;
  }

  File _uniqueDest(String dir, String name) {
    var candidate = File(p.join(dir, name));
    if (!candidate.existsSync()) return candidate;
    final base = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    var counter = 1;
    while (candidate.existsSync()) {
      candidate = File(p.join(dir, '$base-$counter$ext'));
      counter++;
    }
    return candidate;
  }
}

final openFilesProvider =
    NotifierProvider<OpenFilesNotifier, OpenFilesState>(OpenFilesNotifier.new);
