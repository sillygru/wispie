import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/song_identity_repository.dart';
import '../data/repositories/song_repository.dart';
import '../models/song.dart';
import '../providers/artist_album_art_provider.dart';
import '../services/cache_service.dart';
import '../services/color_extraction_service.dart';
import '../services/cover_refresh_service.dart';
import '../services/database_optimizer_service.dart';
import '../services/database_service.dart';
import '../services/ffmpeg_service.dart';
import '../services/library_repair_service.dart';
import '../services/passive_art_fetcher_service.dart';
import '../services/scanner_service.dart';
import '../services/song_identity_service.dart';
import '../services/waveform_service.dart';
import 'providers.dart';
import 'search_provider.dart';

enum IndexerOperationState {
  idle,
  running,
  stopping,
  completed,
  cancelled,
  error
}

class IndexerOps {
  static const optimizeDatabases = 'optimize_databases';
  static const repairLibraryLinks = 'repair_library_links';
  static const matchSongIdentity = 'match_song_identity';
  static const coverCache = 'rebuild_cover_caches';
  static const searchIndex = 'rebuild_search_indexes';
  static const lyricsCache = 'rebuild_lyrics_cache';
  static const waveformCache = 'rebuild_waveform_cache';
  static const colorCache = 'rebuild_color_cache';
  static const blurredCache = 'rebuild_blurred_cache';
  static const recommendations = 'rebuild_recommendations';
  static const artistAlbumArt = 'rebuild_artist_album_art';

  /// One-shot tasks: nothing to count, no "just missing" mode.
  static const tasks = {optimizeDatabases, repairLibraryLinks, recommendations};
  static const blocking = {optimizeDatabases, repairLibraryLinks};
  static const all = [
    optimizeDatabases,
    repairLibraryLinks,
    matchSongIdentity,
    coverCache,
    searchIndex,
    lyricsCache,
    waveformCache,
    colorCache,
    blurredCache,
    recommendations,
    artistAlbumArt,
  ];
}

const _unset = Object();

/// Coverage (`doneCount`/`totalCount`) describes what is on disk right now and
/// is only ever written by a count pass. Run progress (`run*`) describes the
/// current or last run. Mixing the two is what made the old bars start at
/// numbers like 900/100.
class IndexerOperation {
  final String id;
  final IndexerOperationState state;
  final bool countsLoaded;
  final int doneCount;
  final int totalCount;
  final int runDone;
  final int runTotal;
  final double? runFraction;
  final int artistRunDone;
  final int artistRunTotal;
  final int albumRunDone;
  final int albumRunTotal;
  final List<String> failedItems;
  final String? errorMessage;

  const IndexerOperation({
    required this.id,
    this.state = IndexerOperationState.idle,
    this.countsLoaded = false,
    this.doneCount = 0,
    this.totalCount = 0,
    this.runDone = 0,
    this.runTotal = 0,
    this.runFraction,
    this.artistRunDone = 0,
    this.artistRunTotal = 0,
    this.albumRunDone = 0,
    this.albumRunTotal = 0,
    this.failedItems = const [],
    this.errorMessage,
  });

