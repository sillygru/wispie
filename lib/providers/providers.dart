import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/stats_service.dart';
import '../services/audio_player_manager.dart';
import '../services/storage_service.dart';
import '../services/scanner_service.dart';
import '../services/database_service.dart';
import '../services/file_manager_service.dart';
import '../services/bulk_rename_journal.dart';
import '../services/beat_analysis_service.dart';
import '../services/waveform_service.dart';
import '../services/cache_service.dart';
import '../services/color_extraction_service.dart';
import '../services/cover_refresh_service.dart';
import '../services/notification_cover_warmer.dart';
import '../services/update_service.dart';
import '../services/library_logic.dart';
import '../services/lrclib_service.dart';
import '../domain/services/search_service.dart';
import '../domain/services/song_affinity.dart';
import '../domain/services/song_replacement_rules.dart';
import '../domain/services/bulk_rename_planner.dart';
import 'search_provider.dart';
import '../presentation/widgets/spectrum_controller.dart';
import '../data/repositories/song_repository.dart';
import '../models/song.dart';
import 'user_data_provider.dart';
import 'settings_provider.dart';
import 'theme_provider.dart';

export 'auto_backup_provider.dart';
export 'sync_provider.dart';

enum MetadataSaveStatus { idle, saving, success, error }

class MetadataSaveState {
  final MetadataSaveStatus status;
  final String message;

  const MetadataSaveState({
    this.status = MetadataSaveStatus.idle,
    this.message = '',
  });
}

class MetadataSaveNotifier extends Notifier<MetadataSaveState> {
  int _token = 0;

  @override
  MetadataSaveState build() => const MetadataSaveState();

  void start() {
    _token += 1;
    state = const MetadataSaveState(
        status: MetadataSaveStatus.saving,
        message: 'Saving metadata changes...');
  }

  void success([String message = 'Metadata changes saved']) {
    final token = ++_token;
    state =
        MetadataSaveState(status: MetadataSaveStatus.success, message: message);
    _scheduleReset(token);
  }

  void error([String message = 'Failed to save metadata changes']) {
    final token = ++_token;
    state = MetadataSaveState(
      status: MetadataSaveStatus.error,
      message: message,
    );
    _scheduleReset(token);
  }

  void _scheduleReset(int token) {
    Future.delayed(const Duration(seconds: 2), () {
      if (!ref.mounted) return;
      if (_token == token) {
        state = const MetadataSaveState();
      }
    });
  }
}

class UpdateCheckState {
  final bool isChecking;
  final String currentVersion;
  final String? latestTag;
  final DateTime? lastCheckedAt;
  final Uri? releaseUrl;

  const UpdateCheckState({
    this.isChecking = false,
    this.currentVersion = '',
    this.latestTag,
    this.lastCheckedAt,
    this.releaseUrl,
  });

  UpdateCheckState copyWith({
    bool? isChecking,
    String? currentVersion,
    String? latestTag,
    DateTime? lastCheckedAt,
    Uri? releaseUrl,
  }) {
    return UpdateCheckState(
      isChecking: isChecking ?? this.isChecking,
      currentVersion: currentVersion ?? this.currentVersion,
      latestTag: latestTag ?? this.latestTag,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      releaseUrl: releaseUrl ?? this.releaseUrl,
    );
  }

  bool get hasUpdate =>
      latestTag != null &&
      currentVersion.isNotEmpty &&
      UpdateService.isNewerVersion(latestTag!, currentVersion);

  String? get latestVersionLabel => latestTag == null
      ? null
      : UpdateService.normalizedVersionLabel(latestTag!);
}

class UpdateCheckNotifier extends Notifier<UpdateCheckState> {
  static const String _lastCheckedAtKey = 'update_check_last_checked_at';
  static const String _latestTagKey = 'update_check_latest_tag';
  static const String _releaseUrlKey = 'update_check_release_url';
  static const Duration _checkInterval = Duration(days: 1);

  bool _bootstrapped = false;
  bool _sessionCheckStarted = false;

  @override
  UpdateCheckState build() => const UpdateCheckState();

  Future<void> prime() async {
    if (!_bootstrapped) {
      try {
        await _loadCachedState();
      } catch (_) {}
      _bootstrapped = true;
    }

    if (!_sessionCheckStarted && _shouldCheckNow()) {
      _sessionCheckStarted = true;
      await checkForUpdate();
    }
  }

  Future<void> checkForUpdate({bool force = false}) async {
    if (state.isChecking) return;
    if (!force && !_shouldCheckNow()) return;

    state = state.copyWith(isChecking: true);
    try {
      final release = await UpdateService().fetchLatestRelease();
      if (release != null) {
        final checkedAt = DateTime.now();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_latestTagKey, release.tagName);
        await prefs.setInt(_lastCheckedAtKey, checkedAt.millisecondsSinceEpoch);
        await prefs.setString(_releaseUrlKey, release.releaseUrl.toString());
        state = state.copyWith(
          latestTag: release.tagName,
          lastCheckedAt: checkedAt,
          releaseUrl: release.releaseUrl,
        );
      }
    } catch (_) {
      // Fail silently: update checks are best-effort only.
    } finally {
      state = state.copyWith(isChecking: false);
    }
  }

  Future<void> _loadCachedState() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    final lastCheckedAt = prefs.getInt(_lastCheckedAtKey);
    final releaseUrl = prefs.getString(_releaseUrlKey);

    state = UpdateCheckState(
      currentVersion: packageInfo.version,
      latestTag: prefs.getString(_latestTagKey),
      lastCheckedAt: lastCheckedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(lastCheckedAt)
          : null,
      releaseUrl: releaseUrl != null ? Uri.tryParse(releaseUrl) : null,
    );
  }

  bool _shouldCheckNow() {
    final lastCheckedAt = state.lastCheckedAt;
    if (lastCheckedAt == null) return true;
    return DateTime.now().difference(lastCheckedAt) >= _checkInterval;
  }
}

final metadataSaveProvider =
    NotifierProvider<MetadataSaveNotifier, MetadataSaveState>(
        MetadataSaveNotifier.new);

/// Bumped whenever lyrics are written to a file.
///
/// Lyrics live in the audio file rather than in provider state, so there is
/// nothing for a lyrics view to watch. Views listen to this counter and reload
/// from the repository, which by then has had its cache invalidated.
class LyricsRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final lyricsRevisionProvider =
    NotifierProvider<LyricsRevisionNotifier, int>(LyricsRevisionNotifier.new);

class TranslationRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final translationRevisionProvider =
    NotifierProvider<TranslationRevisionNotifier, int>(
        TranslationRevisionNotifier.new);

final updateCheckProvider =
    NotifierProvider<UpdateCheckNotifier, UpdateCheckState>(
        UpdateCheckNotifier.new);

class BottomDockVisibilityState {
  final double visibility;
  final bool isDragging;

  const BottomDockVisibilityState({
    this.visibility = 1,
    this.isDragging = false,
  });

  BottomDockVisibilityState copyWith({
    double? visibility,
    bool? isDragging,
  }) {
    return BottomDockVisibilityState(
      visibility: visibility ?? this.visibility,
      isDragging: isDragging ?? this.isDragging,
    );
  }
}

class BottomDockVisibilityNotifier extends Notifier<BottomDockVisibilityState> {
  /// Getting the bar *out of the way* should take deliberate downward travel —
  /// otherwise it flickers away on the smallest nudge.
  static const double hideDragDistance = 110.0;

  /// Getting it *back* should not. Reaching for the nav bar is an intentional
  /// act, and the old symmetric distance meant half a screen of upward drag
  /// before it reappeared. A short flick up now brings it most of the way home.
  static const double revealDragDistance = 36.0;

  /// True when the last motion we saw was upward (revealing).
  bool _revealing = false;

  @override
  BottomDockVisibilityState build() => const BottomDockVisibilityState();

  void updateFromDrag({required double scrollDelta}) {
    if (scrollDelta == 0) return;

    _revealing = scrollDelta < 0;
    final distance = _revealing ? revealDragDistance : hideDragDistance;

    final nextVisibility =
        (state.visibility - (scrollDelta / distance)).clamp(0.0, 1.0);

    // Already pinned at the end it's heading for — every further pixel of the
    // same scroll would otherwise republish identical state and rebuild the
    // shell on every frame.
    if (nextVisibility == state.visibility && state.isDragging) return;

    state = state.copyWith(
      visibility: nextVisibility,
      isDragging: true,
    );
  }