  IndexerOperation copyWith({
    IndexerOperationState? state,
    bool? countsLoaded,
    int? doneCount,
    int? totalCount,
    int? runDone,
    int? runTotal,
    Object? runFraction = _unset,
    int? artistRunDone,
    int? artistRunTotal,
    int? albumRunDone,
    int? albumRunTotal,
    List<String>? failedItems,
    Object? errorMessage = _unset,
  }) {
    return IndexerOperation(
      id: id,
      state: state ?? this.state,
      countsLoaded: countsLoaded ?? this.countsLoaded,
      doneCount: doneCount ?? this.doneCount,
      totalCount: totalCount ?? this.totalCount,
      runDone: runDone ?? this.runDone,
      runTotal: runTotal ?? this.runTotal,
      runFraction: identical(runFraction, _unset)
          ? this.runFraction
          : runFraction as double?,
      artistRunDone: artistRunDone ?? this.artistRunDone,
      artistRunTotal: artistRunTotal ?? this.artistRunTotal,
      albumRunDone: albumRunDone ?? this.albumRunDone,
      albumRunTotal: albumRunTotal ?? this.albumRunTotal,
      failedItems: failedItems ?? this.failedItems,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  bool get isTask => IndexerOps.tasks.contains(id);
  bool get isBlocking => IndexerOps.blocking.contains(id);
  bool get requiresRestart => id == IndexerOps.optimizeDatabases;
  bool get isRunning =>
      state == IndexerOperationState.running ||
      state == IndexerOperationState.stopping;
  bool get hasSplitArtProgress => id == IndexerOps.artistAlbumArt;
  int get failedCount => failedItems.length;
  int get pendingCount => math.max(0, totalCount - doneCount);
  bool get isFullyCached =>
      !isTask && countsLoaded && totalCount > 0 && doneCount >= totalCount;

  /// Null means indeterminate.
  double? get progress {
    if (runTotal > 0) return (runDone / runTotal).clamp(0.0, 1.0);
    return runFraction?.clamp(0.0, 1.0);
  }

  static double _ratio(int a, int b) => b > 0 ? (a / b).clamp(0.0, 1.0) : 0.0;
  double get artistProgress => _ratio(artistRunDone, artistRunTotal);
  double get albumProgress => _ratio(albumRunDone, albumRunTotal);
}

class IndexerState {
  final Map<String, IndexerOperation> operations;

  const IndexerState({this.operations = const {}});

  IndexerOperation? getOperation(String id) => operations[id];
}

class IndexerResult {
  final bool success;
  final bool cancelled;
  final int processed;
  final int total;
  final int failed;
  final String? error;
  final bool requiresRestart;

  const IndexerResult({
    required this.success,
    this.cancelled = false,
    this.processed = 0,
    this.total = 0,
    this.failed = 0,
    this.error,
    this.requiresRestart = false,
  });
}

class CancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
}

/// Progress for one run. Emissions are throttled: per-item state pushes
/// rebuild the whole screen and made fast passes crawl.
class _Run {
  final IndexerNotifier _owner;
  final String id;
  final CancelToken token;
  int done = 0;
  int total = 0;
  final List<String> failed = [];
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  _Run(this._owner, this.id, this.token);

  bool get cancelled => token.isCancelled;

  void start(int count) {
    total = count;
    done = 0;
    flush();
  }

  void tick({String? failedItem}) {
    if (failedItem != null) failed.add(failedItem);
    report(done + 1, total);
  }

  void report(int newDone, int newTotal) {
    done = newDone;
    total = newTotal;
    final now = DateTime.now();
    if (done >= total || now.difference(_lastEmit).inMilliseconds >= 120) {
      _lastEmit = now;
      flush();
    }
  }

  void flush() {
    _owner._patch(
      id,
      (op) => op.copyWith(
        runDone: done,
        runTotal: total,
        failedItems: List.unmodifiable(failed),
      ),
    );
  }

  IndexerResult result({String? error}) => IndexerResult(
        success: error == null,
        cancelled: cancelled,
        processed: done,
        total: total,
        failed: failed.length,
        error: error,
      );
}

/// Checks run concurrently in small batches: sequential awaits over a large
/// library took long enough to look like a stall.
Future<List<T>> _whereAsync<T>(
  Iterable<T> items,
  Future<bool> Function(T) test,
) async {
  final list = items.toList();
  final out = <T>[];
  const batch = 48;
  for (var i = 0; i < list.length; i += batch) {
    final chunk = list.sublist(i, math.min(i + batch, list.length));
    final hits = await Future.wait(
      chunk.map((e) async {
        try {
          return await test(e);
        } catch (_) {
          return false;
        }
      }),
    );
    for (var j = 0; j < chunk.length; j++) {
      if (hits[j]) out.add(chunk[j]);
    }
  }
  return out;
}

Future<bool> _nonEmptyFile(String? path) async {
  if (path == null || path.isEmpty) return false;
  final file = File(path);
  return await file.exists() && await file.length() > 0;
}

/// What a cache-type operation needs to do for the current library.
class _Plan<T> {
  final List<T> all;
  final List<T> pending;
  const _Plan(this.all, this.pending);
}

class IndexerNotifier extends Notifier<IndexerState> {
  final Map<String, CancelToken> _tokens = {};
  Future<void>? _counting;

  @override
  IndexerState build() => IndexerState(operations: {
        for (final id in IndexerOps.all) id: IndexerOperation(id: id),
      });

  void _patch(String id, IndexerOperation Function(IndexerOperation) f) {
    final op = state.operations[id];
    if (op == null) return;
    state = IndexerState(operations: {...state.operations, id: f(op)});
  }

  bool get anyRunning => state.operations.values.any((o) => o.isRunning);

  /// Coalesces concurrent requests so reopening the screen mid-count does not
  /// start a second full pass.
  Future<void> loadCounts() => _counting ??= _loadCounts().whenComplete(() {
        _counting = null;
      });

  Future<void> _loadCounts() async {
    final songs = await DatabaseService.instance.getAllSongs();
    Future<void> count(String id, Future<(int, int)> Function() f) async {
      try {
        final (done, total) = await f();
        _patch(
          id,
          (op) => op.copyWith(
            countsLoaded: true,
            doneCount: done,
            totalCount: total,
          ),
        );
      } catch (_) {
        _patch(id, (op) => op.copyWith(countsLoaded: true));
      }
    }

    (int, int) fromPlan(_Plan p) =>
        (p.all.length - p.pending.length, p.all.length);

    await Future.wait([
      count(IndexerOps.matchSongIdentity, () async {
        final known = await _identityFilenames();
        return (
          songs.where((s) => known.contains(s.filename)).length,
          songs.length
        );
      }),
      count(IndexerOps.coverCache,
          () async => fromPlan(await _coverPlan(songs, force: false))),
      count(IndexerOps.searchIndex, () async {
        final indexed =
            await ref.read(searchServiceProvider).indexedFilenames();
        return (
          songs.where((s) => indexed.contains(s.filename)).length,
          songs.length
        );
      }),
      count(IndexerOps.lyricsCache,
          () async => fromPlan(await _lyricsPlan(songs, force: false))),
      count(IndexerOps.waveformCache,
          () async => fromPlan(await _waveformPlan(songs, force: false))),
      count(IndexerOps.colorCache,
          () async => fromPlan(await _colorPlan(songs, force: false))),
      count(IndexerOps.blurredCache,
          () async => fromPlan(await _blurredPlan(songs, force: false))),
      count(IndexerOps.artistAlbumArt, () async {
        final c = await _artCoverage();
        final total = c.artistTotal + c.albumTotal;
        return (total - c.artistPending - c.albumPending, total);
      }),
    ]);
    for (final id in IndexerOps.tasks) {
      _patch(id, (op) => op.copyWith(countsLoaded: true));
    }
  }

  Future<IndexerResult> startOperation(
    String id, {
    bool force = false,
    Set<String>? onlyItems,
  }) async {
    final op = state.operations[id];
    if (op == null) return const IndexerResult(success: false);
    if (op.isRunning) return const IndexerResult(success: false);

    final token = CancelToken();
    _tokens[id] = token;
    final run = _Run(this, id, token);
    _patch(
      id,
      (op) => op.copyWith(
        state: IndexerOperationState.running,
        runDone: 0,
        runTotal: 0,
        runFraction: null,
        artistRunDone: 0,
        artistRunTotal: 0,
        albumRunDone: 0,
        albumRunTotal: 0,
        failedItems: const [],
        errorMessage: null,
      ),
    );

    IndexerResult result;
    try {
      result = await _execute(id, run, force: force, only: onlyItems);
    } catch (e) {
      result = run.result(error: e.toString());
    }
    run.flush();
    _tokens.remove(id);

    final next = result.cancelled
        ? IndexerOperationState.cancelled
        : result.success
            ? IndexerOperationState.completed
            : IndexerOperationState.error;
    _patch(
      id,
      (op) => op.copyWith(state: next, errorMessage: result.error),
    );
    unawaited(loadCounts());
    return result;
  }

  void cancelOperation(String id) {
    final token = _tokens[id];
    if (token == null || token.isCancelled) return;
    token.cancel();
    _patch(id, (op) => op.copyWith(state: IndexerOperationState.stopping));
  }

  void _invalidateLibrary() => ref.invalidate(songsProvider);