  /// Asymmetric on purpose: upward intent nearly always wins. Once the finger
  /// leaves, a barely-started reveal completes, while a barely-started hide
  /// springs back.
  void settle() {
    final target = _revealing
        ? (state.visibility > 0.15 ? 1.0 : 0.0)
        : (state.visibility < 0.4 ? 0.0 : 1.0);

    state = state.copyWith(visibility: target, isDragging: false);
  }

  void show() {
    _revealing = true;
    if (state.visibility == 1 && !state.isDragging) return;
    state = const BottomDockVisibilityState(visibility: 1, isDragging: false);
  }
}

final bottomDockVisibilityProvider =
    NotifierProvider<BottomDockVisibilityNotifier, BottomDockVisibilityState>(
  BottomDockVisibilityNotifier.new,
);

/// Returns the shell to the Home bottom-nav tab.
///
/// Esc uses this as its last step: pop a pushed route, and once there is
/// nothing left to pop, fall back to the Home tab rather than doing nothing.
/// Each call mints a new [id] so pressing Esc while already Home still lands.
class HomeNavigationNotifier extends Notifier<int?> {
  int _nextId = 0;

  @override
  int? build() => null;

  void goHome() => state = ++_nextId;
}

final homeNavigationProvider =
    NotifierProvider<HomeNavigationNotifier, int?>(HomeNavigationNotifier.new);

/// Opens the Library bottom-nav tab on a Folders / Artists / Albums sub-tab.
///
/// Each call mints a new [id] so re-tapping the same destination still notifies
/// listeners (e.g. drawer → Artists while already on Artists).
class LibraryNavigationIntent {
  final int subTabIndex;
  final int id;

  const LibraryNavigationIntent({
    required this.subTabIndex,
    required this.id,
  });
}

class LibraryNavigationNotifier extends Notifier<LibraryNavigationIntent?> {
  int _nextId = 0;

  @override
  LibraryNavigationIntent? build() => null;

  /// [subTabIndex]: 0 Folders, 1 Artists, 2 Albums.
  void openSubTab(int subTabIndex) {
    assert(subTabIndex >= 0 && subTabIndex <= 2);
    state = LibraryNavigationIntent(
      subTabIndex: subTabIndex,
      id: ++_nextId,
    );
  }
}

final libraryNavigationProvider =
    NotifierProvider<LibraryNavigationNotifier, LibraryNavigationIntent?>(
  LibraryNavigationNotifier.new,
);

class ScanProgressNotifier extends Notifier<double> {
  @override
  double build() => 0.0;
}

class IsScanningNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

/// Surfaces the reason a scan could not trust its (usually empty) result, so
/// the UI can explain "can't reach your music folder" instead of silently
/// showing an empty library. `null` means the last scan was clean.
class LibraryScanIssueNotifier extends Notifier<ScanStatus?> {
  @override
  ScanStatus? build() => null;

  void set(ScanStatus? status) => state = status;
}

final scanProgressProvider =
    NotifierProvider<ScanProgressNotifier, double>(ScanProgressNotifier.new);
final isScanningProvider =
    NotifierProvider<IsScanningNotifier, bool>(IsScanningNotifier.new);
final libraryScanIssueProvider =
    NotifierProvider<LibraryScanIssueNotifier, ScanStatus?>(
        LibraryScanIssueNotifier.new);

/// Music folders the user has configured. Used to tell "no folder set up yet"
/// apart from "folder configured but currently unreachable" in the UI.
final musicFoldersProvider =
    FutureProvider<List<Map<String, String>>>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  return storage.getMusicFolders();
});

// Services & Repositories
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final statsServiceProvider = Provider<StatsService>((ref) {
  return StatsService();
});

final scannerServiceProvider = Provider<ScannerService>((ref) {
  return ScannerService();
});

final fileManagerServiceProvider = Provider<FileManagerService>((ref) {
  return FileManagerService();
});

final waveformServiceProvider = Provider<WaveformService>((ref) {
  final service = WaveformService(CacheService.instance);
  ref.onDispose(() => service.dispose());
  return service;
});

final beatAnalysisServiceProvider = Provider<BeatAnalysisService>((ref) {
  final service = BeatAnalysisService(CacheService.instance);
  ref.onDispose(() => service.dispose());
  return service;
});

/// The one controller behind every [AudioVisualizer] in the app.
///
/// Created eagerly with the provider but inert until a visualiser listens to
/// it, so an app with no bars on screen pays nothing for this.
final spectrumControllerProvider = Provider<SpectrumController>((ref) {
  final manager = ref.read(audioPlayerManagerProvider);
  final controller = SpectrumController(
    player: manager.player,
    currentSong: manager.currentSongNotifier,
    beatAnalysis: ref.read(beatAnalysisServiceProvider),
    playingIntent: manager.playingNotifier,
  );

  final settings = ref.read(settingsProvider);
  controller
    ..mode = settings.visualizerMode
    ..latencyMs = settings.playerMotionLatencyMs;

  // Pushed in rather than watched, so a settings change retunes the live
  // controller instead of replacing it and dropping every listener.
  ref.listen<SettingsState>(settingsProvider, (previous, next) {
    controller
      ..mode = next.visualizerMode
      ..latencyMs = next.playerMotionLatencyMs;
  });

  ref.onDispose(controller.dispose);
  return controller;
});

final songRepositoryProvider = Provider<SongRepository>((ref) {
  return SongRepository();
});

final lrclibServiceProvider = Provider<LrclibService>((ref) {
  return LrclibService();
});

final audioPlayerManagerProvider = Provider<AudioPlayerManager>((ref) {
  final manager = AudioPlayerManager(
    ref.watch(statsServiceProvider),
    ref.watch(storageServiceProvider),
    ref,
  );

  ref.onDispose(() => manager.dispose());
  return manager;
});

// Data Providers
class SongsNotifier extends AsyncNotifier<List<Song>> {
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;
  Timer? _debounceTimer;

  static const String _startupMaintenancePendingKey =
      'startup_cache_maintenance_pending';

  /// How many files may be renamed before their rows are moved to match.
  ///
  /// Small enough that closing the app mid-sweep costs a visible handful of songs
  /// and their repair is automatic; large enough that the per-commit fsync is not
  /// the bulk of the work.
  static const int _commitSlice = 25;

  @override
  Future<List<Song>> build() async {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    // Watch only the hidden list, not the whole user-data state. userData
    // emits several times during startup (loading flag, initial load,
    // recommendation rebuild) and each emission would otherwise re-run this
    // build — meaning another full getAllSongs() on the UI thread.
    ref.watch(userDataProvider.select((s) => s.hidden.join('\x00')));
    final userData = ref.read(userDataProvider);

    // Before anything reads the library. A sweep that was killed mid-flight has
    // files on disk under names the rows do not have yet, and this is the last
    // point at which the repair can happen without a scan racing it.
    await recoverPendingRenames();

    CoverRefreshService.instance.onCoverResolved = (song) {
      if (song.coverUrl != null && song.coverUrl!.isNotEmpty) {
        updateSongCoverByFilename(song.filename, song.coverUrl!);
      }
    };

    final cached = await DatabaseService.instance.getAllSongs();
    if (cached.isNotEmpty) {
      final filtered =
          cached.where((s) => !userData.isHidden(s.filename)).toList();
      // Only trigger background scan if the app version changed or a
      // library change was explicitly marked. Avoids unnecessary full
      // rescans on every startup which can cause date-added reset and
      // cover re-extraction.
      if (await _shouldRunStartupScan()) {
        _scheduleBackgroundScanUpdate(cached, showIndicator: false);
      }
      return filtered;
    }

    // 3. If no cache, return empty immediately and scan in background.
    //    This avoids blocking the UI on first startup.
    _scheduleBackgroundScanUpdate([], showIndicator: true);
    return [];
  }

  Future<bool> _shouldRunStartupScan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getBool(_startupMaintenancePendingKey) ?? false;
      if (pending) return true;