  Future<IndexerResult> _execute(
    String id,
    _Run run, {
    required bool force,
    Set<String>? only,
  }) async {
    switch (id) {
      case IndexerOps.optimizeDatabases:
        return _optimizeDatabases(run);
      case IndexerOps.repairLibraryLinks:
        return _repairLibraryLinks(run);
      case IndexerOps.recommendations:
        return _rebuildRecommendations(run);
      case IndexerOps.artistAlbumArt:
        return _rebuildArtistAlbumArt(run, force: force);
    }

    final songs = await DatabaseService.instance.getAllSongs();
    List<Song> scoped(List<Song> list) => only == null
        ? list
        : list.where((s) => only.contains(s.filename)).toList();

    switch (id) {
      case IndexerOps.matchSongIdentity:
        return _matchSongIdentity(run, songs, force: force || only != null);
      case IndexerOps.searchIndex:
        return _rebuildSearchIndex(run, songs, force: force);
      case IndexerOps.coverCache:
        final plan = await _coverPlan(songs, force: force);
        return _rebuildCovers(run, scoped(plan.pending), force: force);
      case IndexerOps.lyricsCache:
        final plan = await _lyricsPlan(songs, force: force);
        return _rebuildLyrics(run, scoped(plan.pending), force: force);
      case IndexerOps.waveformCache:
        final plan = await _waveformPlan(songs, force: force);
        return _rebuildWaveforms(run, scoped(plan.pending), force: force);
      case IndexerOps.colorCache:
        final plan = await _colorPlan(songs, force: force);
        final pending = only == null
            ? plan.pending
            : plan.pending.where(only.contains).toList();
        return _rebuildColors(run, pending, force: force);
      case IndexerOps.blurredCache:
        final plan = await _blurredPlan(songs, force: force);
        return _rebuildBlurred(run, scoped(plan.pending));
    }
    return const IndexerResult(success: false);
  }

  // ---------------------------------------------------------------- plans --
  // Each plan is the single definition of "done" for its cache, shared by the
  // idle count and the run so the two can never disagree.

  Future<_Plan<Song>> _coverPlan(List<Song> songs,
      {required bool force}) async {
    if (force) return _Plan(songs, songs);
    // A recorded miss means the file was checked and has no art; counting it
    // as pending would keep the cache from ever reading as complete.
    final misses = await DatabaseService.instance.getCoverMisses();
    final pending = await _whereAsync(songs, (s) async {
      if (misses.containsKey(s.filename)) return false;
      return !await _nonEmptyFile(s.coverUrl);
    });
    return _Plan(songs, pending);
  }

  Future<_Plan<Song>> _lyricsPlan(List<Song> songs,
      {required bool force}) async {
    if (force) return _Plan(songs, songs);
    final repo = SongRepository();
    return _Plan(
      songs,
      await _whereAsync(songs, (s) async => !await repo.hasLyricsCacheEntry(s)),
    );
  }

  Future<_Plan<Song>> _waveformPlan(List<Song> songs,
      {required bool force}) async {
    if (force) return _Plan(songs, songs);
    final cache = CacheService.instance;
    return _Plan(
      songs,
      await _whereAsync(songs, (s) async {
        final f = await cache.getWaveformCacheFile(s.filename);
        return !await f.exists();
      }),
    );
  }

  /// Palettes are keyed by image path, and many songs share one cover, so the
  /// unit here is a distinct cover file, not a song.
  Future<_Plan<String>> _colorPlan(List<Song> songs,
      {required bool force}) async {
    final paths = await _whereAsync(
      {for (final s in songs) s.coverUrl ?? ''}.where((p) => p.isNotEmpty),
      _nonEmptyFile,
    );
    if (force) return _Plan(paths, paths);
    await ColorExtractionService.init();
    return _Plan(
      paths,
      await _whereAsync(paths,
          (p) async => !await ColorExtractionService.hasCachedPalette(p)),
    );
  }

  /// Only songs with a cover on disk can have a blurred background at all.
  Future<_Plan<Song>> _blurredPlan(List<Song> songs,
      {required bool force}) async {
    final withCover =
        await _whereAsync(songs, (s) => _nonEmptyFile(s.coverUrl));
    if (force) return _Plan(withCover, withCover);
    final cache = CacheService.instance;
    return _Plan(
      withCover,
      await _whereAsync(withCover, (s) async {
        final f = await cache.getBlurredCacheFile(s.filename);
        return !await f.exists();
      }),
    );
  }