      final lastVersion = prefs.getString('last_scan_version');
      final info = await PackageInfo.fromPlatform();
      final currentVersion = '${info.version}+${info.buildNumber}';
      return lastVersion != currentVersion;
    } catch (_) {
      return true;
    }
  }

  Future<void> _markStartupScanComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final info = await PackageInfo.fromPlatform();
      await prefs.setString(
          'last_scan_version', '${info.version}+${info.buildNumber}');
      await prefs.setBool(_startupMaintenancePendingKey, false);
    } catch (_) {}
  }

  void updateSongCoverByFilename(String filename, String coverUrl) {
    final current = state.value;
    if (current == null || current.isEmpty) return;
    bool updatedAny = false;
    final newList = current.map((s) {
      if (s.filename == filename && s.coverUrl != coverUrl) {
        updatedAny = true;
        return Song(
          title: s.title,
          artist: s.artist,
          album: s.album,
          filename: s.filename,
          url: s.url,
          coverUrl: coverUrl,
          hasLyrics: s.hasLyrics,
          playCount: s.playCount,
          duration: s.duration,
          mtime: s.mtime,
          createdEpochSec: s.createdEpochSec,
          songDateEpochSec: s.songDateEpochSec,
        );
      }
      return s;
    }).toList();
    if (updatedAny) {
      state = AsyncValue.data(newList);
      ref.read(audioPlayerManagerProvider).refreshSongs(newList);
    }
  }

  void _scheduleBackgroundScanUpdate(List<Song> existingSongs,
      {bool showIndicator = false}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _backgroundScanUpdate(existingSongs, showIndicator: showIndicator);
    });
  }

  Future<List<Song>> _performFullScan({
    bool isBackground = false,
    List<Song>? existingSongs,
    bool showIndicator = false,
    bool fastMode = false,
    void Function(List<Song> songs)? onSongsDiscovered,
  }) async {
    final storage = ref.read(storageServiceProvider);
    final scanner = ref.read(scannerServiceProvider);

    final musicFolders = await storage.getMusicFolders();

    if (musicFolders.isEmpty) {
      debugPrint('No music folders configured. Cannot scan.');
      return [];
    }

    // Only show scanning indicator for non-background scans or if explicitly requested
    if (!isBackground || showIndicator) {
      ref.read(isScanningProvider.notifier).state = true;
    }
    ref.read(scanProgressProvider.notifier).state = 0.0;
    NotificationCoverWarmer.instance.pushPause();

    try {
      final settings = ref.read(settingsProvider);
      final List<Song> allSongs = [];

      // Scan each music folder
      for (int i = 0; i < musicFolders.length; i++) {
        final folder = musicFolders[i];
        final path = folder['path'];
        if (path == null || path.isEmpty) continue;

        final scanResult = await scanner.scanDirectory(
          path,
          existingSongs: existingSongs,
          lyricsPath: null,
          onProgress: (progress) {
            // Overall progress across all folders
            final overallProgress = (i + progress) / musicFolders.length;
            ref.read(scanProgressProvider.notifier).state = overallProgress;
          },
          onSongsDiscovered: onSongsDiscovered,
          includeVideos: settings.includeVideos,
          minimumFileSizeBytes: settings.minimumFileSizeBytes,
          fastMode: fastMode,
        );

        allSongs.addAll(scanResult.songs);
      }

      // De-duplicate by filename (base name) when enabled
      List<Song> uniqueSongs;
      if (settings.preventDuplicateTracks) {
        final seenFilenames = <String>{};
        uniqueSongs = allSongs.where((s) {
          if (seenFilenames.contains(s.filename)) return false;
          seenFilenames.add(s.filename);
          return true;
        }).toList();
      } else {
        uniqueSongs = allSongs;
      }

      // Skip duration filter during fast mode — durations are unknown
      if (!fastMode && settings.minimumTrackDurationMs > 0) {
        uniqueSongs = uniqueSongs
            .where((s) =>
                s.duration == null ||
                s.duration!.inMilliseconds >= settings.minimumTrackDurationMs)
            .toList();
      }

      if (settings.extractFeatArtists) {
        uniqueSongs = uniqueSongs.map(extractFeatFromSong).toList();
      }

      // Carry forward what a scan can't re-derive: when a song was added, and
      // any cover a previous pass extracted. Matched by filename as well as
      // path, since the row these will be written over is keyed by filename —
      // a file that moved folders would otherwise look brand new and lose both.
      if (existingSongs != null) {
        final existingByUrl = <String, Song>{};
        final existingByFilename = <String, Song>{};
        for (final s in existingSongs) {
          existingByUrl[s.url] = s;
          existingByFilename[s.filename] = s;
        }
        uniqueSongs = uniqueSongs.map((s) {
          final existing =
              existingByUrl[s.url] ?? existingByFilename[s.filename];
          if (existing == null) return s;
          final needsCreated = existing.createdEpochSec != null &&
              s.createdEpochSec != existing.createdEpochSec;
          final needsSongDate = existing.songDateEpochSec != null &&
              s.songDateEpochSec != existing.songDateEpochSec;
          final needsCover = s.coverUrl == null && existing.coverUrl != null;
          if (!needsCreated && !needsSongDate && !needsCover) return s;
          return Song(
            title: s.title,
            artist: s.artist,
            album: s.album,
            filename: s.filename,
            url: s.url,
            coverUrl: s.coverUrl ?? existing.coverUrl,
            hasLyrics: s.hasLyrics,
            playCount: s.playCount,
            duration: s.duration,
            mtime: s.mtime,
            createdEpochSec: existing.createdEpochSec ?? s.createdEpochSec,
            songDateEpochSec: existing.songDateEpochSec ?? s.songDateEpochSec,
          );
        }).toList();
      }

      // In fast mode, songs are already batch-inserted by the scanner inner
      // loop (incremental DB writes). In full mode the full scan also does
      // incremental inserts, but we re-insert here to capture any post-
      // processing changes like dedup/filtering.
      if (!fastMode) {
        await DatabaseService.instance.insertSongsBatch(uniqueSongs);
      }

      return uniqueSongs;
    } finally {
      if (!isBackground || showIndicator) {
        ref.read(isScanningProvider.notifier).state = false;
      }
      ref.read(scanProgressProvider.notifier).state = 0.0;
      NotificationCoverWarmer.instance.popPause();
    }
  }

  Future<void> _backgroundScanUpdate(List<Song> existingSongs,
      {bool showIndicator = false}) async {
    if (_isRefreshing) return;

    // Scanning saturates the device with isolate work; passive cover warming
    // stays out of its way until it finishes.
    NotificationCoverWarmer.instance.pushPause();
    try {
      _isRefreshing = true;
      final userData = ref.read(userDataProvider);

      CoverRefreshService.instance.onCoverResolved = (song) {
        updateSongCoverByFilename(song.filename, song.coverUrl!);
      };

      // Show the scanning indicator for the full duration of all passes
      if (showIndicator) {
        ref.read(isScanningProvider.notifier).state = true;
      }

      // === Pass 0: Fast registration (filenames, paths, mtimes only) ===
      // Stream songs live into the UI as they are discovered.
      final accumulatedFast = <Song>[];
      final fastSongs = await _performFullScan(
        isBackground: true,
        existingSongs: existingSongs,
        showIndicator: false,
        fastMode: true,
        onSongsDiscovered: (chunk) {
          accumulatedFast.addAll(chunk);
          final filtered = accumulatedFast
              .where((s) => !userData.isHidden(s.filename))
              .toList();
          if (filtered.isNotEmpty) {
            ref.read(audioPlayerManagerProvider).refreshSongs(filtered);
            state = AsyncValue.data(filtered);
          }
        },
      );

      final filteredFast =
          fastSongs.where((s) => !userData.isHidden(s.filename)).toList();

      if (filteredFast.isNotEmpty) {
        ref.read(audioPlayerManagerProvider).refreshSongs(filteredFast);
        state = AsyncValue.data(filteredFast);
      }

      // === Pass 1: Metadata enrichment & Cover extraction ===
      List<Song> latestEnriched = fastSongs;
      if (fastSongs.isNotEmpty) {
        try {
          latestEnriched = await ScannerService.enrichAllMetadata(
            fastSongs,
            onProgress: (progress) {
              ref.read(scanProgressProvider.notifier).state =
                  0.2 + (progress * 0.3);
            },
            onBatchEnriched: (batch) {
              final currentList = state.value ?? [];
              if (currentList.isEmpty) return;
              final enrichedMap = {for (final s in batch) s.filename: s};
              final updated = currentList.map((s) {
                final match = enrichedMap[s.filename];
                return match ?? s;
              }).toList();
              ref.read(audioPlayerManagerProvider).refreshSongs(updated);
              state = AsyncValue.data(updated);
            },
          );

          final filteredEnriched = latestEnriched
              .where((s) => !userData.isHidden(s.filename))
              .toList();

          ref.read(audioPlayerManagerProvider).refreshSongs(filteredEnriched);
          state = AsyncValue.data(filteredEnriched);
        } catch (e) {
          debugPrint('Metadata enrichment failed: $e');
        }

        // === Pass 2: Fast Background Cover Extraction (non-freezing) ===
        try {
          final withCovers = await ScannerService.extractCoversInBackground(
            latestEnriched,
            onProgress: (progress) {
              ref.read(scanProgressProvider.notifier).state =
                  0.5 + (progress * 0.5);
            },
            onBatchExtracted: (updatedBatch) {
              final currentList = state.value ?? [];
              if (currentList.isEmpty) return;
              final coverMap = {
                for (final s in updatedBatch) s.filename: s.coverUrl
              };
              final updated = currentList.map((s) {
                final newCover = coverMap[s.filename];
                if (newCover != null) {
                  return Song(
                    title: s.title,
                    artist: s.artist,
                    album: s.album,
                    filename: s.filename,
                    url: s.url,
                    coverUrl: newCover,
                    hasLyrics: s.hasLyrics,
                    playCount: s.playCount,
                    duration: s.duration,
                    mtime: s.mtime,
                    createdEpochSec: s.createdEpochSec,
                    songDateEpochSec: s.songDateEpochSec,
                  );
                }
                return s;
              }).toList();
              ref.read(audioPlayerManagerProvider).refreshSongs(updated);
              state = AsyncValue.data(updated);
            },
          );

          final filteredWithCovers =
              withCovers.where((s) => !userData.isHidden(s.filename)).toList();
          ref.read(audioPlayerManagerProvider).refreshSongs(filteredWithCovers);
          state = AsyncValue.data(filteredWithCovers);
        } catch (e) {
          debugPrint('Background cover extraction failed: $e');
        }

        // Rebuild search index after enrichment.
        await Future.delayed(Duration.zero);
        final searchService = SearchService();
        try {
          await searchService.init();
          await searchService.rebuildIndex(latestEnriched);
        } catch (e) {
          debugPrint('Search index rebuild failed: $e');
        } finally {
          await searchService.dispose();
        }
      }

      await _saveScanCheckpoint();
    } catch (e) {
      debugPrint('Background scan failed: $e');
    } finally {
      _isRefreshing = false;
      ref.read(isScanningProvider.notifier).state = false;
      ref.read(scanProgressProvider.notifier).state = 0.0;
      NotificationCoverWarmer.instance.popPause();
    }
  }

  /// Persists a scan-complete marker so interrupted scans don't restart
  /// from scratch on the next app launch. After the marker is saved,
  /// [_shouldRunStartupScan] returns false on subsequent restarts.
  Future<void> _saveScanCheckpoint() async {
    await _markStartupScanComplete();
  }

  Future<void> refresh({bool isBackground = false}) async {
    final storage = ref.read(storageServiceProvider);
    final pullEnabled = await storage.getPullToRefreshEnabled();
    if (!pullEnabled && !isBackground) return;

    if (_isRefreshing) {
      debugPrint('SongsNotifier: Refresh already in progress, skipping');
      return;
    }

    if (isBackground && _lastRefreshTime != null) {
      final diff = DateTime.now().difference(_lastRefreshTime!);
      if (diff.inSeconds < 30) {
        // Reduced from 60 seconds for better responsiveness
        return;
      }
    }

    _isRefreshing = true;
    _lastRefreshTime = DateTime.now();

    try {
      // Capture current progress and flush to DB on manual refresh
      await ref.read(audioPlayerManagerProvider).forceFlushCurrentStats();

      final newState = await AsyncValue.guard<List<Song>>(() async {
        // Local-only refresh - just scan files
        final songs = await _performFullScan(
            isBackground: isBackground, existingSongs: state.value);
        ref.read(audioPlayerManagerProvider).refreshSongs(songs);

        final userData = ref.read(userDataProvider);
        return songs.where((s) => !userData.isHidden(s.filename)).toList();
      });

      if (isBackground) {
        // Only update if not null and actually has changes
        if (newState.hasValue) {
          final newSongs = newState.value!;
          final oldSongs = state.value ?? [];
          bool hasChanges = newSongs.length != oldSongs.length;
          if (!hasChanges) {
            for (int i = 0; i < newSongs.length; i++) {
              if (newSongs[i].url != oldSongs[i].url ||
                  newSongs[i].mtime != oldSongs[i].mtime) {
                hasChanges = true;
                break;
              }
            }
          }
          if (hasChanges) {
            state = newState;
          }
        }
      } else {
        state = newState;
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> forceFullScan() async {
    state = await AsyncValue.guard<List<Song>>(() async {
      final songs = await _performFullScan(); // No existingSongs = full scan
      ref.read(audioPlayerManagerProvider).refreshSongs(songs);
      final userData = ref.read(userDataProvider);
      return songs.where((s) => !userData.isHidden(s.filename)).toList();
    });
  }

  /// Refreshes ONLY the play counts of the current songs from the database
  Future<void> refreshPlayCounts() async {
    if (!state.hasValue) return;

    final playCounts = await DatabaseService.instance.getPlayCounts();

    var changed = false;
    final updatedSongs = state.value!.map((s) {
      final newCount = playCounts[s.filename] ?? 0;
      if (newCount == s.playCount) return s;
      changed = true;
      return Song(
        title: s.title,
        artist: s.artist,
        album: s.album,
        filename: s.filename,
        url: s.url,
        coverUrl: s.coverUrl,
        hasLyrics: s.hasLyrics,
        playCount: newCount,
        duration: s.duration,
        mtime: s.mtime,
        createdEpochSec: s.createdEpochSec,
        songDateEpochSec: s.songDateEpochSec,
      );
    }).toList();

    // Publishing an identical list still rebuilds every provider watching
    // songsProvider (stats, insights, library), and this runs on every
    // lifecycle change — a screenshot is enough.
    if (!changed) return;

    await DatabaseService.instance.insertSongsBatch(updatedSongs);

    state = AsyncValue.data(updatedSongs);

    // Update player manager and cache
    ref.read(audioPlayerManagerProvider).refreshSongs(updatedSongs);
  }

  Future<void> hideSong(Song song) async {
    await ref.read(userDataProvider.notifier).toggleHidden(song.filename);
    // state will auto-update because build() watches userDataProvider
  }

  Future<void> deleteSongFile(Song song) async {
    // Get current songs before setting loading state
    final currentSongs = state.value ?? [];

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Delete the physical file
      await ref.read(fileManagerServiceProvider).deleteSongFile(song);

      // Remove from database
      await DatabaseService.instance.deleteFile(song.filename);

      // Remove the deleted song from the current list immediately
      final updatedSongs =
          currentSongs.where((s) => s.filename != song.filename).toList();

      // Update audio player with the new list
      ref.read(audioPlayerManagerProvider).refreshSongs(updatedSongs);

      // Return the updated list immediately (no full scan needed)
      final userData = ref.read(userDataProvider);
      return updatedSongs.where((s) => !userData.isHidden(s.filename)).toList();
    });
  }

  Future<void> bulkDeleteSongs(List<Song> songs) async {
    final currentSongs = state.value ?? [];
    final filenamesToDelete = songs.map((s) => s.filename).toSet();

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final fileManager = ref.read(fileManagerServiceProvider);

      for (final song in songs) {
        try {
          await fileManager.deleteSongFile(song);
          await DatabaseService.instance.deleteFile(song.filename);
        } catch (e) {
          debugPrint('Failed to delete ${song.filename}: $e');
        }
      }

      final updatedSongs = currentSongs
          .where((s) => !filenamesToDelete.contains(s.filename))
          .toList();

      ref.read(audioPlayerManagerProvider).refreshSongs(updatedSongs);
      final userData = ref.read(userDataProvider);
      return updatedSongs.where((s) => !userData.isHidden(s.filename)).toList();
    });
  }

  /// Publishes an edited song everywhere it is cached, without rescanning.
  ///
  /// A metadata edit touches one file, so the old behaviour — flip the provider
  /// to `AsyncLoading` and re-scan the entire library — was both a visible
  /// freeze and far more work than the change warranted. Each of these is a
  /// targeted update of one row/entry:
  ///
  ///  1. the in-memory song list, so every screen watching it repaints;
  ///  2. the `song` table, so the change survives a restart;
  ///  3. the player's song map and queues, which is also what pushes the new
  ///     values onto the player screen and the now-playing bar;
  ///  4. the search index — updated before publishing state so searches stay in sync.
  ///
  /// [previousFilename] is for renames, where the entry to replace is not the
  /// one the updated song now points at.
  Future<void> _applyLocalSongUpdate(
    Song updated, {
    String? previousFilename,
  }) async {
    final targetFilename = previousFilename ?? updated.filename;

    if (state.hasValue) {
      final current = state.value ?? const <Song>[];
      state = AsyncValue.data([
        for (final s in current)
          if (s.filename == targetFilename) updated else s,
      ]);
    }

    ref.read(audioPlayerManagerProvider).refreshSongs(
          state.value ?? const [],
          previousFilename: previousFilename,
        );

    unawaited(DatabaseService.instance.insertSongsBatch([updated]));
    unawaited(_reindexSong(updated, previousFilename: previousFilename));
  }

  Future<void> _reindexSong(Song song, {String? previousFilename}) async {
    try {
      final searchService = ref.read(searchServiceProvider);
      await searchService.init();
      if (previousFilename != null && previousFilename != song.filename) {
        await searchService.removeSong(previousFilename);
      }
      await searchService.updateSong(song);
    } catch (e) {
      debugPrint('Search index update failed for ${song.filename}: $e');
    }
  }

  /// The file's modification time after a write, so the scanner does not think
  /// the row is stale and re-read what we just told it.
  Future<double?> _statMtime(String url, double? fallback) async {
    try {
      final stat = await File(url).stat();
      return stat.modified.millisecondsSinceEpoch / 1000.0;
    } catch (_) {
      return fallback;
    }
  }

  /// Renames the file on disk and returns the song under its new identity.
  ///
  /// The caller needs that returned song: `filename` is the primary key for
  /// every piece of user data, so anything continuing to act on the old value
  /// after this point would be writing to a path that no longer exists.
  Future<Song> renameSong(Song song, String newFilename) async {
    final notifier = ref.read(metadataSaveProvider.notifier);
    notifier.start();
    try {
      await ref.read(fileManagerServiceProvider).renameSong(song, newFilename);

      // FileManagerService.renameSong appends the original extension, and
      // DatabaseService.renameFile has already migrated the dependent rows.
      final resolvedFilename = '$newFilename${p.extension(song.url)}';
      final resolvedUrl = p.join(p.dirname(song.url), resolvedFilename);
      final updated = song.copyWith(
        filename: resolvedFilename,
        url: resolvedUrl,
      );

      // The lyrics cache is keyed off the file URL, so the old entry is now
      // unreachable garbage.
      await ref.read(songRepositoryProvider).invalidateLyricsCache(song);

      await _applyLocalSongUpdate(updated, previousFilename: song.filename);
      ref.read(userDataProvider.notifier).refresh();
      notifier.success('Renamed successfully');
      return updated;
    } catch (e) {
      notifier.error('Failed to rename song');
      debugPrint('Failed to rename song: $e');
      rethrow;
    }
  }

  /// Finishes the database half of a bulk rename that was interrupted.
  ///
  /// A rename is two writes — the file moves, then the filename-keyed rows follow
  /// — and only the second one is recoverable in principle. The journal closes
  /// that gap, but it is written *before* the file is touched, so it also lists
  /// renames that never happened. Each entry is therefore confirmed against the
  /// filesystem first: applying one whose file is still sitting under the old name
  /// would point the library at a name that does not exist.
  ///
  /// Returns how many songs were put back together.
  Future<int> recoverPendingRenames() async {
    final journal = BulkRenameJournal.instance;
    await journal.load();
    if (journal.isEmpty) return 0;

    final fileManager = ref.read(fileManagerServiceProvider);
    final confirmed = <({String from, String to})>[];
    for (final entry in journal.entries) {
      if (await fileManager.fileExistsAt(entry.url)) {
        confirmed.add((from: entry.from, to: entry.to));
      } else {
        debugPrint('Bulk rename recovery skipped ${entry.from}: '
            '${entry.url} was never written');
      }
    }

    if (confirmed.isNotEmpty) {
      await DatabaseService.instance.renameFiles(confirmed);
      await _reindexRenames({for (final e in confirmed) e.from: e.to});
      debugPrint('Recovered ${confirmed.length} interrupted renames');
    }

    // Either way the journal has served its purpose: the entries are now either
    // in the database or known never to have landed.
    await journal.clear();
    return confirmed.length;
  }

  /// Renames a batch of files and moves every filename-keyed row and cache file
  /// onto the new names.
  ///
  /// Files go first, then the rows, and the rows go in slices rather than one
  /// write at the very end. That is what lets a sweep survive the app being
  /// closed: whatever slice was in flight is the only thing a crash can cost, and
  /// [BulkRenameJournal] is what makes even that slice recoverable. Holding the
  /// whole batch back until the end — which is what one big transaction is
  /// cheaper at — would mean the library spent the entire sweep pointing at names
  /// that did not exist yet.
  ///
  /// Within a slice the work is still batched: at a few hundred songs the
  /// per-song overhead dominates the actual renaming, and re-indexing a song under
  /// its new name re-extracts its lyrics from disk, once per song.
  ///
  /// [onProgress] carries a phase label, because "340 of 500" means nothing on
  /// its own once the operation is a sequence of differently-sized steps.
  ///
  /// [isCancelled] stops the file loop, and nothing else. The database write and
  /// the state publish always run for the files that *were* renamed: bailing out
  /// before them would leave the library pointing at names that no longer exist,
  /// which is the one outcome worse than a slow rename.
  ///
  /// [plans] must come from [BulkRenamePlanner.plan] and be passed through
  /// [BulkRenamePlanner.excludeExistingTargets]; anything marked skipped there
  /// is left alone and reported back in the result.
  Future<BulkRenameResult> bulkRenameSongs(
    List<BulkRenamePlan> plans, {
    void Function(String label, int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final actionable = plans.where((entry) => entry.willRename).toList();
    if (actionable.isEmpty) return const BulkRenameResult.empty();

    final notifier = ref.read(metadataSaveProvider.notifier);
    notifier.start();

    final fileManager = ref.read(fileManagerServiceProvider);
    final cache = CacheService.instance;
    final journal = BulkRenameJournal.instance;
    final cancelled = isCancelled ?? () => false;

    /// Old filename paired with the song under its new identity. Everything
    /// downstream is derived from this rather than kept in parallel maps, which
    /// is how the two drift out of step.
    final applied = <({String previousFilename, Song updated})>[];
    final failures = <BulkRenameFailure>[];
    var stoppedEarly = false;

    /// How far into [applied] the database has been brought. The gap between it
    /// and [applied].length is the slice a crash would cost.
    var committed = 0;

    /// Moves the rows for everything renamed since the last call, then forgets it
    /// in the journal.
    Future<void> commit() async {
      if (applied.length == committed) return;
      final slice = applied.sublist(committed);
      final remaps = {
        for (final item in slice) item.previousFilename: item.updated.filename,
      };

      await DatabaseService.instance.renameFiles([
        for (final item in slice)
          (from: item.previousFilename, to: item.updated.filename),
      ]);

      final current = state.value ?? const <Song>[];
      state = AsyncValue.data(
        BulkRenamePlanner.applyRenames(
          current,
          {for (final item in slice) item.previousFilename: item.updated},
        ),
      );

      ref
          .read(audioPlayerManagerProvider)
          .refreshSongs(state.value!, filenameRemaps: remaps);

      // Covers can move with the file, so the library rows are rewritten rather
      // than left describing the song as it was before its artwork did.
      await DatabaseService.instance.insertSongsBatch([
        for (final item in slice) item.updated,
      ]);

      await _reindexRenames(remaps);

      committed = applied.length;
      await journal.clear();
    }

    onProgress?.call('Renaming files', 0, actionable.length);

    for (var i = 0; i < actionable.length; i++) {
      if (cancelled()) {
        stoppedEarly = true;
        onProgress?.call('Renaming files', i, actionable.length);
        break;
      }

      final entry = actionable[i];
      final before = entry.song;
      final intent = PendingRename(
        from: before.filename,
        to: entry.newFilename,
        url: entry.newUrl,
      );

      try {
        // Written before the rename, not after: only an entry that pre-dates the
        // write can cover the process dying during it.
        await journal.record(intent);

        var updated = before.copyWith(
          filename: entry.newFilename,
          url: entry.newUrl,
        );

        // Disk only. The rows move once the file is known to be there.
        await fileManager.renameFileOnDisk(before, entry.newFilename);

        // Waveform, beat map, blurred art, lyrics and the one filename-keyed
        // cover file all have to follow, and the video/FFmpeg cover is the only
        // cover that is named after the song — so this is also the one case
        // where the song has to be told where its cover went.
        final movedCover = await cache.transferSongCaches(
          before: before,
          after: updated,
        );
        if (movedCover != null) {
          updated = updated.copyWith(coverUrl: movedCover);
        }

        applied.add((previousFilename: before.filename, updated: updated));
      } on FileSystemException catch (e) {
        failures.add(BulkRenameFailure(before.filename, e.message));
        await journal.discard(intent);
      } catch (e) {
        failures.add(BulkRenameFailure(before.filename, '$e'));
        await journal.discard(intent);
      }

      if (applied.length - committed >= _commitSlice) await commit();

      onProgress?.call('Renaming files', i + 1, actionable.length);
    }

    if (applied.isEmpty) {
      await journal.clear();
      notifier.error('Rename failed');
      return BulkRenameResult(
        renamed: const [],
        remaps: const {},
        failures: failures,
      );
    }

    onProgress?.call('Updating library', 0, 1);
    await commit();
    onProgress?.call('Updating library', 1, 1);

    // Once, not per slice: a refresh rebuilds the recommendation playlists, and
    // nobody is looking at the library from behind a full-screen rename.
    ref.read(userDataProvider.notifier).refresh();

    if (stoppedEarly) {
      notifier.success('Stopped after ${applied.length} songs');
    } else {
      notifier.success(
        failures.isEmpty
            ? 'Renamed ${applied.length} songs'
            : 'Renamed ${applied.length}, ${failures.length} failed',
      );
    }

    return BulkRenameResult(
      renamed: [for (final item in applied) item.updated],
      remaps: {
        for (final item in applied)
          item.previousFilename: item.updated.filename,
      },
      failures: failures,
      stoppedEarly: stoppedEarly,
    );
  }

  /// Points the search index at the new filenames.
  ///
  /// Moves the existing rows rather than re-upserting them: a rename changes
  /// the key and none of the indexed content, so re-inserting would make every
  /// song with lyrics re-extract them from disk — one ffprobe process each,
  /// which on a large batch dominated the whole operation.
  Future<void> _reindexRenames(Map<String, String> remaps) async {
    if (remaps.isEmpty) return;
    try {
      final searchService = ref.read(searchServiceProvider);
      await searchService.init();
      await searchService.renameFiles([
        for (final entry in remaps.entries) (from: entry.key, to: entry.value),
      ]);
    } catch (e) {
      // The index is rebuilt on the next scan, so a failed reindex costs a stale
      // search result rather than any data.
      debugPrint('Search index rename failed for ${remaps.length} songs: $e');
    }
  }

  /// Swaps [song]'s audio file for the one [accepted] describes, carrying
  /// every filename-keyed record onto it, and returns the song under its new
  /// identity.
  Future<Song> replaceSongFile(
    Song song,
    ReplacementAccepted accepted, {
    required OriginalFileDisposition disposition,
  }) async {
    final replaced = await _installReplacementFile(song, accepted);
    await _disposeOriginalSong(song, disposition);
    return replaced;
  }

  /// Copies the replacement in, reads what it says about itself, and moves
  /// every filename-keyed record onto it.
  ///
  /// The ordering is the design, not an implementation detail. The copy lands
  /// first because the replacement's metadata can only be read off disk, and is
  /// read from the destination so the read sees the file where it will live.
  /// The databases move next, while the original is still the song every
  /// filename-keyed record points at.
  ///
  /// So a failure anywhere in here leaves the original completely intact with
  /// at most a stray copy to discard.
  Future<Song> _installReplacementFile(
    Song song,
    ReplacementAccepted accepted,
  ) async {
    final notifier = ref.read(metadataSaveProvider.notifier);
    notifier.start();

    var copyWritten = false;
    var libraryMovedToCopy = false;

    try {
      final fileManager = ref.read(fileManagerServiceProvider);
      await fileManager.copySongFile(
        accepted.sourcePath,
        accepted.destinationPath,
      );
      copyWritten = true;

      final read = await ScannerService.readSongMetadata(
        File(accepted.destinationPath),
        existingSong: song,
      );

      // Whatever the file states about itself is taken from the file, whole:
      // tags, duration, cover art, embedded lyrics, release year. What the
      // file cannot know — when it joined the library, how often it was played
      // — stays with the song, since that is the thing being carried over.
      final replaced = Song(
        title: read.title,
        artist: read.artist,
        album: read.album,
        filename: accepted.newFilename,
        url: accepted.destinationPath,
        coverUrl: read.coverUrl,
        hasLyrics: read.hasLyrics,
        playCount: song.playCount,
        duration: read.duration,
        mtime: read.mtime,
        createdEpochSec: song.createdEpochSec,
        songDateEpochSec: read.songDateEpochSec,
      );

      // Play history, favourites, playlists, merged groups, saved queues,
      // translations and cover lookups all move here, across both databases.
      await DatabaseService.instance
          .renameFile(song.filename, accepted.newFilename);
      libraryMovedToCopy = true;

      // Keyed off the old file's URL, which nothing will ever read again.
      await ref.read(songRepositoryProvider).invalidateLyricsCache(song);

      await _applyLocalSongUpdate(replaced, previousFilename: song.filename);
      ref.read(userDataProvider.notifier).refresh();

      notifier.success('Song replaced');
      return replaced;
    } catch (e) {
      // Only while nothing points at the copy: past that it *is* the song.
      if (copyWritten && !libraryMovedToCopy) {
        await _discardReplacementCopy(accepted.destinationPath);
      }
      notifier.error('Failed to replace song');
      debugPrint('Failed to replace song: $e');
      rethrow;
    }
  }

  /// Gets rid of, or hides, the file the replacement superseded.
  ///
  /// Deliberately outside the replacement's own failure handling: the swap has
  /// already succeeded by now, so a leftover original is a cleanup problem to
  /// report, not a reason to fail it. An original that has since vanished
  /// counts as disposed — which is why nothing here propagates.
  Future<void> _disposeOriginalSong(
    Song song,
    OriginalFileDisposition disposition,
  ) async {
    final userData = ref.read(userDataProvider.notifier);
    try {
      switch (disposition) {
        case OriginalFileDisposition.delete:
          await ref.read(fileManagerServiceProvider).deleteSongFile(song);
          await DatabaseService.instance.deleteFile(song.filename);
          await userData.refresh();
        case OriginalFileDisposition.hide:
          await userData.toggleHidden(song.filename);
      }
    } catch (e) {
      debugPrint('Could not dispose of ${song.filename}: $e');
      ref
          .read(metadataSaveProvider.notifier)
          .error('Song replaced, but the original could not be cleaned up');
    }
  }

  /// Removes a replacement copy that never became the song.
  ///
  /// Best effort by design — on Android the destination may sit behind a
  /// document provider, where a raw delete can fail, and a stray file is a much
  /// smaller problem than a half-finished replacement.
  Future<void> _discardReplacementCopy(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (e) {
      debugPrint('Could not discard replacement copy $path: $e');
    }
  }

  Future<void> updateSongTitle(Song song, String newTitle) async {
    await updateSongMetadata(song, newTitle, song.artist, song.album);
  }

  Future<void> updateSongMetadata(
      Song song, String title, String artist, String album) async {
    final notifier = ref.read(metadataSaveProvider.notifier);
    notifier.start();
    try {
      await ref
          .read(fileManagerServiceProvider)
          .updateSongMetadata(song, title, artist, album);

      final updated = song.copyWith(
        title: title,
        artist: artist,
        album: album,
        mtime: await _statMtime(song.url, song.mtime),
      );
      await _applyLocalSongUpdate(updated);
      notifier.success();
    } catch (e) {
      notifier.error();
      debugPrint('Failed to update song metadata: $e');
      rethrow;
    }
  }

  Future<void> updateSongCover(Song song, String? imagePath) async {
    final notifier = ref.read(metadataSaveProvider.notifier);
    notifier.start();
    try {
      // Deliberately no stop-the-player step: the write swaps the file in via
      // rename, so anything holding it open keeps reading the old bytes.
      final newCoverPath = await ref
          .read(fileManagerServiceProvider)
          .updateSongCover(song, imagePath);

      final fileMtime = await _statMtime(song.url, song.mtime);
      final coverRevision = fileMtime == null
          ? DateTime.now().millisecondsSinceEpoch / 1000.0
          : (song.mtime != null && fileMtime <= song.mtime!)
              ? song.mtime! + 0.001
              : fileMtime;
      final updated = song.copyWith(
        coverUrl: newCoverPath,
        clearCoverUrl: newCoverPath == null,
        mtime: coverRevision,
      );

      // Evict old and new covers from Flutter's decoded-image cache so the next
      // `Image.file` reads the new bytes off disk.
      if (song.coverUrl != null) {
        await CoverRefreshService.evictCoverFromImageCache(song.coverUrl!);
      }
      if (newCoverPath != null && newCoverPath != song.coverUrl) {
        await CoverRefreshService.evictCoverFromImageCache(newCoverPath);
      }

      // Wipe the blurred background cache so the player re-renders the
      // backdrop from the new artwork on the next display.
      unawaited(CacheService.instance.invalidateBlurredCache(song.filename));

      // Before publishing, so the queue rebuild and the cover warmer both see
      // the new artwork rather than re-reading the crop of the old one.
      await _rebuildNotificationCover(song, updated);
      await _applyLocalSongUpdate(updated);

      _refreshPaletteIfPlaying(updated);

      notifier.success('Cover updated successfully');
    } catch (e) {
      notifier.error('Failed to update cover');
      debugPrint('Failed to update song cover: $e');
      rethrow;
    }
  }

  /// Replaces the square crop shown on the lock screen, which is cached
  /// separately from the extracted cover that FileManagerService has already
  /// rewritten.
  ///
  /// Regenerated rather than merely deleted: the notification's art URI is
  /// baked into the queue entry, and a metadata-only edit deliberately does not
  /// rebuild the queue, so the file has to reappear at the same path or the
  /// currently playing track loses its artwork entirely. Even so, the
  /// notification for the track playing right now may keep showing the old
  /// image until the next track change — Android caches the decoded bitmap, and
  /// pushing a new one would mean re-preparing the audio source.
  Future<void> _rebuildNotificationCover(Song previous, Song updated) async {
    try {
      // The cache is keyed off the cover file's name, so the old and new
      // artwork can land under different keys. Clear both: the old one is now
      // orphaned, and the new one may be a stale entry from a previous cover
      // that happened to share a name.
      for (final key in {
        FileManagerService.notificationCoverKey(previous),
        FileManagerService.notificationCoverKey(updated),
      }) {
        if (key != null) {
          await CacheService.instance.invalidateNotificationCover(key);
        }
      }

      await ref.read(fileManagerServiceProvider).getOrCreateNotificationCover(
            updated,
            ref.read(settingsProvider).coverSizingMode,
          );
    } catch (e) {
      debugPrint(
          'Notification cover rebuild failed for ${updated.filename}: $e');
    }
  }

  /// Re-derives the player accent when the song whose cover just changed is the
  /// one on screen. Without this the player keeps the colour of the old art.
  void _refreshPaletteIfPlaying(Song song) {
    final current =
        ref.read(audioPlayerManagerProvider).currentSongNotifier.value;
    if (current?.filename != song.filename) return;

    ColorExtractionService.extractPalette(song.coverUrl, useIsolate: true)
        .then((palette) {
      // Extraction runs in an isolate, so the container may be gone by now.
      if (!ref.mounted) return;
      ref
          .read(themeProvider.notifier)
          .updateExtractedPalette(palette, forFilename: song.filename);
    });
  }

  Future<void> updateLyrics(Song song, String lyricsContent) async {
    final notifier = ref.read(metadataSaveProvider.notifier);
    notifier.start();
    try {
      try {
        await ref
            .read(fileManagerServiceProvider)
            .updateLyrics(song, lyricsContent);
        await ref.read(songRepositoryProvider).invalidateLyricsCache(song);
      } catch (e) {
        debugPrint(
            'File lyrics embedding failed, falling back to local cache: $e');
        await ref
            .read(songRepositoryProvider)
            .saveLyricsToCache(song, lyricsContent);
      }

      final updated = song.copyWith(
        hasLyrics: lyricsContent.trim().isNotEmpty,
        mtime: await _statMtime(song.url, song.mtime),
      );
      await _applyLocalSongUpdate(updated);

      // Wakes up any lyrics view already showing this song — the pane otherwise
      // only reloads when the track changes.
      ref.read(lyricsRevisionProvider.notifier).bump();
      notifier.success('Lyrics saved');
    } catch (e) {
      notifier.error('Failed to save lyrics');
      debugPrint('Failed to update lyrics: $e');
      rethrow;
    }
  }

  Future<void> moveSong(Song song, String targetDirectoryPath) async {
    if (kDebugMode) {
      debugPrint("MOVE_SONG: Starting move for ${song.title}");
      debugPrint("MOVE_SONG: Source: ${song.url}");
      debugPrint("MOVE_SONG: Target Dir: $targetDirectoryPath");
    }

    try {
      final oldFile = File(song.url);
      if (!await oldFile.exists()) {
        if (kDebugMode) {
          debugPrint("MOVE_SONG: ERROR - Source file does not exist");
        }
        return;
      }

      final newPath = p.join(targetDirectoryPath, song.filename);
      if (kDebugMode) debugPrint("MOVE_SONG: Target Path: $newPath");

      if (p.equals(oldFile.path, newPath)) {
        if (kDebugMode) {
          debugPrint("MOVE_SONG: Source and target are identical, skipping");
        }
        return;
      }

      // Ensure target directory exists
      final targetDir = Directory(targetDirectoryPath);
      if (!await targetDir.exists()) {
        if (kDebugMode) {
          debugPrint(
              "MOVE_SONG: Creating target directory: $targetDirectoryPath");
        }
        await targetDir.create(recursive: true);
      }

      if (kDebugMode) {
        debugPrint("MOVE_SONG: Executing rename...");
      }
      // Cross-platform safe move
      try {
        await oldFile.rename(newPath);
      } catch (e) {
        if (kDebugMode) {
          debugPrint("MOVE_SONG: Rename failed, trying copy/delete: $e");
        }
        await oldFile.copy(newPath);
        await oldFile.delete();
      }
      if (kDebugMode) {
        debugPrint("MOVE_SONG: Move successful");
      }

      if (kDebugMode) {
        debugPrint("MOVE_SONG: Refreshing provider...");
      }
      await refresh();
      if (kDebugMode) {
        debugPrint("MOVE_SONG: Finished");
      }
    } catch (e, stack) {
      debugPrint('MOVE_SONG: ERROR: $e');
      if (kDebugMode) {
        debugPrint('MOVE_SONG: STACKTRACE: $stack');
      }
      rethrow;
    }
  }

  Future<void> moveFolder(String oldFolderPath, String targetParentPath) async {
    if (kDebugMode) {
      debugPrint("MOVE_FOLDER: Starting move for $oldFolderPath");
      debugPrint("MOVE_FOLDER: Target Parent: $targetParentPath");
    }

    try {
      final oldDir = Directory(oldFolderPath);
      if (!await oldDir.exists()) {
        if (kDebugMode) {
          debugPrint("MOVE_FOLDER: ERROR - Source directory does not exist");
        }
        return;
      }

      final folderName = p.basename(oldFolderPath);
      final newPath = p.join(targetParentPath, folderName);
      if (kDebugMode) {
        debugPrint("MOVE_FOLDER: New Path: $newPath");
      }

      if (p.equals(oldDir.path, newPath)) {
        if (kDebugMode) {
          debugPrint("MOVE_FOLDER: Source and target are identical, skipping");
        }
        return;
      }

      if (p.isWithin(oldDir.path, targetParentPath)) {
        if (kDebugMode) {
          debugPrint("MOVE_FOLDER: ERROR - Cannot move folder into itself");
        }
        throw Exception("Cannot move a folder into itself or its subfolders");
      }

      // Ensure target parent exists
      final targetParentDir = Directory(targetParentPath);
      if (!await targetParentDir.exists()) {
        if (kDebugMode) {
          debugPrint("MOVE_FOLDER: Creating target parent: $targetParentPath");
        }
        await targetParentDir.create(recursive: true);
      }

      if (kDebugMode) {
        debugPrint("MOVE_FOLDER: Executing rename...");
      }
      try {
        await oldDir.rename(newPath);
      } catch (e) {
        if (kDebugMode) {
          debugPrint("MOVE_FOLDER: Rename failed, trying recursive move: $e");
        }
        // Fallback for cross-device moves or other issues
        final newDir = Directory(newPath);
        await newDir.create(recursive: true);
        await for (final entity in oldDir.list(recursive: false)) {
          final name = p.basename(entity.path);
          if (entity is File) {
            await entity.copy(p.join(newPath, name));
            await entity.delete();
          } else if (entity is Directory) {
            // Simple recursive call or handle nested
            // For now, let's keep it simple as most moves are on same device
          }
        }
        await oldDir.delete(recursive: true);
      }
      if (kDebugMode) {
        debugPrint("MOVE_FOLDER: Rename successful");
      }

      if (kDebugMode) {
        debugPrint("MOVE_FOLDER: Refreshing provider...");
      }
      await refresh();
      if (kDebugMode) {
        debugPrint("MOVE_FOLDER: Finished");
      }
    } catch (e, stack) {
      debugPrint('MOVE_FOLDER: ERROR: $e');
      if (kDebugMode) {
        debugPrint('MOVE_FOLDER: STACKTRACE: $stack');
      }
      rethrow;
    }
  }
}

@visibleForTesting
Song extractFeatFromSong(Song song) {
  final regex = RegExp(
    r'\s*[\(\[]?\s*(?:feat\.?|ft\.?|featuring)\s+([^\)\]\(\[\n]+?)\s*[\)\]]?\s*$',
    caseSensitive: false,
  );
  final match = regex.firstMatch(song.title);
  if (match == null) return song;

  final featArtist = match.group(1)!.trim();
  final cleanTitle = song.title.substring(0, match.start).trim();
  if (cleanTitle.isEmpty) return song;

  final newArtist = song.artist == 'Unknown Artist'
      ? featArtist
      : '${song.artist}, $featArtist';

  return Song(
    title: cleanTitle,
    artist: newArtist,
    album: song.album,
    filename: song.filename,
    url: song.url,
    coverUrl: song.coverUrl,
    hasLyrics: song.hasLyrics,
    playCount: song.playCount,
    duration: song.duration,
    mtime: song.mtime,
    createdEpochSec: song.createdEpochSec,
    songDateEpochSec: song.songDateEpochSec,
  );
}

final songsProvider =
    AsyncNotifierProvider<SongsNotifier, List<Song>>(SongsNotifier.new);

/// Filename -> song lookup over the loaded library. Anything that resolves a
/// stored filename list (queue snapshots, playlists, backups) should watch this
/// rather than rebuilding its own map per widget.
final songsByFilenameProvider = Provider<Map<String, Song>>((ref) {
  final songsAsync = ref.watch(songsProvider);
  if (songsAsync is AsyncData<List<Song>>) {
    return {for (final song in songsAsync.value) song.filename: song};
  }
  return const {};
});

final recommendationsProvider = Provider<List<Song>>((ref) {
  final userData = ref.watch(userDataProvider);
  final songsAsync = ref.watch(songsProvider);

  if (songsAsync is! AsyncData || songsAsync.value == null) {
    return [];
  }

  final allSongs = songsAsync.value!;
  final quickPicks = userData.playlists
      .where((p) => p.id == 'quick_picks' && p.isRecommendation)
      .firstOrNull;

  if (quickPicks == null) return [];

  final songByFilename = {for (final s in allSongs) s.filename: s};
  return quickPicks.songs
      .map((ps) => songByFilename[ps.songFilename])
      .whereType<Song>()
      .toList();
});

final playCountsProvider = Provider<Map<String, int>>((ref) {
  final songsAsync = ref.watch(songsProvider);
  if (songsAsync is AsyncData<List<Song>>) {
    return {
      for (final song in songsAsync.value) song.filename: song.playCount,
    };
  }

  return const {};
});

final lastPlayedTimestampsProvider =
    FutureProvider<Map<String, double>>((ref) async {
  ref.watch(songsProvider);
  return DatabaseService.instance.getLastPlayedTimestamps();
});

/// Per-song taste scores, the same model the shuffle engine picks from.
///
/// Exposed so the library's "Recommended" sort ranks by exactly what shuffle
/// plays — the two used to run separate, disagreeing scoring functions.
final songAffinitiesProvider =
    FutureProvider<Map<String, SongAffinity>>((ref) async {
  ref.watch(songsProvider);
  final userData = ref.watch(userDataProvider);

  final events = await DatabaseService.instance.getAffinityEvents();
  return computeAffinities(
    events: [
      for (final e in events)
        PlayEventRecord(
          filename: e.filename,
          timestamp: e.timestamp,
          playRatio: e.playRatio,
        ),
    ],
    now: DateTime.now(),
    favorites: userData.favorites.toSet(),
  );
});

/// Folder the library tree is rooted at, resolved from the configured music
/// folders and the scanned songs (see [LibraryLogic.resolveLibraryRoot]).
///
/// This is a provider rather than a `FutureBuilder` inside the library screen on
/// purpose: the screen rebuilds on every song, play-count and user-data change,
/// and a per-build future reset the folder tab to its "no music folder" state
/// for as long as the lookup was in flight — which is what made the library
/// intermittently look empty while home still listed everything.
final libraryRootPathProvider = Provider<AsyncValue<String?>>((ref) {
  final foldersAsync = ref.watch(musicFoldersProvider);
  final songs = ref.watch(songsProvider).value ?? const <Song>[];

  return foldersAsync.whenData(
    (folders) => LibraryLogic.resolveLibraryRoot(
      allSongs: songs,
      configuredFolders: [
        for (final folder in folders) folder['path'] ?? '',
      ],
    ),
  );
});

final artistMapProvider = Provider<Map<String, List<Song>>>((ref) {
  final songs = ref.watch(songsProvider).value ?? const <Song>[];
  if (songs.isEmpty) return const {};
  return LibraryLogic.groupByArtist(songs);
});

final albumMapProvider = Provider<Map<String, List<Song>>>((ref) {
  final songs = ref.watch(songsProvider).value ?? const <Song>[];
  if (songs.isEmpty) return const {};
  return LibraryLogic.groupByAlbum(songs);
});

final artistListProvider = Provider<List<String>>((ref) {
  final artistMap = ref.watch(artistMapProvider);
  if (artistMap.isNotEmpty) {
    return LibraryLogic.sortArtistsByTrackCount(artistMap);
  }
  return const [];
});

final albumListProvider = Provider<List<String>>((ref) {
  final albumMap = ref.watch(albumMapProvider);
  if (albumMap.isNotEmpty) {
    return LibraryLogic.sortAlbumsByTrackCount(albumMap);
  }
  return const [];
});

final userDataProvider = NotifierProvider<UserDataNotifier, UserDataState>(() {
  return UserDataNotifier();
});