  Future<Set<String>> _identityFilenames() async {
    final db = await DatabaseService.instance.userDataDb;
    return {
      for (final r in await SongIdentityRepository.loadAll(db)) r.filename
    };
  }

  Future<
      ({
        int artistTotal,
        int artistPending,
        int albumTotal,
        int albumPending
      })> _artCoverage() async {
    final songs = await ref.read(songsProvider.future);
    return PassiveArtFetcherService.instance
        .artCoverage(songs, ref.read(artistAlbumArtProvider));
  }

  // ----------------------------------------------------------- operations --

  Future<IndexerResult> _optimizeDatabases(_Run run) async {
    final result = await DatabaseOptimizerService().optimizeDatabases(
      options: const OptimizationOptions(
        automaticMode: false,
        selectedTypes: {
          OptimizationType.statsDatabase,
          OptimizationType.userDataDatabase,
        },
      ),
    );
    final r = run.result(error: result.success ? null : result.message);
    return IndexerResult(
      success: r.success,
      error: r.error,
      requiresRestart: result.success,
    );
  }

  Future<IndexerResult> _repairLibraryLinks(_Run run) async {
    await LibraryRepairService.instance.repairLibrary(
      onProgress: (progress, _) =>
          _patch(run.id, (op) => op.copyWith(runFraction: progress)),
    );
    _invalidateLibrary();
    return run.result();
  }

  Future<IndexerResult> _rebuildRecommendations(_Run run) async {
    await ref
        .read(userDataProvider.notifier)
        .updateRecommendationPlaylists(force: true);
    return run.result();
  }

  Future<IndexerResult> _matchSongIdentity(_Run run, List<Song> songs,
      {required bool force}) async {
    final service = SongIdentityService.instance;
    if (service.isRunning) {
      return run.result(error: 'busy');
    }
    final report = await service.reconcile(
      songs,
      options: IdentityRunOptions(
        force: force,
        isCancelled: () => run.cancelled,
        onProgress: run.report,
      ),
    );
    if (report.changedUserData) {
      _invalidateLibrary();
      ref.read(userDataProvider.notifier).refresh();
    }
    return run.result();
  }

  Future<IndexerResult> _rebuildSearchIndex(_Run run, List<Song> songs,
      {required bool force}) async {
    final search = ref.read(searchServiceProvider);
    await search.init();
    if (force) await search.clearIndex();
    run.start(songs.length);
    await search.rebuildIndex(
      songs,
      isCancelled: () => run.cancelled,
      onProgress: run.report,
    );
    if (!run.cancelled) {
      final indexed = await search.indexedFilenames();
      for (final s in songs) {
        if (!indexed.contains(s.filename)) run.failed.add(s.filename);
      }
    }
    return run.result();
  }

  Future<IndexerResult> _rebuildCovers(_Run run, List<Song> targets,
      {required bool force}) async {
    run.start(targets.length);
    if (force) {
      await DatabaseService.instance.clearAllCoverMisses();
    }
    final scanner = ScannerService();
    var touched = false;
    // Small chunks so stop takes effect quickly and progress is real; the
    // scanner's own callback only reports one pass over everything.
    const chunkSize = 24;
    for (var i = 0; i < targets.length; i += chunkSize) {
      if (run.cancelled) break;
      final chunk = targets.sublist(i, math.min(i + chunkSize, targets.length));
      // force wipes the covers directory, which must only happen once.
      final coverMap = await scanner.rebuildCoverCache(
        chunk,
        force: force && i == 0,
      );
      final updated = <Song>[];
      final resolved = <String>[];
      for (final song in chunk) {
        final cover = coverMap[song.url];
        if (cover != null) {
          if (cover != song.coverUrl) {
            updated.add(song.copyWith(coverUrl: cover));
          }
          resolved.add(song.filename);
          run.tick();
        } else if (await File(song.url).exists()) {
          // Readable file, nothing embedded: record it so it stops counting
          // as missing.
          await DatabaseService.instance
              .markCoverMiss(song.filename, song.mtime ?? 0);
          run.tick();
        } else {
          run.tick(failedItem: song.filename);
        }
      }
      if (resolved.isNotEmpty) {
        await DatabaseService.instance.clearCoverMisses(resolved);
      }
      if (updated.isNotEmpty) {
        await DatabaseService.instance.insertSongsBatch(updated);
        touched = true;
      }
    }
    CoverRefreshService.instance.invalidateMisses();
    if (touched || force) _invalidateLibrary();
    return run.result();
  }

  Future<IndexerResult> _rebuildLyrics(_Run run, List<Song> targets,
      {required bool force}) async {
    final repo = SongRepository();
    if (force) await repo.clearLyricsCache();
    run.start(targets.length);
    for (final song in targets) {
      if (run.cancelled) break;
      try {
        await repo.getLyrics(song);
        final ok = await repo.hasLyricsCacheEntry(song);
        run.tick(failedItem: ok ? null : song.filename);
      } catch (_) {
        run.tick(failedItem: song.filename);
      }
    }
    return run.result();
  }

  Future<IndexerResult> _rebuildWaveforms(_Run run, List<Song> targets,
      {required bool force}) async {
    final cache = CacheService.instance;
    final waveforms = WaveformService(cache);
    run.start(targets.length);
    try {
      for (final song in targets) {
        if (run.cancelled) break;
        try {
          final file = await cache.getWaveformCacheFile(song.filename);
          if (force && await file.exists()) await file.delete();
          final data = await waveforms.getWaveform(song.filename, song.url);
          run.tick(failedItem: data.isEmpty ? song.filename : null);
        } catch (_) {
          run.tick(failedItem: song.filename);
        }
      }
    } finally {
      waveforms.dispose();
    }
    return run.result();
  }

  Future<IndexerResult> _rebuildColors(_Run run, List<String> paths,
      {required bool force}) async {
    if (force) await ColorExtractionService.clearCache();
    run.start(paths.length);
    for (final path in paths) {
      if (run.cancelled) break;
      try {
        final palette = await ColorExtractionService.extractPalette(path);
        run.tick(failedItem: palette == null ? path : null);
      } catch (_) {
        run.tick(failedItem: path);
      }
    }
    return run.result();
  }

  Future<IndexerResult> _rebuildBlurred(_Run run, List<Song> targets) async {
    final cache = CacheService.instance;
    final ffmpeg = FFmpegService();
    run.start(targets.length);
    for (final song in targets) {
      if (run.cancelled) break;
      try {
        final out = await cache.getBlurredCacheFile(song.filename);
        final ok = await ffmpeg.generateBlurredImage(
          inputPath: song.coverUrl!,
          outputPath: out.path,
          width: 300,
          height: 300,
          blurSigma: 15,
        );
        run.tick(failedItem: ok ? null : song.filename);
      } catch (_) {
        run.tick(failedItem: song.filename);
      }
    }
    return run.result();
  }

  Future<IndexerResult> _rebuildArtistAlbumArt(_Run run,
      {required bool force}) async {
    if (force) await ref.read(artistAlbumArtProvider.notifier).clearAll();
    var aDone = 0, aTotal = 0, bDone = 0, bTotal = 0;
    var last = DateTime.fromMillisecondsSinceEpoch(0);
    void emit() {
      final now = DateTime.now();
      final finished = aDone >= aTotal && bDone >= bTotal;
      if (!finished && now.difference(last).inMilliseconds < 120) return;
      last = now;
      run.done = aDone + bDone;
      run.total = aTotal + bTotal;
      _patch(
        run.id,
        (op) => op.copyWith(
          runDone: run.done,
          runTotal: run.total,
          artistRunDone: aDone,
          artistRunTotal: aTotal,
          albumRunDone: bDone,
          albumRunTotal: bTotal,
        ),
      );
    }

    final result = await PassiveArtFetcherService.instance.runArtBurst(
      driven: true,
      onArtistProgress: (done, total) {
        aDone = done;
        aTotal = total;
        emit();
      },
      onAlbumProgress: (done, total) {
        bDone = done;
        bTotal = total;
        emit();
      },
      isCancelled: () => run.cancelled,
    );
    last = DateTime.fromMillisecondsSinceEpoch(0);
    emit();
    run.failed.addAll(result.failedItems);
    return run.result(error: result.offline ? 'offline' : null);
  }
}

final indexerProvider =
    NotifierProvider<IndexerNotifier, IndexerState>(IndexerNotifier.new);
