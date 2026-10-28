import 'package:flutter/widgets.dart'; // For AppLifecycleListener
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:async'; // For Timer
import 'package:flutter/foundation.dart' show listEquals;
import '../models/song.dart';
import '../models/queue_item.dart';
import '../models/queue_snapshot.dart';
import '../models/shuffle_config.dart';
import '../domain/models/play_source.dart';
import '../domain/services/remembered_order.dart';
import '../domain/services/shuffle_migration.dart';
import '../domain/services/shuffle_selector.dart';
import '../domain/services/smart_weights.dart';
import '../domain/services/song_affinity.dart';
import '../domain/services/taste_model.dart';
import '../domain/services/queue_ops.dart' as queue_ops;
import 'stats_service.dart';
import 'storage_service.dart';
import 'database_service.dart';
import 'sync_service.dart';
import 'ffmpeg_service.dart';
import 'file_manager_service.dart';
import 'notification_cover_warmer.dart';
import 'volume_monitor_service.dart';
import 'color_extraction_service.dart';
import 'scanner_service.dart';
import 'open_file_service.dart';
import '../domain/services/cover_optimizer.dart';
import '../providers/theme_provider.dart';
import '../providers/queue_history_provider.dart';
import 'permission_service.dart';
import 'online_audio_cache.dart';
import 'youtube_audio_source.dart';
import 'youtube_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/providers.dart';

// Gap state persistence keys
const String _keyGapSongId = 'gap_current_song_id';
const String _keyGapResumeTimestamp = 'gap_resume_timestamp';
const String _keyGapIsActive = 'gap_is_active';

// Cache limits for foreground/background
const int _foregroundCacheSize = 250;
const int _foregroundCacheBytes = 40 * 1024 * 1024; // 40MB
const int _backgroundCacheSize = 50;
const int _backgroundCacheBytes = 10 * 1024 * 1024; // 10MB

enum PlaybackMediaMode { audio, video }

class AudioPlayerManager extends WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();
  final StatsService _statsService;
  final StorageService _storageService;
  final Ref? _ref;

  List<QueueItem> _originalQueue = [];
  List<QueueItem> _effectiveQueue = [];
  List<String> _sessionTopOrder = [];
  List<Song> _allSongs = [];
  Map<String, Song> _songMap = {};

  /// Open-with songs that are not part of the library. Kept apart from
  /// [_songMap]/[_allSongs] on purpose: library scans rebuild those maps from
  /// the database, and transient cache copies must never leak into the
  /// library, shuffle candidate generation, or user-data keys.
  final Map<String, Song> _transientSongs = {};

  /// Registers open-with songs so every filename-keyed lookup (now-playing,
  /// queue reconcile, covers, stats guard) resolves them. Safe to call with
  /// library songs too — those are already in [_songMap] and are skipped.
  void ensureKnownSongs(List<Song> songs) {
    for (final song in songs) {
      if (!isExternalSongFilename(song.filename)) continue;
      _transientSongs[song.filename] = song;
    }
  }

  Song? _lookupSong(String filename) =>
      _songMap[filename] ?? _transientSongs[filename];

  /// Remote tracks are not part of the library map — they only exist in the
  /// queue (plus cached user data). Without this fallback the now-playing bar
  /// and the player panel had no song to show or open for anything streamed.
  Song? _lookupQueuedSong(String filename) {
    for (final item in _effectiveQueue) {
      if (item.song.filename == filename) return item.song;
    }
    return null;
  }

  Song? _resolveSong(String filename) =>
      _lookupSong(filename) ?? _lookupQueuedSong(filename);

  // Active queue snapshot ID for auto-save tracking
  String? _currentQueueSnapshotId;
  // Queue history entry the current song's play event belongs to. Latched on
  // the song's first stats flush rather than at song start: a new queue's
  // snapshot is saved only after its first track has already started.
  String? _currentSongQueueSnapshotId;

  // Pending queue replacement (fires when current song ends)
  List<Song>? _pendingQueueSongs;
  String? _pendingQueuePlaylistId;
  final ValueNotifier<bool> pendingQueueNotifier = ValueNotifier(false);

  // User data for weighting (Fallback / Offline)
  // O(1) lookup sets for membership checks (shuffle weighting path is hot).
  Set<String> _favoriteKeys = const <String>{};
  Set<String> _suggestLessKeys = const <String>{};
  Set<String> _hiddenKeys = const <String>{};
  // Songs belonging to at least one user playlist, for `playlistSongsWeight`.
  Set<String> _playlistKeys = const <String>{};

  // Merged song groups for shuffle weighting
  Map<String, List<String>> _mergedGroups = {};
  Map<String, String?> _mergedGroupPriorities = {};

  /// Play source per queue entry (keyed by `QueueItem.queueId`, not filename,
  /// since one song can be queued twice). Bounded to avoid growing forever.
  final Map<String, PlaySource> _itemSource = {};
  static const int _maxItemSources = 2000;
  String? _currentQueueId;
  // Filename -> groupId lookup, rebuilt on setUserData().
  Map<String, String> _filenameToGroupId = const <String, String>{};

  // Shuffle state
  ShuffleState _shuffleState = const ShuffleState();

  // Upcoming order from the last shuffle, in memory only. Lets the shuffle
  // button flip back to a shuffle the listener already heard instead of
  // rolling a new one. Cleared whenever a new queue starts.
  List<String>? _rememberedUpcomingIds;
  bool _shuffleOrderDirty = false;
  bool _shuffleOrderApplying = false;

  // Cache DB query results and the derived affinity model across rapid
  // shuffle calls. Cleared by _invalidateShuffleCache() whenever user data
  // changes, since favorites feed the affinity floor.
  Map<String, SongAffinity>? _cachedAffinities;
  List<
      ({
        String filename,
        double timestamp,
        double playRatio,
        String eventType
      })>? _cachedPlayHistory;
  DateTime? _shuffleCacheTimestamp;
  static const Duration _shuffleCacheDuration = Duration(seconds: 30);

  // Smart taste snapshot. Built in an isolate, rebuilt lazily after play events,
  // user-data or library changes. Shuffle waits on it only briefly.
  TasteSnapshot? _taste;
  Future<TasteSnapshot>? _tasteBuilding;
  bool _tasteDirty = true;
  static const Duration _tasteWait = Duration(milliseconds: 1500);
  // Artists of the last completed plays this app session, for session context.
  final List<String> _recentCompletedArtists = [];
  static const int _sessionArtistWindow = 5;

  // Stats tracking state
  String? _currentSongFilename;
  // When the track now playing started. The queue's played list uses it to
  // tell the listen still in progress from listens that are over.
  DateTime? _currentListenStartedAt;
  String? _currentPlaylistId;
  DateTime? _playStartTime;
  bool _isCompleting = false;

  // Previous session tracking for ignoring quick skips of resumed songs
  String? _previousSessionSongFilename;
  bool _isResumedFromPreviousSession = false;
  double? _pendingResumedSongStartSec;

  // Session-only first-song baseline tracking (RAM only)
  bool _sessionFirstSongCaptured = false;
  String? _sessionFirstSongFilename;
  double? _sessionFirstSongStartSec;

  // Volume monitoring
  VolumeMonitorService? _volumeMonitorService;

  // Fading and delay state
  bool _isFadingOut = false;
  bool _isInGap = false;
  bool _pausedByGap = false;
  String? _lastFadedFilename;
  Timer? _fadeTimer;
  Timer? _gapTimer;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<SequenceState?>? _sequenceSubscription;
  final List<StreamSubscription<dynamic>> _trackedSubscriptions = [];
  SettingsState? _cachedSettings;
  Future<void> _queueMutationChain = Future<void>.value();
  Timer? _playbackStateSaveTimer;
  static const Duration _playbackStateSaveInterval =
      Duration(milliseconds: 750);

  // Guards deliberate queue mutations from the sequence-sync listener. While
  // this is > 0 the manager is itself rewriting the player's sources, so the
  // listener must not rebuild _effectiveQueue from a transient half-mutated
  // sequence. The sync exists only to catch changes made *outside* the app
  // (notification / headset actions).
  int _playerMutationDepth = 0;

  // setAudioSources broadcasts the new sequence against the old index before
  // the platform seeks to initialIndex, and the platform can report further
  // indices while it loads. Those states flashed random songs in the UI and
  // were recorded as skips, so listeners consume only states observed outside
  // a mutation, plus the final state once the mutation lands.
  final StreamController<SequenceState> _settledSequenceController =
      StreamController<SequenceState>.broadcast(sync: true);

  Stream<SequenceState> get settledSequenceStateStream =>
      _settledSequenceController.stream;

  Stream<int?> get settledCurrentIndexStream =>
      settledSequenceStateStream.map((s) => s.currentIndex).distinct();

  void _emitSettledSequence(SequenceState state) {
    if (_playerMutationDepth > 0 || _settledSequenceController.isClosed) {
      return;
    }
    _settledSequenceController.add(state);
  }

  // Play/pause fade state (separate from track-transition fades)
  // ignore: unused_field
  bool _isPlayPauseFading = false;
  bool _isPausingByFade = false;
  Timer? _playPauseFadeTimer;

  // Fade state tracking
  double _targetVolume = 1.0;
  // The volume the user chose. Fades ramp the player's volume around this and
  // never write to it, so the volume UI does not move during a fade.
  final ValueNotifier<double> userVolumeNotifier = ValueNotifier(1.0);
  DateTime? _fadeStartTime;
  double? _fadeDurationMs;
  bool _holdMutedUntilNextTrack = false;

  // Feature coordination state
  bool _wasPausedByMute = false;

  // Sleep-timer parking: armed until the track boundary, then held while the
  // next track is muted, paused and rewound.
  bool _parkPending = false;
  bool _parking = false;
  // Whether anything has played since the park was armed, so a paused player
  // arms the park without immediately resolving it.
  bool _parkSawPlayback = false;
  Completer<void>? _parkCompleter;
  StreamSubscription<int?>? _parkIndexSub;
  StreamSubscription<PlayerState>? _parkStateSub;
  LoopMode? _parkSavedLoopMode;

  // New stats counters
  double _foregroundDuration = 0.0;
  double _backgroundDuration = 0.0;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  final ValueNotifier<bool> shuffleNotifier = ValueNotifier(false);
  final ValueNotifier<ShuffleState> shuffleStateNotifier = ValueNotifier(
    const ShuffleState(),
  );
  final ValueNotifier<List<QueueItem>> queueNotifier = ValueNotifier([]);
  final ValueNotifier<Song?> currentSongNotifier = ValueNotifier(null);
  final ValueNotifier<bool> playingNotifier = ValueNotifier(false);
  final ValueNotifier<PlaybackMediaMode> preferredMediaModeNotifier =
      ValueNotifier(PlaybackMediaMode.audio);
  final ValueNotifier<PlaybackMediaMode> effectiveMediaModeNotifier =
      ValueNotifier(PlaybackMediaMode.audio);
  final ValueNotifier<bool> fastForwardNotifier = ValueNotifier(false);

  bool get isFastForwarding => fastForwardNotifier.value;

  Future<void> startFastForward({double speed = 2.0}) async {
    if (fastForwardNotifier.value) return;
    fastForwardNotifier.value = true;
    try {
      await _player.setSpeed(speed);
    } catch (e) {
      debugPrint('AudioPlayerManager: failed to set fast forward speed: $e');
    }
  }

  Future<void> stopFastForward() async {
    if (!fastForwardNotifier.value) return;
    fastForwardNotifier.value = false;
    try {
      await _player.setSpeed(1.0);
    } catch (e) {
      debugPrint('AudioPlayerManager: failed to reset speed: $e');
    }
  }

  AudioPlayerManager(this._statsService, this._storageService, [this._ref]) {
    WidgetsBinding.instance.addObserver(this);
    _initStatsListeners();
    _initFadingListeners();
    _initPersistence();
    _initVolumeMonitoring();
    _restoreGapStateIfNeeded();
    _track(SyncService.instance.queueApplied
        .listen((q) => unawaited(_applySyncedQueue(q))));
    // The playhead is checkpointed when it changes meaning — a pause, a track
    // change, going to the background — and once right before a run uploads,
    // which is the moment another device reads it.
    SyncService.instance.beforeRun = savePlaybackState;
  }

  AudioPlayer get player => _player;
  String? get currentPlaylistId => _currentPlaylistId;

  /// Id of the history entry the live queue is playing under, or null when this
  /// queue has no snapshot yet. Play events carry it, which is what makes the
  /// queue's played list queryable.
  String? get currentQueueId =>
      _currentQueueSnapshotId ?? _currentSongQueueSnapshotId;

  /// Bumped whenever the played set of the current queue can have changed, so
  /// the queue pane re-reads it instead of deriving it from the queue order.
  final ValueNotifier<int> queuePlayedRevision = ValueNotifier<int>(0);

  /// When the current track's listen began, or null before one has started.
  DateTime? get currentListenStartedAt => _currentListenStartedAt;

  /// Plays the current track out, then leaves the queue parked on the next one:
  /// loaded, rewound to zero and paused, so no part of it is heard.
  ///
  /// Resolves once the queue is parked, once it runs out of tracks first, or on
  /// [cancelParkAfterCurrentTrack]. This is how the sleep timer ends a session:
  /// cutting the last track off early loses the ending, and stopping exactly at
  /// the boundary lets the next track's first frames through.
  Future<void> parkAfterCurrentTrack() async {
    final pending = _parkCompleter;
    if (pending != null) return pending.future;

    final completer = Completer<void>();
    _parkCompleter = completer;
    _parkPending = true;
    _parkSawPlayback = false;

    // A gap pauses a second before the end and then skips ahead; let the track
    // play out so the park lands on a real boundary instead.
    if (_isInGap) {
      _cancelGap();
      unawaited(_player.play());
    }

    // Repeat-one would replay the track instead of ending it, so the park
    // would wait forever. Loop once more, then stop on the next track.
    if (_player.loopMode == LoopMode.one) {
      _parkSavedLoopMode = LoopMode.one;
      try {
        await _player.setLoopMode(LoopMode.off);
      } catch (e) {
        debugPrint('AudioPlayerManager: failed to clear loop for park: $e');
      }
    }

    final startIndex = _player.currentIndex;
    if (startIndex == null) {
      _releasePark();
      return completer.future;
    }

    _parkIndexSub = _player.currentIndexStream.listen((index) {
      if (!_parkPending || index == null || index == startIndex) return;
      unawaited(_park());
    });

    _parkStateSub = _player.playerStateStream.listen((state) {
      if (!_parkPending) return;
      if (state.playing) {
        _parkSawPlayback = true;
        return;
      }
      // Nothing left to play out: the queue ended, or the listener paused it.
      // A park armed while paused waits instead, so "stop after this song"
      // survives a break the listener takes before the song ends.
      if (_parkSawPlayback ||
          state.processingState == ProcessingState.completed) {
        _releasePark();
      }
    });

    return completer.future;
  }

  /// Disarms a park that has not happened yet and puts the volume back.
  void cancelParkAfterCurrentTrack() {
    if (!_parkPending) return;
    _releasePark();
    _setVolumeWithSafety(userVolumeNotifier.value);
  }

  Future<void> _park() async {
    if (_parking) return;
    _parking = true;
    final volume = userVolumeNotifier.value;
    try {
      // Mute first: the platform can already hold frames of the next track, and
      // pausing alone would let those through.
      await _player.setVolume(0);
      await _player.pause();
      await _player.seek(Duration.zero);
    } catch (e) {
      debugPrint('AudioPlayerManager: failed to park the queue: $e');
    }
    _holdMutedUntilNextTrack = false;
    _isFadingOut = false;
    _parking = false;
    _releasePark();
    _setVolumeWithSafety(volume);
    await savePlaybackState();
  }

  void _releasePark() {
    _parkPending = false;
    _parkSawPlayback = false;
    _parkIndexSub?.cancel();
    _parkIndexSub = null;
    _parkStateSub?.cancel();
    _parkStateSub = null;

    final loopMode = _parkSavedLoopMode;
    _parkSavedLoopMode = null;
    if (loopMode != null) {
      try {
        _player.setLoopMode(loopMode);
      } catch (e) {
        debugPrint('AudioPlayerManager: failed to restore loop mode: $e');
      }
    }

    final completer = _parkCompleter;
    _parkCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  PlaybackMediaMode get preferredMediaMode => preferredMediaModeNotifier.value;
  PlaybackMediaMode get effectiveMediaMode => effectiveMediaModeNotifier.value;

  Future<void> setPreferredMediaMode(PlaybackMediaMode mode) async {
    preferredMediaModeNotifier.value = mode;
    _updateEffectivePlaybackMode();
    await savePlaybackState();
  }

  PlaybackMediaMode _resolveEffectiveMode(Song? song) {
    if (preferredMediaModeNotifier.value == PlaybackMediaMode.video &&
        song?.hasVideo == true) {
      return PlaybackMediaMode.video;
    }
    return PlaybackMediaMode.audio;
  }

  void _updateEffectivePlaybackMode([Song? song]) {
    final currentSong = song ?? currentSongNotifier.value;
    effectiveMediaModeNotifier.value = _resolveEffectiveMode(currentSong);
  }

  Future<bool> stopIfCurrentSong(String fileUrl) async {
    final current = currentSongNotifier.value;
    if (current == null) return false;
    if (!p.equals(current.url, fileUrl)) return false;
    try {
      await _player.stop();
      return true;
    } catch (e) {
      debugPrint('AudioPlayerManager: failed to stop for edit: $e');
      return false;
    }
  }

  bool _isFavorite(String filename) {
    final lower = filename.toLowerCase();
    return _favoriteKeys.contains(lower) ||
        _favoriteKeys.contains(p.basename(lower));
  }

  bool _isSuggestLess(String filename) {
    final lower = filename.toLowerCase();
    return _suggestLessKeys.contains(lower) ||
        _suggestLessKeys.contains(p.basename(lower));
  }

  bool _isHidden(String filename) {
    final lower = filename.toLowerCase();
    return _hiddenKeys.contains(lower) ||
        _hiddenKeys.contains(p.basename(lower));
  }

  bool _isInPlaylist(String filename) {
    final lower = filename.toLowerCase();
    return _playlistKeys.contains(lower) ||
        _playlistKeys.contains(p.basename(lower));
  }

  void setUserData({
    List<String>? favorites,
    List<String>? suggestLess,
    List<String>? hidden,
    List<String>? playlistSongs,
    Map<String, List<String>>? mergedGroups,
    Map<String, String?>? mergedGroupPriorities,
  }) {
    if (favorites != null) {
      _favoriteKeys = _buildFilenameKeys(favorites);
    }
    if (suggestLess != null) {
      _suggestLessKeys = _buildFilenameKeys(suggestLess);
    }
    if (hidden != null) {
      _hiddenKeys = _buildFilenameKeys(hidden);
    }
    if (playlistSongs != null) {
      _playlistKeys = _buildFilenameKeys(playlistSongs);
    }
    if (mergedGroups != null) {
      _mergedGroups = mergedGroups;
      _filenameToGroupId = _buildFilenameToGroupId(mergedGroups);
    }
    if (mergedGroupPriorities != null) {
      _mergedGroupPriorities = mergedGroupPriorities;
    }
    _invalidateShuffleCache();
    _tasteDirty = true;
  }

  void _invalidateShuffleCache() {
    _cachedAffinities = null;
    _cachedPlayHistory = null;
    _shuffleCacheTimestamp = null;
  }

  static Set<String> _buildFilenameKeys(List<String> filenames) {
    if (filenames.isEmpty) return const <String>{};
    final keys = <String>{};
    for (final f in filenames) {
      keys.add(f.toLowerCase());
      keys.add(p.basename(f).toLowerCase());
    }
    return keys;
  }

  static Map<String, String> _buildFilenameToGroupId(
      Map<String, List<String>> groups) {
    if (groups.isEmpty) return const <String, String>{};
    final map = <String, String>{};
    for (final entry in groups.entries) {
      for (final filename in entry.value) {
        map[filename] = entry.key;
      }
    }
    return map;
  }

  List<String> _getMergedSiblings(String filename) {
    for (final group in _mergedGroups.values) {
      if (group.contains(filename)) {
        return group.where((f) => f != filename).toList();
      }
    }
    return [];
  }

  Future<void> updateShuffleConfig(
    ShuffleConfig config, {
    bool applyToCurrentQueue = true,
    bool createSnapshotOnQueueApply = false,
  }) async {
    _shuffleState = _shuffleState.copyWith(config: config);
    shuffleStateNotifier.value = _shuffleState;
    shuffleNotifier.value = config.enabled;
    _invalidateShuffleCache();
    _rememberedUpcomingIds = null;
    _saveShuffleState();

    if (applyToCurrentQueue && _effectiveQueue.isNotEmpty) {
      if (config.enabled) {
        await shuffleUpcoming(
          createNewSnapshot: createSnapshotOnQueueApply,
        );
      } else {
        await orderUpcoming(
          createNewSnapshot: createSnapshotOnQueueApply,
        );
      }
    }
  }

  Future<void> playSong(
    Song song, {
    List<Song>? contextQueue,
    String? playlistId,
    bool startPlaying = true,
    bool forceLinear = false,
  }) async {
    _resetFading();
    await _player.setShuffleModeEnabled(false);
    _currentPlaylistId = playlistId;

    if (forceLinear && _shuffleState.config.enabled) {
      _shuffleState = _shuffleState.copyWith(
        config: _shuffleState.config.copyWith(enabled: false),
      );
      shuffleStateNotifier.value = _shuffleState;
      shuffleNotifier.value = false;
      await _saveShuffleState();
    }

    _pendingQueueSongs = null;
    _pendingQueuePlaylistId = null;
    pendingQueueNotifier.value = false;

    final currentSong = currentSongNotifier.value;
    if (currentSong != null && currentSong.filename == song.filename) {
      await _player.seek(Duration.zero);
      if (startPlaying) await _player.play();
      _savePlaybackState();
      return;
    }

    _sessionTopOrder.clear();
    _rememberedUpcomingIds = null;

    bool usedContextQueue = false;
    if (_originalQueue.isEmpty) {
      if (contextQueue != null) {
        _originalQueue = contextQueue.map((s) => QueueItem(song: s)).toList();
        usedContextQueue = true;
      } else {
        _originalQueue = [QueueItem(song: song)];
      }

      final originalIdx = _originalQueue.indexWhere(
        (item) => item.song.filename == song.filename,
      );

      if (_shuffleState.config.enabled && !forceLinear) {
        final otherItems = List<QueueItem>.from(_originalQueue)
          ..removeAt(originalIdx);
        final shuffledOthers = await _weightedShuffle(
          otherItems,
          lastItem: _originalQueue[originalIdx],
        );
        _effectiveQueue = [_originalQueue[originalIdx], ...shuffledOthers];
        _updateQueueNotifier();
        await _rebuildQueue(initialIndex: 0, startPlaying: startPlaying);
      } else {
        _effectiveQueue = List.from(_originalQueue);
        _updateQueueNotifier();
        await _rebuildQueue(
          initialIndex: originalIdx,
          startPlaying: startPlaying,
        );
      }

      if (usedContextQueue) {
        await _saveQueueSnapshot(
          [for (final item in _effectiveQueue) item.song],
          playlistId: playlistId,
        );
      } else {
        _currentQueueSnapshotId = null;
      }

      _savePlaybackState();
      return;
    }

    final currentIndex = _player.currentIndex ?? 0;
    final targetIndex = (currentIndex + 1).clamp(0, _effectiveQueue.length);

    final duplicate = QueueItem(song: song);
    _effectiveQueue.insert(targetIndex, duplicate);

    final origTarget = (currentIndex + 1).clamp(0, _originalQueue.length);
    _originalQueue.insert(origTarget, QueueItem(song: song));

    _updateQueueNotifier();
    final insertWatch = Stopwatch()..start();
    try {
      final source = await _createAudioSource(
        duplicate,
        awaitCover: true,
        resolveRemoteNow: true,
      );
      await _player.insertAudioSource(targetIndex, source);
    } catch (e) {
      _effectiveQueue.removeAt(targetIndex);
      rethrow;
    }
    _logSlow('playSong: insert source', insertWatch);

    if (startPlaying) {
      await _player.seek(Duration.zero, index: targetIndex);
      unawaited(_player.play());
    }

    _syncCoverWarmer(targetIndex);
    await _updateCurrentSnapshotSongs();
    _savePlaybackState();
  }

  StreamSubscription<T> _track<T>(StreamSubscription<T> sub) {
    _trackedSubscriptions.add(sub);
    return sub;
  }

  void _initStatsListeners() {
    // Track previous playing state for manual pause detection
    bool wasPlaying = false;

    _track(_player.playerStateStream.listen((state) {
      // Confirm fade-pause completion before checking for manual intervention
      if (_isPausingByFade && !state.playing) {
        _isPausingByFade = false;
      }

      // Detect manual pause (user pressed pause button)
      // Don't cancel transitions if we are in a gap (expected pause) or completing a fade
      if (wasPlaying &&
          !state.playing &&
          !_isInGap &&
          !_pausedByGap &&
          !_isPausingByFade) {
        _handleManualIntervention();
      }

      // Handle user pressing play during gap - cancel the gap timer
      if (_isInGap && state.playing) {
        _cancelGap();
      }

      // Reset pausedByGap after the state settles, but only outside a gap
      if (!wasPlaying && !state.playing && !_isInGap) {
        _pausedByGap = false;
      }

      wasPlaying = state.playing;

      // Keep playingNotifier in sync with actual player state
      // (unless a fade is in progress, in which case it was already set)
      if (!_isPlayPauseFading) {
        playingNotifier.value = state.playing;
      }

      if (state.playing) {
        _playStartTime ??= DateTime.now();
      } else if (_playStartTime != null) {
        _updateDurations();
        _playStartTime = null;
        _flushStats();
        // Checkpoint the playhead: a pause is where this device stopped
        // listening, and where the next one should pick up.
        _savePlaybackState();
      }
      if (state.processingState == ProcessingState.completed) {
        _isCompleting = true;
        _flushStats(isTerminal: true);
      }
    }));

    // Listen for seek operations to cancel fade out. The fade-related seek
    // detection lives in _initFadingListeners, which owns the single
    // positionStream subscription for this player.

    _track(_player.sequenceStateStream.listen(_emitSettledSequence));
    _track(settledSequenceStateStream.listen((state) {
      _syncEffectiveQueueWithPlayerSequence(state);
      final currentItem = state.currentSource?.tag;

      if (currentItem is MediaItem) {
        final newFilename = currentItem.id;

        // Stats tracking
        if (_currentSongFilename != null &&
            _currentSongFilename != newFilename) {
          if (!_isCompleting) {
            final shouldIgnore = _isResumedFromPreviousSession &&
                _currentSongFilename == _previousSessionSongFilename &&
                _foregroundDuration + _backgroundDuration <= 10.0;

            if (!shouldIgnore) {
              _flushStats(isTerminal: true);
            }
          }
        }

        if (_currentSongFilename != newFilename) {
          final liveStartSec =
              max(0.0, _player.position.inMilliseconds / 1000.0);
          double songStartSec = liveStartSec;
          if (_pendingResumedSongStartSec != null &&
              _isResumedFromPreviousSession &&
              _previousSessionSongFilename == newFilename) {
            songStartSec = max(songStartSec, _pendingResumedSongStartSec!);
            _pendingResumedSongStartSec = null;
          }
          if (!_sessionFirstSongCaptured) {
            _sessionFirstSongCaptured = true;
            _sessionFirstSongFilename = newFilename;
            _sessionFirstSongStartSec = songStartSec;
          }

          _isCompleting = false;
          _currentSongFilename = newFilename;
          _currentListenStartedAt = DateTime.now();
          _currentSongQueueSnapshotId = null;
          final currentIdx = _player.currentIndex;
          _currentQueueId = currentIdx != null &&
                  currentIdx >= 0 &&
                  currentIdx < _effectiveQueue.length &&
                  _effectiveQueue[currentIdx].song.filename == newFilename
              ? _effectiveQueue[currentIdx].queueId
              : null;
          _foregroundDuration = 0.0;
          _backgroundDuration = 0.0;
          _playStartTime = _player.playing ? DateTime.now() : null;
          final song = _resolveSong(newFilename);
          currentSongNotifier.value = song;
          _updateEffectivePlaybackMode(song);
          _warmBeatAnalysis(song);
          _warmWaveform(song);
          _optimizeCoverForCurrentSong(song);
          _isResumedFromPreviousSession = false;
          _savePlaybackState();

          // No palette warm here: the current track's palette is extracted
          // below and the next track's by [_preExtractNextColor]. A radius-1
          // warm would add a third cover decode (the previous track's) to an
          // already crowded track change, and its theme is still cached from
          // when it was playing.
          if (state.currentIndex != null) {
            _syncCoverWarmer(state.currentIndex!);
          }

          // Extract color from cover only when foregrounded
          if (!_isBackground && song != null && _ref != null) {
            final filenameAtExtraction = newFilename;
            ColorExtractionService.extractPaletteForCover(song.coverUrl)
                .then((palette) {
              // Extraction is async; drop results for a track the user has
              // already skipped past.
              if (_currentSongFilename != filenameAtExtraction) return;
              // Pushed through unchanged — the extraction service already
              // corrected the accent for legibility, and a second pass here is
              // what let the player and the rest of the app drift onto two
              // different colours. A null result is forwarded too, so a song
              // whose cover failed to decode clears the previous track's accent
              // instead of silently keeping it.
              _ref!.read(themeProvider.notifier).updateExtractedPalette(
                    palette,
                    forFilename: filenameAtExtraction,
                  );
            });
            _preExtractNextColor();
          }
        }
      }
    }));
  }

  // ==================== FADE AND GAP LOGIC ====================

  /// Whether anything the playhead listener does can actually happen.
  ///
  /// Fades and gaps are both off by default, and for a user who leaves them
  /// that way the listener below was a callback several times a second, for the
  /// whole of every track, that could only ever fall through its own guards —
  /// including while the app is in the background with the screen off.
  bool _needsPositionListener(SettingsState? settings) =>
      settings != null &&
      (settings.fadeOutDuration > 0 || settings.delayDuration > 0);

  /// Attaches or detaches the playhead listener to match the current settings.
  /// Called once the settings cache is populated, and again whenever it
  /// changes.
  void _syncPositionListener() {
    final needed = _needsPositionListener(_cachedSettings);
    if (needed == (_positionSubscription != null)) return;

    if (needed) {
      _positionSubscription = _player.positionStream.listen(_onFadePosition);
    } else {
      _positionSubscription?.cancel();
      _positionSubscription = null;
      // Nothing is left to finish a fade that is already under way, so put the
      // volume back rather than leaving the track quiet forever.
      if (_isFadingOut) _cancelTransitions();
    }
  }

  Duration _lastTickPosition = Duration.zero;
  DateTime _lastAdvanceAt = DateTime.now();

  // AVFoundation can stop advancing near the end (duration estimate longer
  // than the decodable audio) and sit there for seconds before completing.
  void _skipStalledTail(Duration position, Duration remaining) {
    if (!(Platform.isMacOS || Platform.isIOS)) return;
    final now = DateTime.now();
    if (position != _lastTickPosition || !_player.playing) {
      _lastTickPosition = position;
      _lastAdvanceAt = now;
      return;
    }
    if (remaining < const Duration(seconds: 5) &&
        now.difference(_lastAdvanceAt) > const Duration(milliseconds: 700) &&
        _player.hasNext) {
      _lastAdvanceAt = now;
      _player.seekToNext();
    }
  }

  void _onFadePosition(Duration position) {
    if (_ref == null) return;
    // Use the cached settings populated by the settingsProvider listener
    // (set up in _initVolumeMonitoring). positionStream fires many times
    // per second, so avoid a Riverpod lookup per tick.
    final settings = _cachedSettings;
    if (settings == null) return;

    final totalDuration = _player.duration;
    if (totalDuration == null) return;

    // Minimum 30 second song for any transitions
    if (totalDuration.inSeconds < 30) return;

    final remaining = totalDuration - position;

    _skipStalledTail(position, remaining);

    // Handle gap mode - pause before end, resume after delay. A park owns the
    // end of the track, so no gap may cut it short.
    if (settings.delayDuration > 0 &&
        !_parkPending &&
        !_isInGap &&
        _player.playing &&
        _gapTimer == null) {
      _handleGapTrigger(
        remaining: remaining,
        delayDuration: settings.delayDuration,
      );
    }

    // Handle fade out trigger
    if (settings.fadeOutDuration > 0 &&
        _player.playing &&
        !_isFadingOut &&
        remaining.inMilliseconds <= settings.fadeOutDuration * 1000 &&
        remaining.inMilliseconds > 0) {
      _startFadeOut(settings.fadeOutDuration);
    }

    // Reset fade if user seeks back. The +500 ms hysteresis matches the
    // original duplicate listener that lived in _initStatsListeners.
    if (_isFadingOut) {
      final fadeOutMs = settings.fadeOutDuration * 1000;
      if (fadeOutMs > 0 && remaining.inMilliseconds > fadeOutMs + 500) {
        _cancelTransitions();
      }
    }
  }

  void _initFadingListeners() {
    _sequenceSubscription =
        _track(settledSequenceStateStream.listen((state) async {
      if (_ref == null) return;
      // Use cached settings to avoid Riverpod lookups on every sequence
      // update (fires on every track change, but in a tighter loop during
      // gap-driven replays).
      final settings = _cachedSettings;
      if (settings == null) return;

      final currentItem = state.currentSource?.tag;
      if (currentItem is MediaItem) {
        final newFilename = currentItem.id;
        if (_lastFadedFilename != newFilename) {
          _lastFadedFilename = newFilename;
          // Reset gap state on new song
          _isInGap = false;
          _gapTimer?.cancel();
          _isFadingOut = false;
          _holdMutedUntilNextTrack = false;

          // A parked track stays silent: its volume comes back only when a park
          // settles, and a fade-in belongs to playback, which has not started.
          if (!_parkPending) {
            _setVolumeWithSafety(userVolumeNotifier.value);
            if (settings.fadeInDuration > 0 && _player.playing) {
              _startFadeIn(settings.fadeInDuration);
            }
          }
        }
      }
    }));

    // Handle completion - apply pending queue if exists, reset volume
    _track(_player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (!_holdMutedUntilNextTrack && !_parkPending) {
          _setVolumeWithSafety(userVolumeNotifier.value);
        }
        _isFadingOut = false;

        // Apply pending queue replacement when queue completes
        if (_pendingQueueSongs != null) {
          final pendingSongs = _pendingQueueSongs!;
          final pendingPlaylistId = _pendingQueuePlaylistId;
          _pendingQueueSongs = null;
          _pendingQueuePlaylistId = null;
          pendingQueueNotifier.value = false;
          replaceQueue(pendingSongs,
              playlistId: pendingPlaylistId,
              forceLinear: true,
              clearCurrentSong: true);
        }
      }
    }));
  }

  /// Where a queue entry came from, for `playevent.source`. Entries never
  /// tagged explicitly fall back to the active mode, since that is what placed
  /// them. Returns null only when there is no queue entry at all.
  PlaySource? _sourceFor(String? queueId) {
    if (queueId == null) return null;
    return _itemSource[queueId] ??
        (_shuffleState.config.enabled ? PlaySource.shuffle : PlaySource.linear);
  }

  void _tagSource(String queueId, PlaySource source) {
    _itemSource.remove(queueId);
    _itemSource[queueId] = source;
    while (_itemSource.length > _maxItemSources) {
      _itemSource.remove(_itemSource.keys.first);
    }
  }

  Future<void> _initPersistence() async {
    // Load shuffle state
    final savedShuffleJson = await _storageService.loadShuffleState();
    _shuffleState = migrateShuffleState(
      savedShuffleJson,
      await _currentAppVersion(),
    );
    shuffleStateNotifier.value = _shuffleState;
    shuffleNotifier.value = _shuffleState.config.enabled;
    await _saveShuffleState();
  }

  Future<String> _currentAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }

  void _initVolumeMonitoring() {
    if (_ref != null) {
      _volumeMonitorService = VolumeMonitorService(
        onVolumeZero: () {
          final currentSettings = _ref!.read(settingsProvider);
          if (currentSettings.autoPauseOnVolumeZero && _player.playing) {
            _wasPausedByMute = true;
            _player.pause();
          }
        },
        onVolumeRestored: () {
          final currentSettings = _ref!.read(settingsProvider);
          if (currentSettings.autoPauseOnVolumeZero &&
              currentSettings.autoResumeOnVolumeRestore &&
              _wasPausedByMute) {
            _wasPausedByMute = false;
            // If in gap, wait for gap to complete
            if (!_isInGap) {
              _player.play();
            }
          }
        },
      );
      _volumeMonitorService?.initialize();

      // Any playback start (notification, headset, lock screen, gap resume)
      // invalidates a mute-pause; otherwise a later unrelated volume-up,
      // possibly from another app, would start playback out of nowhere.
      _track(_player.playingStream.listen((playing) {
        if (playing) _wasPausedByMute = false;
      }));

      _ref!.listen(settingsProvider, (previous, next) {
        _cachedSettings = next;
        _syncPositionListener();
        if (previous?.autoPauseOnVolumeZero != next.autoPauseOnVolumeZero) {
          _volumeMonitorService
              ?.setAutoPauseEnabled(next.autoPauseOnVolumeZero);
        }
      });

      final initialSettings = _ref!.read(settingsProvider);
      _cachedSettings = initialSettings;
      _syncPositionListener();
      _volumeMonitorService?.setAutoPauseEnabled(
        initialSettings.autoPauseOnVolumeZero,
      );
    }
  }

  void _handleGapTrigger({
    required Duration remaining,
    required double delayDuration,
  }) {
    // Trigger gap when 1 second remains
    if (remaining.inMilliseconds <= 1000 && remaining.inMilliseconds > 0) {
      _triggerSimpleGap(delayDuration: delayDuration);
    }
  }

  void _triggerSimpleGap({required double delayDuration}) {
    if (_isInGap) return;

    final sequenceState = _player.sequenceState;
    final currentItem = sequenceState.currentSource?.tag;
    if (currentItem is! MediaItem) return;

    _isInGap = true;
    _pausedByGap = true;

    // Pause playback (1 second before end)
    _player.pause();

    // Schedule resume after gap duration
    final delayMs = (delayDuration * 1000).toInt();
    _gapTimer = Timer(Duration(milliseconds: delayMs), () {
      _resumeAfterGap(expectedSongId: currentItem.id);
    });
  }

  void _resumeAfterGap({required String expectedSongId}) {
    if (!_isInGap) return;

    // Clear gap state
    _isInGap = false;
    _pausedByGap = false;
    _gapTimer = null;
    _wasPausedByMute = false;

    // Verify we're still on the same song
    final sequenceState = _player.sequenceState;
    final currentItem = sequenceState.currentSource?.tag;
    if (currentItem is! MediaItem || currentItem.id != expectedSongId) {
      // User skipped/changed song during gap
      return;
    }

    // Skip to next song after gap and resume playback
    if (_player.hasNext) {
      _player.seekToNext();
    }
    _player.play();
  }

  // Exponential fade out curve (sounds natural to human ears)
  double _fadeOutCurve(double linearProgress) {
    // Exponential decay: volume drops faster at the end
    // linearProgress: 1.0 -> 0.0 (remaining time ratio)
    // Returns: curved volume from 1.0 -> 0.0
    return pow(linearProgress, 2.0).toDouble();
  }

  // Exponential fade in curve (sounds natural to human ears)
  double _fadeInCurve(double linearProgress) {
    // Exponential growth: volume rises slower at the start
    // linearProgress: 0.0 -> 1.0 (elapsed time ratio)
    // Returns: curved volume from 0.0 -> 1.0
    return pow(linearProgress, 1.5).toDouble();
  }

  void _startFadeIn(double duration) {
    _fadeTimer?.cancel();
    _fadeDurationMs = duration * 1000;
    _fadeStartTime = DateTime.now();
    _targetVolume = 1.0;

    _setVolumeWithSafety(0.0);

    _fadeTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_fadeStartTime == null || _fadeDurationMs == null) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_fadeStartTime!).inMilliseconds;
      final targetMs = _fadeDurationMs!;

      if (elapsed >= targetMs) {
        _setVolumeWithSafety(userVolumeNotifier.value);
        _fadeStartTime = null;
        _fadeDurationMs = null;
        timer.cancel();
      } else {
        final linearProgress = elapsed / targetMs;
        final curvedVolume = _fadeInCurve(linearProgress);
        _setVolumeWithSafety(curvedVolume * userVolumeNotifier.value);
      }
    });
  }

  void _startFadeOut(double duration) {
    _fadeTimer?.cancel();
    _isFadingOut = true;
    _holdMutedUntilNextTrack = false;
    _fadeDurationMs = duration * 1000;
    _fadeStartTime = DateTime.now();

    _fadeTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_fadeStartTime == null || _fadeDurationMs == null) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_fadeStartTime!).inMilliseconds;
      final targetMs = _fadeDurationMs!;

      if (elapsed >= targetMs) {
        _setVolumeWithSafety(0.0);
        _isFadingOut = false;
        _holdMutedUntilNextTrack = true;
        _fadeStartTime = null;
        _fadeDurationMs = null;
        timer.cancel();
      } else {
        final linearProgress = 1.0 - (elapsed / targetMs);
        final curvedVolume = _fadeOutCurve(linearProgress.clamp(0.0, 1.0));
        _setVolumeWithSafety(curvedVolume * userVolumeNotifier.value);
      }
    });
  }

  void _setVolumeWithSafety(double volume) {
    _targetVolume = volume.clamp(0.0, 1.0);
    try {
      _player.setVolume(_targetVolume);
    } catch (e) {
      debugPrint('AudioPlayerManager: Failed to set volume: $e');
    }
  }

  void setUserVolume(double volume) {
    userVolumeNotifier.value = volume.clamp(0.0, 1.0);
    if (!_isFadingOut && !_isPlayPauseFading) {
      _setVolumeWithSafety(userVolumeNotifier.value);
    }
  }

  /// Toggles playback with optional fade based on settings.
  void togglePlayPause() {
    if (_player.playing) {
      fadeAndPause();
    } else {
      fadeAndPlay();
    }
  }

  /// Fades volume to 0 over pauseFadeDuration, then pauses and restores volume.
  void fadeAndPause() {
    if (!_player.playing) return;
    _playPauseFadeTimer?.cancel();

    final settings = _ref?.read(settingsProvider);
    final fadeDurationMs =
        ((settings?.pauseFadeDuration ?? 0.0) * 1000).toInt();

    if (fadeDurationMs <= 0) {
      _isPausingByFade = true;
      _player.pause();
      return;
    }
    playingNotifier.value = false;
    _isPlayPauseFading = true;
    final startTime = DateTime.now();
    final startVolume = _targetVolume;

    _playPauseFadeTimer =
        Timer.periodic(const Duration(milliseconds: 33), (timer) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsed >= fadeDurationMs || !_player.playing) {
        timer.cancel();
        _isPlayPauseFading = false;
        _isPausingByFade = true;
        _setVolumeWithSafety(0.01);
        _player.pause();
        _setVolumeWithSafety(userVolumeNotifier.value);
        return;
      }
      final progress = elapsed / fadeDurationMs;
      final curved = startVolume * (1.0 - pow(progress, 0.5));
      _setVolumeWithSafety(curved.toDouble());
    });
  }

  /// Starts playback at volume 0 then fades up over playFadeDuration.
  void fadeAndPlay() {
    _playPauseFadeTimer?.cancel();
    _wasPausedByMute = false;

    final settings = _ref?.read(settingsProvider);
    final fadeDurationMs = ((settings?.playFadeDuration ?? 0.0) * 1000).toInt();

    if (fadeDurationMs <= 0) {
      _player.play();
      return;
    }

    // Show playing state in UI immediately, before the fade starts
    playingNotifier.value = true;
    _setVolumeWithSafety(0.0);
    _player.play();
    _isPlayPauseFading = true;
    final startTime = DateTime.now();
    final targetVolume = userVolumeNotifier.value;

    _playPauseFadeTimer =
        Timer.periodic(const Duration(milliseconds: 33), (timer) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsed >= fadeDurationMs) {
        timer.cancel();
        _isPlayPauseFading = false;
        _setVolumeWithSafety(targetVolume);
        return;
      }
      final progress = elapsed / fadeDurationMs;
      final curved = targetVolume * pow(progress, 0.5).toDouble();
      _setVolumeWithSafety(curved);
    });
  }

  void _resetFading() {
    _fadeTimer?.cancel();
    _playPauseFadeTimer?.cancel();
    _isFadingOut = false;
    _holdMutedUntilNextTrack = false;
    _isPlayPauseFading = false;
    _isPausingByFade = false;
    _fadeStartTime = null;
    _fadeDurationMs = null;
    _targetVolume = 1.0;
    _setVolumeWithSafety(userVolumeNotifier.value);
  }

  void _cancelTransitions() {
    _cancelGap();
    _fadeTimer?.cancel();
    _playPauseFadeTimer?.cancel();
    _isFadingOut = false;
    _holdMutedUntilNextTrack = false;
    _isPlayPauseFading = false;
    _isPausingByFade = false;
    _fadeStartTime = null;
    _fadeDurationMs = null;
    _targetVolume = 1.0;
    _setVolumeWithSafety(userVolumeNotifier.value);
  }

  void _cancelGap() {
    _isInGap = false;
    _pausedByGap = false;
    _gapTimer?.cancel();
    _clearGapState();
  }

  void _handleManualIntervention() {
    // A park pauses on purpose; its volume is restored when it settles, and
    // cancelling the transition here would unmute the parked track.
    if (_parkPending) return;
    // User manually paused - cancel any ongoing transitions
    _cancelTransitions();
  }

  // ==================== GAP STATE PERSISTENCE ====================

  Future<void> _clearGapState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyGapSongId);
      await prefs.remove(_keyGapResumeTimestamp);
      await prefs.remove(_keyGapIsActive);
    } catch (e) {
      debugPrint('AudioPlayerManager: Failed to clear gap state: $e');
    }
  }

  Future<void> _restoreGapStateIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool(_keyGapIsActive) ?? false;

      if (!isActive) return;

      final songId = prefs.getString(_keyGapSongId);
      final resumeTimestamp = prefs.getInt(_keyGapResumeTimestamp);

      if (songId == null || resumeTimestamp == null) {
        await _clearGapState();
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final remainingMs = resumeTimestamp - now;

      if (remainingMs <= 0) {
        // Gap already expired, clear state
        await _clearGapState();
        return;
      }

      // We're still in a gap from before
      // Check if we're on the same song
      final sequenceState = _player.sequenceState;
      final currentItem = sequenceState.currentSource?.tag;
      if (currentItem is! MediaItem || currentItem.id != songId) {
        await _clearGapState();
        return;
      }

      // Restore gap state
      _isInGap = true;

      // Schedule resume - just_audio will auto-advance to next song
      _gapTimer = Timer(Duration(milliseconds: remainingMs), () {
        _resumeAfterGap(expectedSongId: songId);
      });
    } catch (e) {
      debugPrint('AudioPlayerManager: Failed to restore gap state: $e');
    }
  }

  // ==================== LIFECYCLE ====================

  void _setCacheLimits({required bool isBackground}) {
    if (isBackground) {
      PaintingBinding.instance.imageCache.maximumSize = _backgroundCacheSize;
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          _backgroundCacheBytes;
    } else {
      PaintingBinding.instance.imageCache.maximumSize = _foregroundCacheSize;
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          _foregroundCacheBytes;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_playStartTime != null) {
      _updateDurations();
      _playStartTime = DateTime.now();
    }

    final isBackground = state != AppLifecycleState.resumed;
    NotificationCoverWarmer.instance.setForeground(!isBackground);

    if (isBackground) {
      _flushStats(isTerminal: true);
      savePlaybackState();
      _setCacheLimits(isBackground: true);
      _statsService.flush();
    } else {
      _setCacheLimits(isBackground: false);
    }

    _statsService.setBackground(isBackground);

    final wasBackground = _isBackground;
    _appLifecycleState = state;

    // Pick the prefetching back up for whatever ended up playing while nobody
    // was looking, so opening the player still finds a beat map and a palette
    // waiting.
    if (wasBackground && !isBackground) {
      final currentSong = currentSongNotifier.value;
      _warmBeatAnalysis(currentSong);
      _warmWaveform(currentSong);
      final index = _player.currentIndex;
      if (index != null) _warmThemePalettesAroundIndex(index);
      if (currentSong != null && _ref != null) {
        final filenameAtExtraction = currentSong.filename;
        ColorExtractionService.extractPaletteForCover(currentSong.coverUrl)
            .then((palette) {
          if (_currentSongFilename != filenameAtExtraction) return;
          _ref?.read(themeProvider.notifier).updateExtractedPalette(
                palette,
                forFilename: filenameAtExtraction,
              );
        });
        _preExtractNextColor();
      }
    }
  }

  void onMemoryPressure() {
    // Lower the LRU caps so Flutter trims aggressively on its own; this
    // avoids the wholesale clear() that would force regen of expensive
    // blurred backgrounds.
    PaintingBinding.instance.imageCache.maximumSize = 20;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 5 * 1024 * 1024;
  }

  // ==================== STATS & SHUFFLE ====================

  void _preExtractNextColor() {
    // Same reasoning as _warmThemePalettesAroundIndex: a head start on a theme
    // nobody is looking at is just a cover decode charged to the battery.
    if (_isBackground) return;

    final currentIndex = _player.currentIndex;
    if (currentIndex == null || _effectiveQueue.isEmpty) return;

    final nextIndex = currentIndex + 1;
    if (nextIndex >= _effectiveQueue.length) return;

    final nextSong = _effectiveQueue[nextIndex].song;
    if (nextSong.coverUrl != null) {
      ColorExtractionService.extractPaletteForCover(nextSong.coverUrl);
    }
  }

  /// Whether the app is out of sight. Anything that exists only to have a
  /// visual ready sooner can wait for [didChangeAppLifecycleState] to bring it
  /// back.
  bool get _isBackground => _appLifecycleState != AppLifecycleState.resumed;

  /// Kicks off beat analysis for the track that just started and the one after
  /// it.
  ///
  /// Lives here rather than in the player screen so a song is analysed the
  /// first time it is *played*, not the first time its artwork happens to be on
  /// screen. Analysing the next track too means skipping forward finds a beat
  /// map already waiting instead of a few seconds of idle motion.
  ///
  /// Everything downstream is cached and de-duplicated, so calling this on
  /// every track change is cheap after the first pass through a library.
  void _warmBeatAnalysis(Song? current) {
    if (_ref == null) return;

    // Beat analysis decodes the whole track to PCM and runs an FFT over it. In
    // the background that is minutes of CPU per track — with the screen off —
    // for a grid that only drives the player's motion. Nothing is lost by
    // waiting: the player screen analyses on demand when it opens, and the
    // resume path below re-warms whatever is playing then.
    if (_isBackground) return;

    final settings = _ref!.read(settingsProvider);
    if (!settings.beatReactiveCoverEnabled &&
        !settings.beatReactiveParticlesEnabled &&
        settings.visualizerMode != VisualizerMode.synced) {
      return;
    }

    final service = _ref!.read(beatAnalysisServiceProvider);

    // Streamed tracks are decoded from their cached download, which only
    // exists once the track has been streamed through; the service skips those
    // until then.
    if (current != null) service.prefetchSong(current);

    final currentIndex = _player.currentIndex;
    if (currentIndex == null || _effectiveQueue.isEmpty) return;
    final nextIndex = currentIndex + 1;
    if (nextIndex >= _effectiveQueue.length) return;

    service.prefetchSong(_effectiveQueue[nextIndex].song);
  }

  /// Builds the seek bar's waveform ahead of time and writes it to the cache.
  ///
  /// The decode is the expensive part; doing it here means the next visit to
  /// the player reads a small JSON file instead. Local files are decoded from
  /// the audio, streamed tracks from their completed download once it exists.
  void _warmWaveform(Song? current) {
    final ref = _ref;
    if (ref == null || _isBackground) return;
    if (!ref.read(settingsProvider).showWaveform) return;
    final service = ref.read(waveformServiceProvider);

    void warmSong(Song? song) {
      if (song == null) return;
      if (song.isLocal) {
        unawaited(service.warm(song.filename, song.url));
        return;
      }
      // A streamed track has no file of its own. Its download only becomes
      // decodable once the whole track is cached, so the replay path warms from
      // there; the first play is covered by the seek bar's own retry.
      final id = song.remoteId;
      if (!song.isYoutube || id == null || id.isEmpty) return;
      unawaited(() async {
        final file = await OnlineAudioCache.instance.completeFile(
          OnlineAudioCache.providerYouTube,
          id,
        );
        if (file == null) return;
        await service.warm(song.filename, file.path);
      }());
    }

    warmSong(current);

    final index = _player.currentIndex;
    if (index == null || _effectiveQueue.isEmpty) return;
    final next = index + 1;
    if (next >= _effectiveQueue.length) return;
    warmSong(_effectiveQueue[next].song);
  }

  void _warmThemePalette(String? coverUrl) {
    if (coverUrl == null || coverUrl.isEmpty) return;
    unawaited(ColorExtractionService.extractPaletteForCover(coverUrl));
  }

  void _optimizeCoverForCurrentSong(Song? song) {
    if (_isBackground) return;
    if (song == null || !song.isLocal) return;
    if (song.coverUrl == null || song.coverUrl!.isEmpty) return;
    final coverPath = song.coverUrl!;
    if (p.basename(coverPath).startsWith('c_')) return;

    unawaited(() async {
      try {
        final coversDir = await ScannerService.coversDirectory();
        final file = File(coverPath);
        if (!await file.exists()) return;
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) return;
        final coversDirPath = coversDir.path;
        final newPath =
            await Isolate.run(() => CoverOptimizer.saveOptimizedCover(
                  bytes,
                  coversDirPath,
                ));
        if (newPath != coverPath) {
          final updatedSong = song.copyWith(coverUrl: newPath);
          await DatabaseService.instance.insertSongsBatch([updatedSong]);
          _songMap[song.filename] = updatedSong;
          if (_currentSongFilename == song.filename) {
            currentSongNotifier.value = updatedSong;
          }
        }
      } catch (e) {
        debugPrint('Failed to optimize cover for ${song.title}: $e');
      }
    }());
  }

  /// Purely a head start on the theme for tracks either side of this one. The
  /// track actually playing is extracted separately, so skipping this in the
  /// background costs nothing but a decode the user cannot see.
  ///
  /// Used on explicit navigation (queue reorder, skip-to, resume) rather than
  /// on automatic track changes — those already cover current + next through
  /// the dedicated extract and [_preExtractNextColor].
  void _warmThemePalettesAroundIndex(int centerIndex, {int radius = 1}) {
    if (_effectiveQueue.isEmpty) return;
    if (_isBackground) return;

    for (int offset = -radius; offset <= radius; offset++) {
      final index = centerIndex + offset;
      if (index < 0 || index >= _effectiveQueue.length) continue;
      _warmThemePalette(_effectiveQueue[index].song.coverUrl);
    }
  }

  Future<ShuffleState?> syncShuffleState() async {
    return _shuffleState;
  }

  Future<void> _saveShuffleState() async {
    await _storageService.saveShuffleState(_shuffleState.toJson());
  }

  /// Queues a playback-state write, coalescing bursts.
  ///
  /// The state embeds both full queues, so encoding it is proportional to the
  /// library size — and startup alone triggers it from a dozen call sites.
  /// Callers that need the write to have landed use [savePlaybackState].
  void _savePlaybackState() {
    if (_playbackStateSaveTimer?.isActive ?? false) return;
    _playbackStateSaveTimer = Timer(_playbackStateSaveInterval, () {
      unawaited(_writePlaybackState());
    });
  }

  /// Records the playback state. [positionMs] overrides the live playhead for
  /// callers that are adopting a position the player has not settled onto yet.
  Future<void> _writePlaybackState(
      {bool force = false, int? positionMs}) async {
    final currentIndex = _player.currentIndex;
    final currentSong =
        (currentIndex != null && currentIndex < _effectiveQueue.length)
            ? _effectiveQueue[currentIndex].song
            : null;

    final state = {
      'last_song_filename': currentSong?.filename,
      'last_effective_queue': _effectiveQueue.map((e) => e.toJson()).toList(),
      'last_original_queue': _originalQueue.map((e) => e.toJson()).toList(),
      'last_position_ms': positionMs ?? _player.position.inMilliseconds,
      'current_playlist_id': _currentPlaylistId,
      'current_queue_snapshot_id': _currentQueueSnapshotId,
      'preferred_media_mode': preferredMediaModeNotifier.value.name,
    };

    await _storageService.savePlaybackState(state);
    unawaited(_syncCurrentQueue(currentSong?.filename,
        force: force, positionMs: positionMs));
  }

  /// Writes the playback state immediately, cancelling any coalesced write.
  Future<void> savePlaybackState() async {
    _playbackStateSaveTimer?.cancel();
    await _writePlaybackState(force: true);
  }

  // Latched once the user has played something, so a cold-start default queue
  // never overwrites the cloud copy.
  bool _queueSyncArmed = false;
  List<String> _syncedEff = const [];
  List<String> _syncedOrig = const [];
  String? _syncedCurrent;
  int _syncedPositionMs = 0;

  Future<void> _syncCurrentQueue(String? current,
      {required bool force, int? positionMs}) async {
    if (!_queueSyncArmed) {
      if (!_player.playing) return;
      _queueSyncArmed = true;
    }
    final eff = [for (final e in _effectiveQueue) e.song.filename];
    final orig = [for (final e in _originalQueue) e.song.filename];
    final posMs = positionMs ?? _player.position.inMilliseconds;
    final changed = current != _syncedCurrent ||
        !listEquals(eff, _syncedEff) ||
        !listEquals(orig, _syncedOrig);
    if (!changed && !(force && (posMs - _syncedPositionMs).abs() > 5000)) {
      return;
    }
    _syncedEff = eff;
    _syncedOrig = orig;
    _syncedCurrent = current;
    _syncedPositionMs = posMs;
    try {
      await DatabaseService.instance.saveCurrentQueue({
        'current': current,
        'position_ms': posMs,
        'effective': eff,
        'original': listEquals(eff.toSet().toList()..sort(),
                    orig.toSet().toList()..sort()) &&
                eff.length == orig.length
            ? null
            : orig,
        'playlist_id': _currentPlaylistId,
      });
    } catch (e) {
      debugPrint('AudioPlayerManager: current queue sync write failed: $e');
    }
  }

  /// Replaces the queue with one another device synced. Only reached from a
  /// user-pressed sync with "prefer cloud queue" on, so it applies even while
  /// playing; the queue arrives with the event rather than being re-read from
  /// the database, where a concurrent local save could already have
  /// overwritten it.
  Future<void> _applySyncedQueue(Map<String, dynamic> q) async {
    final wasPlaying = _player.playing;
    List<QueueItem> items(Object? names) => [
          for (final n in (names as List? ?? const []))
            if (_lookupSong('$n') case final song?) QueueItem(song: song),
        ];
    final eff = items(q['effective']);
    if (eff.isEmpty) return;
    final orig = q['original'] == null ? List.of(eff) : items(q['original']);
    final idx = eff.indexWhere((e) => e.song.filename == q['current']);
    final pulledMs = (q['position_ms'] as num?)?.toInt() ?? 0;
    await _runSerializedQueueMutation(() async {
      _effectiveQueue = eff;
      _originalQueue = orig.isEmpty ? List.of(eff) : orig;
      _currentPlaylistId = q['playlist_id'] as String?;
      _rememberedUpcomingIds = null;
      _pendingQueueSongs = null;
      _pendingQueuePlaylistId = null;
      pendingQueueNotifier.value = false;
      _resetFading();
      await _rebuildQueue(
        initialIndex: idx < 0 ? 0 : idx,
        startPlaying: wasPlaying,
        initialPosition: idx < 0 ? null : Duration(milliseconds: pulledMs),
      );
      // A fresh entry owned by this device, so plays from here on carry a
      // queue id and later edits do not touch the other device's snapshot.
      await _saveQueueSnapshot(
        [for (final e in _effectiveQueue) e.song],
        playlistId: _currentPlaylistId,
      );
    });
    _syncedEff = [for (final e in _effectiveQueue) e.song.filename];
    _syncedOrig = [for (final e in _originalQueue) e.song.filename];
    _syncedCurrent = q['current'] as String?;
    _syncedPositionMs = idx < 0 ? 0 : pulledMs;
    _updateQueueNotifier();
    // Persist the position just adopted rather than re-reading the player, which
    // has only just been handed the sources. No force: this row came from the
    // cloud and rewriting it from an unsettled playhead is what lost it.
    await _writePlaybackState(positionMs: _syncedPositionMs);
  }

  void _updateDurations() {
    if (_playStartTime != null) {
      final now = DateTime.now();
      final diff = now.difference(_playStartTime!).inMilliseconds / 1000.0;
      if (_appLifecycleState == AppLifecycleState.resumed) {
        _foregroundDuration += diff;
      } else {
        _backgroundDuration += diff;
      }
    }
  }

  void _flushStats({bool isTerminal = false}) {
    if (_currentSongFilename == null) return;
    if (_playStartTime != null) _updateDurations();

    final song = _resolveSong(_currentSongFilename!);
    final totalLength =
        (song?.duration?.inMilliseconds.toDouble() ?? 0.0) / 1000.0;
    double effectiveTotalLength = totalLength;
    final firstSongStartSec = _sessionFirstSongStartSec;
    final isFirstSongMidStart =
        _currentSongFilename == _sessionFirstSongFilename &&
            firstSongStartSec != null &&
            firstSongStartSec > 0;
    if (isFirstSongMidStart && totalLength > 0) {
      final adjustedLength = max(0.0, totalLength - firstSongStartSec);
      if (adjustedLength > 0) {
        effectiveTotalLength = adjustedLength;
      }
    }

    double finalDuration = _foregroundDuration + _backgroundDuration;

    if (finalDuration > 0.5 && !isExternalSongFilename(_currentSongFilename!)) {
      _tasteDirty = true;
      final completed = effectiveTotalLength > 0 &&
          finalDuration / effectiveTotalLength >= 0.85;
      final artist = song?.artist ?? '';
      if (completed && artist.isNotEmpty) {
        _recentCompletedArtists.add(artist);
        if (_recentCompletedArtists.length > _sessionArtistWindow) {
          _recentCompletedArtists.removeAt(0);
        }
      }
      // Transient open-with plays leave no stats rows: their cache-path keys
      // could never rejoin the library entry they may later be imported as.
      unawaited(_statsService.trackStats({
        'song_filename': _currentSongFilename!,
        'duration_played': finalDuration,
        'foreground_duration': _foregroundDuration,
        'background_duration': _backgroundDuration,
        'total_length': effectiveTotalLength,
        'source': _sourceFor(_currentQueueId)?.dbValue,
        'queue_id': _currentSongQueueSnapshotId ??= _currentQueueSnapshotId,
      }));
    }
    _foregroundDuration = 0.0;
    _backgroundDuration = 0.0;
    if (isTerminal) {
      _playStartTime = null;
    } else if (_playStartTime != null) {
      _playStartTime = DateTime.now();
    }
    unawaited(_statsService.flush().whenComplete(() {
      _tasteDirty = true;
      // Committed: the queue's played list now includes what just finished.
      queuePlayedRevision.value++;
    }));
    _ref?.read(songsProvider.notifier).refreshPlayCounts();
  }

  // ==================== INIT & QUEUE ====================

  static List<QueueItem> _parseQueueItems(List<dynamic> json) {
    final items = <QueueItem>[];
    for (final entry in json) {
      try {
        items.add(QueueItem.fromJson(entry));
      } catch (_) {
        // A single unreadable entry must not cost us the whole saved queue.
      }
    }
    return items;
  }

  /// The subset of [paths] that no longer exist on disk, resolved off the UI
  /// thread.
  static Future<Set<String>> _findMissingSongPaths(Set<String> paths) async {
    final candidates = paths.where((path) => path.isNotEmpty).toList();
    if (candidates.isEmpty) return const <String>{};
    try {
      return await Isolate.run(() => {
            for (final path in candidates)
              if (!File(path).existsSync()) path,
          });
    } catch (e) {
      // If the isolate cannot run, keep every entry rather than wrongly
      // dropping the user's whole queue.
      debugPrint('AudioPlayerManager: queue existence check failed: $e');
      return const <String>{};
    }
  }

  Future<void> init(List<Song> songs, {bool autoSelect = false}) async {
    _allSongs = songs;
    _tasteDirty = true;
    if (_shuffleState.config.personality == ShufflePersonality.smart) {
      unawaited(tasteSnapshot());
    }
    _songMap = {for (var s in songs) s.filename: s};
    await _player.setShuffleModeEnabled(false);

    await DatabaseService.instance.init();

    final savedState = await _storageService.loadPlaybackState();

    if (savedState != null) {
      try {
        final savedPreferredMode =
            savedState['preferred_media_mode'] as String?;
        preferredMediaModeNotifier.value = savedPreferredMode == 'video'
            ? PlaybackMediaMode.video
            : PlaybackMediaMode.audio;

        final List<dynamic> effJson = savedState['last_effective_queue'] ?? [];
        final List<dynamic> origJson = savedState['last_original_queue'] ?? [];

        final restoreWatch = Stopwatch()..start();
        final effItems = _parseQueueItems(effJson);
        final origItems = _parseQueueItems(origJson);

        // Both queues are the whole library on a cold start, so checking each
        // file inline would be hundreds of blocking stat calls on the UI
        // thread. One isolate covers both lists at once.
        final missing = await _findMissingSongPaths({
          for (final item in effItems) item.song.url,
          for (final item in origItems) item.song.url,
        });
        // Remote entries have no local path to lose; their audio is either
        // cached or resolved when playback reaches them. Filtering them out
        // here would drop an online queue on every restart.
        bool exists(QueueItem item) => item.song.isLocal
            ? item.song.url.isNotEmpty && !missing.contains(item.song.url)
            : true;

        _effectiveQueue = effItems.where(exists).toList();
        _originalQueue = origItems.where(exists).toList();
        // Surviving staged open-with copies restore as embedded Song JSON;
        // re-register them so now-playing and queue lookups keep resolving
        // after the library maps are rebuilt without them.
        ensureKnownSongs([
          for (final item in _effectiveQueue) item.song,
          for (final item in _originalQueue) item.song,
        ]);
        _logSlow('init: restored saved queue', restoreWatch);

        if (_effectiveQueue.isNotEmpty || _originalQueue.isNotEmpty) {
          _currentPlaylistId = savedState['current_playlist_id'];
          _currentQueueSnapshotId = savedState['current_queue_snapshot_id'];

          final savedPositionMs = savedState['last_position_ms'] ?? 0;
          final lastSongFilename = savedState['last_song_filename'];

          int initialIndex = 0;
          Duration? resumePosition;

          if (lastSongFilename != null) {
            initialIndex = _effectiveQueue.indexWhere(
              (item) => item.song.filename == lastSongFilename,
            );
            if (initialIndex != -1) {
              resumePosition = Duration(milliseconds: savedPositionMs);
              _previousSessionSongFilename = lastSongFilename;
              _isResumedFromPreviousSession = true;
              _pendingResumedSongStartSec =
                  max(0.0, resumePosition.inMilliseconds / 1000.0);
            } else {
              initialIndex = 0;
            }
          }

          await _rebuildQueue(
            initialIndex: initialIndex,
            startPlaying: false,
            initialPosition: resumePosition,
          );
          _updateEffectivePlaybackMode();
          return;
        }
      } catch (e) {
        // Ignore
      }
    }

    _originalQueue = songs.map((s) => QueueItem(song: s)).toList();
    _effectiveQueue = List.from(_originalQueue);

    int initialIndex = 0;
    Duration? resumePosition;

    if (savedState != null) {
      final lastSongFilename = savedState['last_song_filename'] as String?;
      final savedPositionMs = savedState['last_position_ms'] as int?;
      if (lastSongFilename != null && savedPositionMs != null) {
        final songIndex =
            songs.indexWhere((s) => s.filename == lastSongFilename);
        if (songIndex != -1) {
          initialIndex = songIndex;
          resumePosition = Duration(milliseconds: savedPositionMs);
          _previousSessionSongFilename = lastSongFilename;
          _isResumedFromPreviousSession = true;
          _pendingResumedSongStartSec =
              max(0.0, resumePosition.inMilliseconds / 1000.0);
        }
      }
    }

    if (autoSelect && songs.isNotEmpty && resumePosition == null) {
      initialIndex = Random().nextInt(songs.length);
    }
    await _rebuildQueue(
        initialIndex: initialIndex,
        startPlaying: false,
        initialPosition: resumePosition);
    _updateEffectivePlaybackMode();
  }

  void refreshSongs(
    List<Song> newSongs, {
    String? previousFilename,
    Map<String, String>? filenameRemaps,
  }) {
    final oldSongMapKeys = _songMap.keys.toSet();
    _allSongs = newSongs.where((s) => !_isHidden(s.filename)).toList();
    _tasteDirty = true;
    _songMap = {for (var s in _allSongs) s.filename: s};

    final currentIdx = _player.currentIndex;
    final currentItemBefore =
        (currentIdx != null && currentIdx < _effectiveQueue.length)
            ? _effectiveQueue[currentIdx]
            : null;

    Song? renamedSong;
    if (previousFilename != null) {
      renamedSong = _allSongs
          .where((s) => !oldSongMapKeys.contains(s.filename))
          .firstOrNull;
    }

    // A batch rename knows exactly which old name became which new one, so it
    // hands the mapping over rather than making each entry infer its own
    // successor. Inferring cannot work past one song: the "key that wasn't here
    // before" test has already been consumed by the first rename.
    String? remapped(String filename) => filenameRemaps?[filename];

    Song resolve(Song song) {
      final mapped = remapped(song.filename);
      if (mapped != null && mapped != song.filename) {
        return _lookupSong(mapped) ?? _lookupSong(song.filename) ?? song;
      }
      if (previousFilename != null &&
          song.filename == previousFilename &&
          renamedSong != null) {
        return _lookupSong(renamedSong.filename) ?? song;
      }
      return _lookupSong(song.filename) ?? song;
    }

    _effectiveQueue = _effectiveQueue
        .map((item) => item.copyWith(song: resolve(item.song)))
        .toList();
    _originalQueue = _originalQueue
        .map((item) => item.copyWith(song: resolve(item.song)))
        .toList();

    _updateQueueNotifier();
    _savePlaybackState();
    _updateEffectivePlaybackMode();

    final remappedCurrent =
        _currentSongFilename == null ? null : remapped(_currentSongFilename!);
    if (remappedCurrent != null && remappedCurrent != _currentSongFilename) {
      _currentSongFilename = remappedCurrent;
    } else if (previousFilename != null &&
        _currentSongFilename == previousFilename &&
        renamedSong != null) {
      _currentSongFilename = renamedSong.filename;
    }

    final currentFilename = _currentSongFilename;
    if (currentFilename != null) {
      final updated = _lookupSong(currentFilename);
      if (updated != null && updated != currentSongNotifier.value) {
        currentSongNotifier.value = updated;
      }
    }

    if (currentIdx != null &&
        currentItemBefore != null &&
        (filenameRemaps?.isNotEmpty ?? false || previousFilename != null)) {
      _rebuildQueue(initialIndex: currentIdx, startPlaying: _player.playing);
    }
  }

  /// Builds the player entry for [item].
  ///
  /// [awaitCover] is for the one song the user is starting: it blocks on
  /// producing the square notification cover so the notification is right
  /// immediately. Every other entry takes the synchronous path — an already
  /// cached cover if there is one, otherwise the raw art, with the square
  /// version left to [NotificationCoverWarmer]. Awaiting it for a whole queue
  /// is what used to stall a cold start for the best part of a minute.
  ///
  /// [resolveRemoteNow] only matters for YouTube: the track that is starting
  /// resolves its stream immediately, while queued entries stay lazy.
  Future<AudioSource> _createAudioSource(
    QueueItem item, {
    bool awaitCover = false,
    bool resolveRemoteNow = false,
  }) async {
    final song = item.song;
    Uri? audioUri;
    String? lazyYouTubeId;
    late final String playbackAudioPath;
    String? videoPath;
    if (song.isYoutube) {
      final videoId = song.remoteId;
      if (videoId == null || videoId.isEmpty) {
        throw const YouTubeApiException('YouTube video ID is missing.');
      }
      unawaited(OnlineAudioCache.instance.ensureSwept());
      final cached = await OnlineAudioCache.instance.completeFile(
        OnlineAudioCache.providerYouTube,
        videoId,
      );
      if (cached != null) {
        unawaited(OnlineAudioCache.instance.touch(cached));
        audioUri = Uri.file(cached.path);
        playbackAudioPath = cached.path;
        final ref = _ref;
        if (ref != null && ref.read(settingsProvider).showWaveform) {
          unawaited(
            ref.read(waveformServiceProvider).warm(song.filename, cached.path),
          );
        }
      } else {
        // Resolved on the first byte request, so a queue of search results
        // costs no network until a track is actually played.
        lazyYouTubeId = videoId;
        playbackAudioPath = '';
      }
    } else {
      final mediaPaths = await _resolvePlayableMediaPaths(song);
      audioUri = _mediaUri(mediaPaths.audioPath);
      playbackAudioPath = mediaPaths.audioPath;
      videoPath = mediaPaths.videoPath;
    }

    Uri? artUri;
    if (song.coverUrl != null && song.coverUrl!.isNotEmpty) {
      final coverSizingMode = _ref?.read(settingsProvider).coverSizingMode ??
          PlayerCoverSizingMode.sourceAspect;
      String? coverPath;
      if (song.isRemote) {
        coverPath = song.coverUrl;
      } else if (awaitCover) {
        final fileManager = _ref?.read(fileManagerServiceProvider);
        coverPath = fileManager == null
            ? song.coverUrl
            : await fileManager.getOrCreateNotificationCover(
                song,
                coverSizingMode,
              );
      } else {
        coverPath =
            FileManagerService.peekNotificationCover(song, coverSizingMode) ??
                song.coverUrl;
      }
      if (coverPath != null && coverPath.isNotEmpty) {
        // Never emit an invalid artUri: audio_service drops the entire
        // notification when ContentResolver cannot open it. Some OEMs are
        // strict and drop on large or missing covers.
        // content:// URIs are resolved by the provider, file paths must exist.
        final isContentUri = coverPath.startsWith('content://');
        final isRemoteUri =
            coverPath.startsWith('http://') || coverPath.startsWith('https://');
        final fileExists =
            isContentUri || isRemoteUri || !_isMissingLocalFile(coverPath);
        if (fileExists) {
          try {
            artUri = _mediaUri(coverPath);
          } catch (_) {
            artUri = null;
          }
        } else {
          artUri = null;
        }
      }
    }

    final tag = MediaItem(
      id: song.filename,
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: song.duration,
      artUri: artUri,
      extras: {
        'hasLyrics': song.hasLyrics,
        'hasVideo': song.hasVideo,
        'remoteUrl': song.isLocal ? song.url : '',
        'queueId': item.queueId,
        'audioPath': song.isLocal ? song.url : '',
        'playbackAudioPath': playbackAudioPath,
        if (videoPath != null) 'videoPath': videoPath,
      },
    );

    if (lazyYouTubeId != null) {
      return YouTubeAudioSource(
        videoId: lazyYouTubeId,
        title: song.title,
        artist: song.artist,
        tag: tag,
      );
    }
    return AudioSource.uri(audioUri!, tag: tag);
  }

  Future<({String audioPath, String? videoPath})> _resolvePlayableMediaPaths(
    Song song,
  ) async {
    if (!Platform.isIOS) {
      return (audioPath: song.url, videoPath: song.hasVideo ? song.url : null);
    }

    final ffmpeg = FFmpegService();
    final needsAudioProxy = !_isIosNativeAudioPath(song.url);
    final audioPath = needsAudioProxy
        ? (await ffmpeg.prepareIosAudioProxy(song.url)) ?? song.url
        : song.url;

    String? videoPath = song.hasVideo ? song.url : null;
    if (song.hasVideo && !_isIosNativeVideoPath(song.url)) {
      videoPath = await ffmpeg.prepareIosVideoProxy(song.url) ?? song.url;
    }

    return (audioPath: audioPath, videoPath: videoPath);
  }

  /// MediaStore rows arrive as content:// URIs while scanned files are plain
  /// paths. ExoPlayer handles both, but Uri.file() must never wrap the
  /// former — it would produce an unplayable file://content://... URI.
  /// Streamed open-with links (http/https) pass through for the same reason.
  static Uri _mediaUri(String path) {
    if (path.startsWith('content://')) return Uri.parse(path);
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    return Uri.file(path);
  }

  /// Plain paths that no longer exist on disk cannot play. Content URIs skip
  /// the check since their availability is up to the content provider.
  static bool _isMissingLocalFile(String path) {
    if (path.startsWith('content://')) return false;
    try {
      return !File(path).existsSync();
    } on FileSystemException {
      return true;
    }
  }

  bool _isIosNativeAudioPath(String path) {
    const supported = {
      '.aac',
      '.aif',
      '.aiff',
      '.caf',
      '.flac',
      '.m4a',
      '.m4b',
      '.mp3',
      '.mp4',
      '.m4v',
      '.mov',
      '.wav',
    };
    return supported.contains(p.extension(path).toLowerCase());
  }

  bool _isIosNativeVideoPath(String path) {
    const supported = {
      '.3gp',
      '.m4v',
      '.mov',
      '.mp4',
    };
    return supported.contains(p.extension(path).toLowerCase());
  }

  void _updateQueueNotifier() {
    final next = List<QueueItem>.from(_effectiveQueue);
    // Skip the new-list allocation and listener notification when the
    // queue contents are identical. queueNotifier listeners rebuild
    // large UI sections, so the comparison is well worth the O(N) walk.
    final current = queueNotifier.value;
    if (_listEqualsQueue(current, next)) {
      return;
    }
    queueNotifier.value = next;
  }

  static bool _listEqualsQueue(List<QueueItem> a, List<QueueItem> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].queueId != b[i].queueId) return false;
    }
    return true;
  }

  /// Runs [body] with the sequence-sync listener suppressed, so our own
  /// intermediate player states can never be mistaken for an outside edit.
  Future<T> _guardPlayerMutation<T>(Future<T> Function() body) async {
    _playerMutationDepth++;
    try {
      return await body();
    } finally {
      _playerMutationDepth--;
      if (_playerMutationDepth == 0) {
        // Publish the authoritative model once the whole mutation has landed.
        _updateQueueNotifier();
        _emitSettledSequence(_player.sequenceState);
      }
    }
  }

  Future<T> _runSerializedQueueMutation<T>(
    Future<T> Function() mutation,
  ) {
    final next =
        _queueMutationChain.then((_) => _guardPlayerMutation(mutation));
    _queueMutationChain = next.then<void>(
      (_) {},
      onError: (e, _) {
        debugPrint('Queue mutation failed: $e');
      },
    );
    return next;
  }

  bool _sameQueueSnapshot(List<QueueItem> first, List<QueueItem> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (int i = 0; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }
    return true;
  }

  void _syncEffectiveQueueWithPlayerSequence(SequenceState state) {
    // Our own mutations rewrite the player's sources step by step; adopting an
    // intermediate sequence here would truncate the queue mid-edit.
    if (_playerMutationDepth > 0) return;

    final sequence = state.sequence;
    if (sequence.isEmpty) return;

    final entries = <queue_ops.SequenceEntry>[];
    for (final source in sequence) {
      final tag = source.tag;
      if (tag is! MediaItem) continue;
      entries.add((
        filename: tag.id,
        queueId: tag.extras?['queueId'] as String?,
      ));
    }

    final rebuilt = queue_ops.reconcileWithSequence(
      _effectiveQueue,
      entries,
      (filename) {
        final song = _resolveSong(filename);
        return song == null ? null : QueueItem(song: song);
      },
    );

    if (rebuilt.isEmpty || _sameQueueSnapshot(_effectiveQueue, rebuilt)) return;
    _effectiveQueue = rebuilt;
    _updateQueueNotifier();
    _savePlaybackState();
  }

  Future<void> shuffleAndPlay(
    List<Song> songs, {
    ShuffleContext? context,
    bool saveSnapshot = true,
  }) async {
    if (songs.isEmpty) return;

    _resetFading();
    await _player.setShuffleModeEnabled(false);

    _shuffleState = _shuffleState.copyWith(
      config: _shuffleState.config.copyWith(enabled: true),
    );
    shuffleNotifier.value = true;
    shuffleStateNotifier.value = _shuffleState;
    _saveShuffleState();

    // Clear any pending queue replacement
    _pendingQueueSongs = null;
    _pendingQueuePlaylistId = null;
    pendingQueueNotifier.value = false;

    // Shuffle weighting (affinities, anti-repeat) must reflect the freshest
    // DB state. Without this, two rapid shuffles within the 30s cache window
    // would reuse the identical playHistory and could surface the same songs
    // again even though the previous queue's songs should now be penalised
    // via the queue overlay in _loadShuffleModel. Invalidate so the DB side
    // is re-read and the overlay is prepended correctly.
    _invalidateShuffleCache();
    _rememberedUpcomingIds = null;

    // Set up fresh queue (always replaces current queue entirely)
    _originalQueue = songs.map((s) => QueueItem(song: s)).toList();
    _currentPlaylistId = null;

    // Pick the opening song from the same weighted distribution as the rest of
    // the queue. This used to be a uniform Random().nextInt over the whole
    // library, which meant the one song the listener actually hears on pressing
    // shuffle ignored every personality and weighting setting.
    final selectedItem =
        await _selectSeedItem(_originalQueue, context: context);

    // Build shuffled effective queue for the selected song
    final otherItems = List<QueueItem>.from(_originalQueue)
      ..removeWhere((item) => item.queueId == selectedItem.queueId);
    final shuffledOthers = await _weightedShuffle(
      otherItems,
      lastItem: selectedItem,
      context: context,
    );
    _effectiveQueue = [selectedItem, ...shuffledOthers];
    _updateQueueNotifier();

    // Replace player queue and start playing
    await _rebuildQueue(initialIndex: 0, startPlaying: true);

    // Save a queue-history snapshot of the shuffled order, unless this shuffle
    // came from a folder or ad-hoc song list.
    if (saveSnapshot) {
      await _saveQueueSnapshot(
        [for (final item in _effectiveQueue) item.song],
        playlistId: null,
      );
    } else {
      _currentQueueSnapshotId = null;
    }

    _savePlaybackState();
  }

  /// Same shuffle as [shuffleAndPlay], but the current song keeps playing and
  /// the freshly shuffled library replaces everything after it.
  Future<void> shuffleAfterCurrentSong(
    List<Song> songs, {
    ShuffleContext? context,
  }) async {
    if (songs.isEmpty) return;

    final rawIndex = _player.currentIndex;
    if (_effectiveQueue.isEmpty ||
        rawIndex == null ||
        rawIndex < 0 ||
        rawIndex >= _effectiveQueue.length) {
      return shuffleAndPlay(songs);
    }

    _shuffleState = _shuffleState.copyWith(
      config: _shuffleState.config.copyWith(enabled: true),
    );
    shuffleNotifier.value = true;
    shuffleStateNotifier.value = _shuffleState;
    _saveShuffleState();
    _invalidateShuffleCache();
    _rememberedUpcomingIds = null;

    final currentItem = _effectiveQueue[rawIndex];
    final candidates = songs
        .where((s) => s.filename != currentItem.song.filename)
        .map((s) => QueueItem(song: s))
        .toList();
    if (candidates.isEmpty) return;

    final shuffled = await _weightedShuffle(
      candidates,
      lastItem: currentItem,
      context: context,
    );
    if (shuffled.isEmpty) return;

    await _runSerializedQueueMutation(() async {
      if (_effectiveQueue.isEmpty) return;
      final currentIndex =
          (_player.currentIndex ?? 0).clamp(0, _effectiveQueue.length - 1);
      _effectiveQueue = [
        ..._effectiveQueue.sublist(0, currentIndex + 1),
        ...shuffled,
      ];
      await _mutateQueueAfterIndex(currentIndex);
      _warmThemePalettesAroundIndex(currentIndex);
      _updateQueueNotifier();
      await _updateCurrentSnapshotSongs();
      _savePlaybackState();
    });
  }

  /// Same shuffle as [shuffleAndPlay], but the whole current queue plays out
  /// first and the freshly shuffled library is appended at the end.
  Future<void> shuffleAfterCurrentQueue(
    List<Song> songs, {
    ShuffleContext? context,
  }) async {
    if (songs.isEmpty) return;
    if (_effectiveQueue.isEmpty) {
      return shuffleAndPlay(songs, context: context);
    }

    _shuffleState = _shuffleState.copyWith(
      config: _shuffleState.config.copyWith(enabled: true),
    );
    shuffleNotifier.value = true;
    shuffleStateNotifier.value = _shuffleState;
    _saveShuffleState();
    _invalidateShuffleCache();
    _rememberedUpcomingIds = null;

    final shuffled = await _weightedShuffle(
      songs.map((s) => QueueItem(song: s)).toList(),
      lastItem: _effectiveQueue.last,
      context: context,
    );
    if (shuffled.isEmpty) return;

    await _runSerializedQueueMutation(() async {
      for (final item in shuffled) {
        _effectiveQueue.add(item);
        try {
          final source = await _createAudioSource(item);
          await _player.addAudioSource(source);
        } catch (e) {
          _effectiveQueue.remove(item);
          rethrow;
        }
      }
      _updateQueueNotifier();
      await _updateCurrentSnapshotSongs();
      _savePlaybackState();
    });
  }

  /// Flips between the remembered shuffle and the original order. Rapid taps
  /// collapse into one reorder of the latest state.
  Future<void> toggleShuffle() => _setShuffleMode(!shuffleNotifier.value);

  /// Long-press on the shuffle button: roll a brand-new shuffle instead of
  /// restoring the remembered one.
  Future<void> newShuffleQueue() {
    _rememberedUpcomingIds = null;
    return _setShuffleMode(true);
  }

  Future<void> _setShuffleMode(bool enabled) async {
    shuffleNotifier.value = enabled;
    _shuffleState = _shuffleState.copyWith(
      config: _shuffleState.config.copyWith(enabled: enabled),
    );
    shuffleStateNotifier.value = _shuffleState;
    _saveShuffleState();

    _shuffleOrderDirty = true;
    if (_shuffleOrderApplying) return;

    _shuffleOrderApplying = true;
    try {
      while (_shuffleOrderDirty) {
        _shuffleOrderDirty = false;
        await _applyShuffleOrder(shuffleNotifier.value);
      }
    } finally {
      _shuffleOrderApplying = false;
    }
  }

  Future<void> _applyShuffleOrder(bool enabled) async {
    await _runSerializedQueueMutation(() async {
      if (_effectiveQueue.isEmpty) return;

      final currentIndex =
          (_player.currentIndex ?? 0).clamp(0, _effectiveQueue.length - 1);
      final currentItem = _effectiveQueue[currentIndex];
      final upcoming = _effectiveQueue.sublist(currentIndex + 1);

      if (upcoming.length > 1) {
        final List<QueueItem> reordered;
        if (enabled) {
          final remembered = _rememberedUpcomingIds;
          if (remembered != null) {
            reordered = applyRememberedOrder<QueueItem>(
              upcoming,
              remembered,
              (item) => item.queueId,
            );
          } else {
            reordered = await _weightedShuffle(upcoming, lastItem: currentItem);
          }
          _rememberedUpcomingIds = reordered.map((i) => i.queueId).toList();
        } else {
          reordered = _inOriginalOrder(upcoming, currentItem);
        }

        _effectiveQueue = [
          ..._effectiveQueue.sublist(0, currentIndex + 1),
          ...reordered,
        ];
        await _mutateQueueAfterIndex(currentIndex);
        _updateQueueNotifier();
        _warmThemePalettesAroundIndex(currentIndex);
      }

      if (_currentQueueSnapshotId != null) {
        await _updateCurrentSnapshotSongs();
      }
      _savePlaybackState();
    });
  }

  Future<void> replaceQueue(
    List<Song> songs, {
    String? playlistId,
    bool forceLinear = false,
    bool saveSnapshot = true,
    bool clearCurrentSong = false,
  }) async {
    if (songs.isEmpty) return;

    // Clear any pending queue replacement since we're replacing immediately
    _pendingQueueSongs = null;
    _pendingQueuePlaylistId = null;
    pendingQueueNotifier.value = false;
    _sessionTopOrder.clear();
    _rememberedUpcomingIds = null;

    _currentPlaylistId = playlistId;

    final currentSong = currentSongNotifier.value;
    final isPlaying = _player.playing;
    // The still-playing song kept at the head is not part of the new queue's
    // history entry.
    final prepended =
        !clearCurrentSong && currentSong != null && isPlaying ? 1 : 0;

    if (forceLinear) {
      _resetFading();
      await _player.setShuffleModeEnabled(false);

      if (_shuffleState.config.enabled) {
        _shuffleState = _shuffleState.copyWith(
          config: _shuffleState.config.copyWith(enabled: false),
        );
        shuffleStateNotifier.value = _shuffleState;
        shuffleNotifier.value = false;
        await _saveShuffleState();
      }

      _originalQueue = songs.map((s) => QueueItem(song: s)).toList();

      if (!clearCurrentSong && currentSong != null && isPlaying) {
        final currentItem = QueueItem(song: currentSong);
        _effectiveQueue = [currentItem, ..._originalQueue];
        await _rebuildQueue(initialIndex: 0, startPlaying: true);
      } else {
        _effectiveQueue = List.from(_originalQueue);
        await _rebuildQueue(initialIndex: 0, startPlaying: true);
      }
    } else {
      _resetFading();
      await _player.setShuffleModeEnabled(false);
      _originalQueue = songs.map((s) => QueueItem(song: s)).toList();

      if (_shuffleState.config.enabled) {
        final firstItem = _originalQueue.first;
        final otherItems = List<QueueItem>.from(_originalQueue)..removeAt(0);
        final shuffledOthers = await _weightedShuffle(
          otherItems,
          lastItem: firstItem,
        );
        _effectiveQueue = [firstItem, ...shuffledOthers];
      } else {
        _effectiveQueue = List.from(_originalQueue);
      }

      if (!clearCurrentSong && currentSong != null && isPlaying) {
        final currentItem = QueueItem(song: currentSong);
        _effectiveQueue = [currentItem, ..._effectiveQueue];
      }
      await _rebuildQueue(initialIndex: 0, startPlaying: true);
    }

    if (saveSnapshot) {
      await _saveQueueSnapshot(
        [for (final item in _effectiveQueue.sublist(prepended)) item.song],
        playlistId: playlistId,
      );
    } else {
      _currentQueueSnapshotId = null;
    }

    _savePlaybackState();
    _updateQueueNotifier();
  }

  /// Starts a new history entry for a queue that begins now. [songs] must be
  /// in play order so the entry matches what is actually heard. An identical
  /// older entry is replaced rather than reused: reusing kept its old time and
  /// let later edits rewrite a snapshot that belonged to another session or
  /// another device.
  Future<void> _saveQueueSnapshot(List<Song> songs,
      {String? playlistId}) async {
    if (songs.isEmpty) return;

    final songFilenames = songs.map((s) => s.filename).toList();
    final source = playlistId ?? 'shuffle';
    final snapshot = QueueSnapshot.create(
      songFilenames: songFilenames,
      source: source,
      deviceId: SyncService.instance.deviceId,
    );
    _currentQueueSnapshotId = snapshot.id;
    try {
      await DatabaseService.instance.saveQueueSnapshot(
        snapshot.id,
        snapshot.name,
        snapshot.createdAt,
        snapshot.source,
        snapshot.songFilenames,
      );
      // Trim the queue history so it doesn't grow unbounded across long
      // sessions. Runs only on fresh insertions.
      unawaited(DatabaseService.instance.pruneQueueSnapshots());
      _notifyQueueHistoryChanged();
      _savePlaybackState();
    } catch (e) {
      debugPrint('Failed to save queue snapshot: $e');
    }
  }

  /// Keeps the current history entry in step with the live queue. Only
  /// snapshots this device created are edited; anything else (legacy ids,
  /// entries synced from another device, a restored entry) gets a fresh
  /// snapshot instead, so one device's queue edits never rewrite another
  /// device's history.
  Future<void> _updateCurrentSnapshotSongs() async {
    if (_effectiveQueue.isEmpty) return;
    final id = _currentQueueSnapshotId;
    final filenames = _effectiveQueue.map((q) => q.song.filename).toList();
    try {
      if (id != null &&
          QueueSnapshot.isOwnedBy(id, SyncService.instance.deviceId) &&
          await DatabaseService.instance
              .updateQueueSnapshotSongs(id, filenames)) {
        _notifyQueueHistoryChanged();
        return;
      }
      await _saveQueueSnapshot(
        _effectiveQueue.map((item) => item.song).toList(),
        playlistId: _currentPlaylistId,
      );
    } catch (e) {
      debugPrint('Failed to update queue snapshot: $e');
    }
  }

  void _notifyQueueHistoryChanged() {
    final ref = _ref;
    if (ref == null || !ref.mounted) return;
    ref.invalidate(queueHistoryProvider);
  }

  void setPendingQueueReplacement(List<Song> songs, {String? playlistId}) {
    _pendingQueueSongs = songs;
    _pendingQueuePlaylistId = playlistId;
    pendingQueueNotifier.value = true;
  }

  void cancelPendingQueueReplacement() {
    _pendingQueueSongs = null;
    _pendingQueuePlaylistId = null;
    pendingQueueNotifier.value = false;
  }

  /// Reorders only the tracks after the current one.
  ///
  /// The current track and everything already played stay exactly where they
  /// are, and the set of queued songs is never touched — this is purely a
  /// reordering, so flipping shuffle can never add or drop tracks. Because only
  /// sources after the current index are rewritten, the track that is playing
  /// is never re-created and audio does not stutter.
  Future<void> _reorderUpcoming(
    Future<List<QueueItem>> Function(List<QueueItem>, QueueItem) reorder, {
    bool createNewSnapshot = false,
  }) async {
    await _runSerializedQueueMutation(() async {
      if (_effectiveQueue.isEmpty) return;

      final currentIndex =
          (_player.currentIndex ?? 0).clamp(0, _effectiveQueue.length - 1);
      final currentItem = _effectiveQueue[currentIndex];
      final upcoming = _effectiveQueue.sublist(currentIndex + 1);

      if (upcoming.length > 1) {
        final reordered = await reorder(upcoming, currentItem);
        _effectiveQueue = [
          ..._effectiveQueue.sublist(0, currentIndex + 1),
          ...reordered,
        ];
        await _mutateQueueAfterIndex(currentIndex);
        _updateQueueNotifier();
        _warmThemePalettesAroundIndex(currentIndex);
      }

      if (createNewSnapshot) {
        await _saveQueueSnapshot(
          _effectiveQueue.map((item) => item.song).toList(),
          playlistId: _currentPlaylistId,
        );
      } else {
        await _updateCurrentSnapshotSongs();
      }
      _savePlaybackState();
    });
  }

  /// Shuffles everything after the current track, in place.
  Future<void> shuffleUpcoming({bool createNewSnapshot = false}) {
    return _reorderUpcoming(
      (upcoming, current) => _weightedShuffle(upcoming, lastItem: current),
      createNewSnapshot: createNewSnapshot,
    );
  }

  /// Restores original queue order for everything after the current track.
  Future<void> orderUpcoming({bool createNewSnapshot = false}) {
    return _reorderUpcoming(
      (upcoming, current) async => _inOriginalOrder(upcoming, current),
      createNewSnapshot: createNewSnapshot,
    );
  }

  /// Sorts [upcoming] back into original queue order, resuming from where
  /// [current] sits in that order and wrapping around to the start — so turning
  /// shuffle off continues the album or playlist from the right place rather
  /// than jumping back to track one.
  List<QueueItem> _inOriginalOrder(
    List<QueueItem> upcoming,
    QueueItem current,
  ) {
    final byQueueId = <String, int>{};
    final byFilename = <String, int>{};
    for (int i = 0; i < _originalQueue.length; i++) {
      byQueueId[_originalQueue[i].queueId] = i;
      byFilename.putIfAbsent(_originalQueue[i].song.filename, () => i);
    }

    // Duplicated entries carry a fresh queueId, so fall back to the filename.
    int? positionOf(QueueItem item) =>
        byQueueId[item.queueId] ?? byFilename[item.song.filename];

    final anchor = positionOf(current) ?? -1;
    final length = _originalQueue.length;

    // Entries the original queue never had — added via Play Next, or generated
    // on the fly — have no natural position, so they keep their relative order
    // at the end rather than being dropped.
    final known = <QueueItem>[];
    final unknown = <QueueItem>[];
    for (final item in upcoming) {
      (positionOf(item) == null ? unknown : known).add(item);
    }

    int rank(QueueItem item) {
      final position = positionOf(item)!;
      return position > anchor ? position : position + length;
    }

    known.sort((a, b) => rank(a).compareTo(rank(b)));
    return [...known, ...unknown];
  }

  /// Loads (and caches) the listening model shuffle scores against.
  ///
  /// The affinity map is keyed by filename — the primary key for all user data
  /// — and is rebuilt whenever the cache expires or user data changes, since
  /// favorites feed the affinity floor.
  Future<
      ({
        Map<String, SongAffinity> affinities,
        Map<String, int> historyIndex,
      })> _loadShuffleModel() async {
    final now = DateTime.now();
    final cacheValid = _shuffleCacheTimestamp != null &&
        now.difference(_shuffleCacheTimestamp!) < _shuffleCacheDuration;

    if (!cacheValid || _cachedAffinities == null) {
      final results = await Future.wait([
        DatabaseService.instance.getAffinityEvents(),
        DatabaseService.instance
            .getPlayHistory(limit: _shuffleState.config.historyLimit),
      ]);

      final events = results[0]
          as List<({String filename, double timestamp, double playRatio})>;
      _cachedPlayHistory = results[1] as List<
          ({
            String filename,
            double timestamp,
            double playRatio,
            String eventType
          })>;

      _cachedAffinities = computeAffinities(
        events: [
          for (final e in events)
            PlayEventRecord(
              filename: e.filename,
              timestamp: e.timestamp,
              playRatio: e.playRatio,
            ),
        ],
        now: now,
        favorites: _favoriteKeys,
      );
      _shuffleCacheTimestamp = now;
    }

    // Anti-repeat must survive across queue regenerations. DB playHistory
    // only reflects songs that have been *played* and flushed; a queue that was
    // just displayed but not yet played, or a song that is still playing and
    // not yet flushed, would otherwise appear as "never played" on the next
    // shuffle. We prepend the current queue's recent order so a new shuffle
    // immediately after the previous one still penalises songs the listener
    // just saw/heard, regardless of flush timing or the 30s affinity cache.
    final historyIndex = <String, int>{};
    final queueRecency = <String>[];
    if (_effectiveQueue.isNotEmpty) {
      final rawIdx = _player.currentIndex;
      final currentIdx =
          (rawIdx != null && rawIdx >= 0 && rawIdx < _effectiveQueue.length)
              ? rawIdx
              : (_effectiveQueue.isEmpty ? -1 : 0);
      if (currentIdx >= 0) {
        queueRecency.add(_effectiveQueue[currentIdx].song.filename);
        for (int i = currentIdx - 1; i >= 0; i--) {
          queueRecency.add(_effectiveQueue[i].song.filename);
        }
        for (int i = currentIdx + 1; i < _effectiveQueue.length; i++) {
          queueRecency.add(_effectiveQueue[i].song.filename);
        }
      } else {
        for (final item in _effectiveQueue) {
          queueRecency.add(item.song.filename);
        }
      }
    }

    var nextIdx = 0;
    for (final filename in queueRecency) {
      if (nextIdx >= _shuffleState.config.historyLimit) break;
      if (historyIndex.containsKey(filename)) continue;
      // Expand to merged siblings so every variant of the same logical track
      // shares the queue-based recency.
      final groupId = _filenameToGroupId[filename];
      final siblings = groupId != null ? _mergedGroups[groupId] : null;
      if (siblings != null) {
        for (final s in siblings) {
          historyIndex.putIfAbsent(s, () => nextIdx);
        }
      }
      historyIndex.putIfAbsent(filename, () => nextIdx);
      nextIdx++;
    }

    final playHistory = _cachedPlayHistory!;
    for (int i = 0; i < playHistory.length; i++) {
      final filename = playHistory[i].filename;
      if (historyIndex.containsKey(filename)) continue;
      final groupId = _filenameToGroupId[filename];
      final siblings = groupId != null ? _mergedGroups[groupId] : null;
      if (siblings != null) {
        for (final s in siblings) {
          historyIndex.putIfAbsent(s, () => nextIdx);
        }
      }
      historyIndex.putIfAbsent(filename, () => nextIdx);
      nextIdx++;
      if (nextIdx >= _shuffleState.config.historyLimit) break;
    }

    return (affinities: _cachedAffinities!, historyIndex: historyIndex);
  }

  /// Smart taste snapshot, or null when smart is off or the snapshot is not
  /// ready. Never throws: a shuffle must start even if the model fails.
  Future<TasteSnapshot?> tasteSnapshot() async {
    if (!_tasteDirty && _taste != null) return _taste;
    try {
      return await (_tasteBuilding ??= _buildTaste());
    } catch (e) {
      debugPrint('Smart taste snapshot failed: $e');
      return _taste;
    }
  }

  Future<TasteSnapshot?> _tasteForShuffle() async {
    if (_shuffleState.config.personality != ShufflePersonality.smart) {
      return null;
    }
    return tasteSnapshot().timeout(_tasteWait, onTimeout: () => _taste);
  }

  Future<TasteSnapshot> _buildTaste() async {
    _tasteDirty = false;
    try {
      final rows = await DatabaseService.instance.getTasteEvents();
      // Streamed tracks are not in the library list, and without their metadata
      // every one of them would key on its own filename: a listener who only
      // uses imported playlists would never build an artist profile.
      final streamed = await DatabaseService.instance.getRemoteSongs();
      final meta = <String, SongMeta>{
        for (final s in _allSongs)
          s.filename: SongMeta(artist: s.artist, album: s.album),
        for (final s in streamed)
          s.filename: SongMeta(artist: s.artist, album: s.album),
      };
      final known = {
        ..._allSongs.map((s) => s.filename),
        ...streamed.map((s) => s.filename),
      };
      final inputs = TasteInputs(
        events: [
          for (final r in rows)
            PlaySignal(
              filename: r.filename,
              timestamp: r.timestamp,
              ratio: r.ratio,
              secondsPlayed: r.secondsPlayed,
              sessionId: r.sessionId,
              source: PlaySource.parse(r.source),
            ),
        ],
        meta: meta,
        favorites: {
          for (final filename in known)
            if (_isFavorite(filename)) filename,
        },
        suggestLess: {
          for (final filename in known)
            if (_isSuggestLess(filename)) filename,
        },
        now: DateTime.now(),
      );
      final snapshot = await Isolate.run(() => buildTasteSnapshot(inputs));
      _taste = snapshot;
      return snapshot;
    } catch (_) {
      _tasteDirty = true;
      rethrow;
    } finally {
      _tasteBuilding = null;
    }
  }

  ShuffleWeights _weightsFor() =>
      ShuffleWeights.forPersonality(_shuffleState.config);

  /// Shuffles over most of the library are "library" picks. Anything smaller
  /// is scoped to an album, artist, playlist or search result.
  ShuffleContext _resolveShuffleContext(int poolSize, ShuffleContext? context) {
    if (context != null) return context;
    final library = _allSongs.length;
    return library > 0 && poolSize >= library * 0.8
        ? ShuffleContext.library
        : ShuffleContext.scoped;
  }

  /// Groups queue items so a merge group competes as one song, not several.
  List<_VirtualShuffleItem> _virtualItems(List<QueueItem> items) {
    final Map<String, List<QueueItem>> mergeGroups = {};
    final List<QueueItem> standaloneItems = [];

    for (final item in items) {
      final groupId = _getMergedGroupId(item.song.filename);
      if (groupId != null) {
        mergeGroups.putIfAbsent(groupId, () => []).add(item);
      } else {
        standaloneItems.add(item);
      }
    }

    return [
      for (final item in standaloneItems)
        _VirtualShuffleItem(
          type: _VirtualItemType.standalone,
          items: [item],
          representative: item,
        ),
      for (final entry in mergeGroups.entries)
        _VirtualShuffleItem(
          type: _VirtualItemType.mergeGroup,
          items: entry.value,
          representative: entry.value.first,
          groupId: entry.key,
        ),
    ];
  }

  List<ShuffleCandidate<_VirtualShuffleItem>> _legacyCandidates(
    List<_VirtualShuffleItem> virtual,
    Map<String, SongAffinity> affinities,
    Map<String, int> historyIndex,
  ) =>
      [for (final v in virtual) _toCandidate(v, affinities, historyIndex)];

  /// Smart pool: one candidate per virtual item. Taste is summed in the
  /// weights step, so only identity and flags are needed here.
  List<SmartCandidate<_VirtualShuffleItem>> _smartCandidates(
    List<_VirtualShuffleItem> virtual,
  ) =>
      [
        for (final v in virtual)
          SmartCandidate<_VirtualShuffleItem>(
            item: v,
            filenames: [for (final q in v.items) q.song.filename],
            artistKey: tasteArtistKey(
              v.representative.song.artist,
              v.representative.song.filename,
            ),
            albumKey: v.representative.song.album.trim().toLowerCase(),
            isFavorite: v.items.any((q) => _isFavorite(q.song.filename)),
            isSuggestLess: v.items.any((q) => _isSuggestLess(q.song.filename)),
            isInPlaylist: v.items.any((q) => _isInPlaylist(q.song.filename)),
          ),
      ];

  /// Collapses a candidate (possibly a merge group) into the signals scoring
  /// needs. Merge groups take the strongest signal across their members —
  /// liking one version of a song means liking the group.
  ShuffleCandidate<_VirtualShuffleItem> _toCandidate(
    _VirtualShuffleItem virtual,
    Map<String, SongAffinity> affinities,
    Map<String, int> historyIndex,
  ) {
    final representative = virtual.representative;

    if (virtual.type == _VirtualItemType.standalone) {
      final filename = representative.song.filename;
      return ShuffleCandidate(
        payload: virtual,
        artist: representative.song.artist,
        album: representative.song.album,
        affinity: affinities[filename] ?? SongAffinity.unknown,
        isFavorite: _isFavorite(filename),
        isSuggestLess: _isSuggestLess(filename),
        isInPlaylist: _isInPlaylist(filename),
        historyIndex: historyIndex[filename],
      );
    }

    var best = SongAffinity.unknown;
    var isFavorite = false;
    var isSuggestLess = false;
    var isInPlaylist = false;
    int? bestHistoryIndex;
    var totalPlayCount = 0;

    for (final queueItem in virtual.items) {
      final filename = queueItem.song.filename;
      final affinity = affinities[filename];

      if (affinity != null) {
        totalPlayCount += affinity.playCount;
        if (affinity.affinity > best.affinity) best = affinity;
      }

      if (_isFavorite(filename)) isFavorite = true;
      if (_isSuggestLess(filename)) isSuggestLess = true;
      if (_isInPlaylist(filename)) isInPlaylist = true;

      final idx = historyIndex[filename];
      if (idx != null && (bestHistoryIndex == null || idx < bestHistoryIndex)) {
        bestHistoryIndex = idx;
      }
    }

    return ShuffleCandidate(
      payload: virtual,
      artist: representative.song.artist,
      album: representative.song.album,
      // Play counts sum across the group so novelty sees the group as one
      // song that has been played as often as all its versions combined.
      affinity: SongAffinity(
        affinity: best.affinity,
        recentSaturation: best.recentSaturation,
        completionRate: best.completionRate,
        skipRate: best.skipRate,
        playCount: totalPlayCount,
        lastPlayedAt: best.lastPlayedAt,
      ),
      isFavorite: isFavorite,
      isSuggestLess: isSuggestLess,
      isInPlaylist: isInPlaylist,
      historyIndex: bestHistoryIndex,
    );
  }

  /// Chooses the song shuffle opens with.
  ///
  /// Falls back to a uniform pick only if scoring somehow yields nothing, so
  /// pressing shuffle can never fail to start playback.
  Future<QueueItem> _selectSeedItem(
    List<QueueItem> items, {
    ShuffleContext? context,
  }) async {
    final model = await _loadShuffleModel();
    final taste = await _tasteForShuffle();
    final virtual = _virtualItems(items);

    _VirtualShuffleItem? seed;
    if (taste != null) {
      final config = _shuffleState.config;
      seed = selectSmartSeed<_VirtualShuffleItem>(
        pool: _smartCandidates(virtual),
        taste: taste,
        familiarity: 1 - config.discoveryLevel,
        context: _resolveShuffleContext(items.length, context),
        historyIndex: model.historyIndex,
        historyLimit: config.antiRepeatEnabled ? config.historyLimit : 0,
        favoriteMultiplier: config.favoriteMultiplier,
        suggestLessMultiplier: config.suggestLessMultiplier,
      );
    } else {
      final candidates =
          _legacyCandidates(virtual, model.affinities, model.historyIndex);
      seed = selectSeed(candidates, _weightsFor())?.payload;
    }

    final selected = seed == null ? null : _selectSongFromVirtualItem(seed);
    return selected ?? items[Random().nextInt(items.length)];
  }

  Future<List<QueueItem>> _weightedShuffle(
    List<QueueItem> items, {
    QueueItem? lastItem,
    ShuffleContext? context,
  }) async {
    if (items.isEmpty) return [];

    final model = await _loadShuffleModel();
    final taste = await _tasteForShuffle();
    final virtual = _virtualItems(items);

    final List<_VirtualShuffleItem> ordered;
    if (taste != null) {
      final config = _shuffleState.config;
      ordered = orderSmartQueue<_VirtualShuffleItem>(
        pool: _smartCandidates(virtual),
        taste: taste,
        familiarity: 1 - config.discoveryLevel,
        context: _resolveShuffleContext(items.length, context),
        streakBreakerEnabled: config.streakBreakerEnabled,
        currentArtist: lastItem?.song.artist,
        currentFilename: lastItem?.song.filename ?? _currentSongFilename,
        historyIndex: model.historyIndex,
        historyLimit: config.antiRepeatEnabled ? config.historyLimit : 0,
        favoriteMultiplier: config.favoriteMultiplier,
        suggestLessMultiplier: config.suggestLessMultiplier,
        lastArtist: lastItem?.song.artist,
        lastAlbum: lastItem?.song.album,
      );
    } else {
      final candidates =
          _legacyCandidates(virtual, model.affinities, model.historyIndex);
      ordered = [
        for (final c in orderQueue(
          candidates,
          _weightsFor(),
          lastArtist: lastItem?.song.artist,
          lastAlbum: lastItem?.song.album,
        ))
          c.payload,
      ];
    }

    final result = <QueueItem>[];
    for (final virtualItem in ordered) {
      final selected = _selectSongFromVirtualItem(virtualItem);
      if (selected != null) result.add(selected);
    }
    return result;
  }

  String? _getMergedGroupId(String filename) {
    return _filenameToGroupId[filename];
  }

  QueueItem? _selectSongFromVirtualItem(_VirtualShuffleItem virtualItem) {
    if (virtualItem.items.length == 1) {
      return virtualItem.items.first;
    }

    if (virtualItem.groupId != null) {
      final priorityFilename = _mergedGroupPriorities[virtualItem.groupId];
      if (priorityFilename != null) {
        for (final item in virtualItem.items) {
          if (item.song.filename == priorityFilename) {
            return item;
          }
        }
      }
    }

    final weights = virtualItem.items.map((item) {
      double weight = 1.0;
      if (_isFavorite(item.song.filename)) {
        weight *= 2.0;
      }
      if (_isSuggestLess(item.song.filename)) {
        weight *= 0.2;
      }
      return weight;
    }).toList();

    final totalWeight = weights.fold(0.0, (a, b) => a + b);
    if (totalWeight <= 0) {
      return virtualItem.items.first;
    }

    double randomValue = Random().nextDouble() * totalWeight;
    double cumulative = 0.0;
    for (int i = 0; i < weights.length; i++) {
      cumulative += weights[i];
      if (randomValue <= cumulative) {
        return virtualItem.items[i];
      }
    }
    return virtualItem.items.last;
  }

  Future<void> _rebuildQueue({
    int? initialIndex,
    bool startPlaying = true,
    Duration? initialPosition,
  }) =>
      _guardPlayerMutation(() => _rebuildQueueInner(
            initialIndex: initialIndex,
            startPlaying: startPlaying,
            initialPosition: initialPosition,
          ));

  Future<void> _rebuildQueueInner({
    int? initialIndex,
    bool startPlaying = true,
    Duration? initialPosition,
  }) async {
    if (_effectiveQueue.isEmpty) return;
    // Best-effort: ensures POST_NOTIFICATIONS is granted on Android 13+
    // so the MediaStyle notification actually appears. No-op on older
    // Android and does not block playback if denied.
    unawaited(PermissionService.instance.ensureNotificationPermission());

    // Drop entries whose files vanished (renamed outside the app, unmounted
    // SD card, revoked permission). Feeding them to ExoPlayer stalls the
    // whole queue with no audible error.
    final missing = _effectiveQueue
        .where(
            (item) => item.song.isLocal && _isMissingLocalFile(item.song.url))
        .toList();
    if (missing.isNotEmpty) {
      _effectiveQueue.removeWhere((item) => missing.contains(item));
      _originalQueue.removeWhere(
          (item) => missing.any((m) => m.song.filename == item.song.filename));
      debugPrint(
          'AudioPlayerManager: ${missing.length} track${missing.length == 1 ? '' : 's'} unreadable — check storage permission (${missing.first.song.filename}${missing.length > 1 ? ', …' : ''})');
      if (_effectiveQueue.isEmpty) {
        _updateQueueNotifier();
        return;
      }
    }

    final sequenceState = _player.sequenceState;
    final currentMediaItem = sequenceState.currentSource?.tag as MediaItem?;
    final requestedIndex = initialIndex ?? _player.currentIndex ?? 0;
    final targetIndex = requestedIndex.clamp(0, _effectiveQueue.length - 1);
    final currentItem =
        (targetIndex >= 0 && targetIndex < _effectiveQueue.length)
            ? _effectiveQueue[targetIndex]
            : null;

    final currentQueueId = currentMediaItem?.extras?['queueId'] as String?;
    final trackChanged = currentItem != null
        ? currentQueueId != currentItem.queueId
        : currentMediaItem != null;
    if (trackChanged) {
      _resetFading();
    }

    _warmThemePalettesAroundIndex(targetIndex);

    final currentPosition = _player.position;

    Duration position = Duration.zero;
    if (initialPosition != null) {
      position = initialPosition;
    } else if (currentMediaItem != null && currentItem != null) {
      if (currentQueueId == currentItem.queueId) {
        position = currentPosition;
      }
    }

    // One directory listing up front so every entry below can resolve its
    // cover art synchronously instead of stat-ing the cache per song.
    await FileManagerService.primeNotificationCoverIndex();

    final buildWatch = Stopwatch()..start();
    final sources = await Future.wait([
      for (int i = 0; i < _effectiveQueue.length; i++)
        _createAudioSource(
          _effectiveQueue[i],
          awaitCover: i == targetIndex,
          resolveRemoteNow: i == targetIndex,
        ),
    ]);
    _logSlow('rebuild: built ${sources.length} sources', buildWatch);

    final setWatch = Stopwatch()..start();
    await _player.setAudioSources(
      sources,
      initialIndex: targetIndex,
      initialPosition: position,
    );
    _logSlow('rebuild: setAudioSources(${sources.length})', setWatch);
    _updateEffectivePlaybackMode(currentItem?.song);

    if (startPlaying) unawaited(_player.play());
    _updateQueueNotifier();
    _syncCoverWarmer(targetIndex);
  }

  /// Hands the warmer the current queue so it works on whatever plays next
  /// first. Cheap enough to call after any queue mutation.
  void _syncCoverWarmer([int? currentIndex]) {
    final mode = _ref?.read(settingsProvider).coverSizingMode;
    if (mode == null) return;
    NotificationCoverWarmer.instance.setQueue(
      _effectiveQueue.map((item) => item.song).toList(),
      currentIndex ?? _player.currentIndex ?? 0,
      mode,
    );
  }

  /// Reports a step that took long enough for a user to feel it. Deliberately
  /// not gated on [kDebugMode] — the startup stalls this exists to catch only
  /// reproduce on real devices running release builds.
  void _logSlow(String label, Stopwatch watch) {
    watch.stop();
    if (watch.elapsedMilliseconds < 250) return;
    debugPrint(
      'AudioPlayerManager: $label took ${watch.elapsedMilliseconds}ms',
    );
  }

  Future<void> _mutateQueueAfterIndex(int currentIndex) async {
    if (currentIndex < 0) return;

    // Snapshot the intended tail before touching the player. Mid-loop the
    // player's sequence briefly shrinks to a single item; if anything else read
    // _effectiveQueue off that transient state we would rebuild from garbage,
    // so the loops are driven from this immutable copy instead.
    final tail = _effectiveQueue.length > currentIndex + 1
        ? List<QueueItem>.from(_effectiveQueue.sublist(currentIndex + 1))
        : <QueueItem>[];

    await _guardPlayerMutation(() async {
      try {
        // Sequential on purpose: on iOS each source may start an ffmpeg proxy,
        // and fanning those out at once spikes CPU.
        final sources = <AudioSource>[];
        for (final item in tail) {
          sources.add(await _createAudioSource(item));
        }

        final playerLen = _player.sequenceState.sequence.length;
        if (playerLen > currentIndex + 1) {
          await _player.removeAudioSourceRange(currentIndex + 1, playerLen);
        }
        if (sources.isNotEmpty) {
          await _player.insertAudioSources(currentIndex + 1, sources);
        }
        _syncCoverWarmer(currentIndex);
      } catch (e) {
        // The player and the model must never diverge; on any failure fall back
        // to a full, atomic rebuild from the authoritative _effectiveQueue.
        debugPrint('Tail mutation failed, rebuilding queue: $e');
        await _rebuildQueueInner(
          initialIndex: currentIndex,
          startPlaying: _player.playing,
        );
      }
    });
  }

  Future<void> playNext(Song song, {bool allowDuplicate = false}) async {
    await _runSerializedQueueMutation(() async {
      var currentIndex = _player.currentIndex ?? -1;
      final preventMerged =
          _ref?.read(settingsProvider).preventMergedDuplicates ?? true;
      final checkMergedSiblings = !allowDuplicate && preventMerged;

      final mergedSiblings = checkMergedSiblings
          ? _getMergedSiblings(song.filename)
          : const <String>[];

      final candidate = QueueItem(song: song);
      _tagSource(candidate.queueId, PlaySource.queued);

      // Merged-group fix: if a sibling of the requested song already sits in
      // the upcoming section, remove that sibling and insert the *requested*
      // file instead of moving the sibling (which was the previous bug).
      if (mergedSiblings.isNotEmpty) {
        final directExists =
            _effectiveQueue.any((item) => item.song.filename == song.filename);
        if (!directExists) {
          var siblingIdx = -1;
          for (final sibling in mergedSiblings) {
            siblingIdx = _effectiveQueue
                .indexWhere((item) => item.song.filename == sibling);
            if (siblingIdx != -1) break;
          }
          if (siblingIdx > currentIndex) {
            final siblingQueueId = _effectiveQueue[siblingIdx].queueId;
            _effectiveQueue.removeAt(siblingIdx);
            try {
              await _player.removeAudioSourceAt(siblingIdx);
            } catch (e) {
              debugPrint('playNext: failed to remove merged sibling: $e');
            }
            _sessionTopOrder =
                _sessionTopOrder.where((id) => id != siblingQueueId).toList();
            // currentIndex unchanged because removal was after it, but clamp
            // defensively if the player index was affected.
            currentIndex = (_player.currentIndex ?? currentIndex)
                .clamp(-1, _effectiveQueue.length - 1);
          }
        }
      }

      final plan = queue_ops.planPlayNext(
        _effectiveQueue,
        currentIndex,
        candidate,
        sessionTopOrder: _sessionTopOrder,
        mergedSiblings: const [],
        allowDuplicate: allowDuplicate,
      );

      if (plan.isMove) {
        final from = plan.from!;
        final item = _effectiveQueue.removeAt(from);
        _effectiveQueue.insert(plan.to, item);
        try {
          await _player.moveAudioSource(from, plan.to);
        } catch (e) {
          _effectiveQueue.removeAt(plan.to);
          _effectiveQueue.insert(from, item);
          rethrow;
        }
      } else {
        _effectiveQueue.insert(plan.to, plan.item);
        try {
          final source = await _createAudioSource(plan.item);
          await _player.insertAudioSource(plan.to, source);
        } catch (e) {
          _effectiveQueue.removeAt(plan.to);
          rethrow;
        }
      }

      _sessionTopOrder = queue_ops.updateSessionTopOrder(
        _sessionTopOrder,
        plan.item.queueId,
        isOverride: false,
      );
      _sessionTopOrder = queue_ops.pruneSessionTopOrder(
        _effectiveQueue,
        _player.currentIndex ?? -1,
        _sessionTopOrder,
      );

      _updateQueueNotifier();
      _savePlaybackState();
      await _updateCurrentSnapshotSongs();
    });
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    await _runSerializedQueueMutation(() async {
      if (_effectiveQueue.isEmpty) return;
      if (oldIndex < 0 || oldIndex >= _effectiveQueue.length) return;

      int targetIndex = newIndex.clamp(0, _effectiveQueue.length);
      if (oldIndex < targetIndex) targetIndex -= 1;
      if (targetIndex < 0 || targetIndex >= _effectiveQueue.length) return;
      if (oldIndex == targetIndex) return;

      final item = _effectiveQueue.removeAt(oldIndex);
      _effectiveQueue.insert(targetIndex, item);
      try {
        await _player.moveAudioSource(oldIndex, targetIndex);
      } catch (e) {
        _effectiveQueue.removeAt(targetIndex);
        _effectiveQueue.insert(oldIndex, item);
        rethrow;
      }
      _updateQueueNotifier();
      _savePlaybackState();
      await _updateCurrentSnapshotSongs();
    });
  }

  /// Moves a queued entry to the top of the upcoming section — immediately
  /// after the current track (if already in top order, overriding position), or
  /// after the furthest-along top entry in [_sessionTopOrder] that is still
  /// upcoming.
  Future<void> moveUpcomingToTop(String queueId) async {
    await _runSerializedQueueMutation(() async {
      final currentIndex = _player.currentIndex ?? -1;
      if (currentIndex < 0 || currentIndex >= _effectiveQueue.length) return;

      final isOverride = _sessionTopOrder.contains(queueId);
      final plan = queue_ops.planMoveUpcomingToTop(
        _effectiveQueue,
        currentIndex,
        queueId,
        sessionTopOrder: _sessionTopOrder,
      );
      if (plan == null) return;

      final from = plan.from!;
      final item = _effectiveQueue.removeAt(from);
      _effectiveQueue.insert(plan.to, item);
      try {
        await _player.moveAudioSource(from, plan.to);
      } catch (e) {
        _effectiveQueue.removeAt(plan.to);
        _effectiveQueue.insert(from, item);
        rethrow;
      }

      _sessionTopOrder = queue_ops.updateSessionTopOrder(
        _sessionTopOrder,
        queueId,
        isOverride: isOverride,
      );
      _sessionTopOrder = queue_ops.pruneSessionTopOrder(
        _effectiveQueue,
        _player.currentIndex ?? -1,
        _sessionTopOrder,
      );

      _updateQueueNotifier();
      _savePlaybackState();
      await _updateCurrentSnapshotSongs();
    });
  }

  Future<void> addToQueue(Song song) async {
    if (_effectiveQueue.isEmpty) return playSong(song);

    await _runSerializedQueueMutation(() async {
      final item = QueueItem(song: song);
      final originalItem = QueueItem(song: song);
      _tagSource(item.queueId, PlaySource.queued);
      _effectiveQueue.add(item);
      _originalQueue.add(originalItem);

      try {
        await _player.addAudioSource(await _createAudioSource(item));
      } catch (_) {
        _effectiveQueue.remove(item);
        _originalQueue.remove(originalItem);
        _itemSource.remove(item.queueId);
        rethrow;
      }

      _updateQueueNotifier();
      _savePlaybackState();
      await _updateCurrentSnapshotSongs();
      _syncCoverWarmer(_player.currentIndex);
    });
  }

  Future<void> removeFromQueue(int index) async {
    return _runSerializedQueueMutation(() async {
      if (_effectiveQueue.isEmpty) return;
      if (index < 0 || index >= _effectiveQueue.length) return;

      final removedItem = _effectiveQueue.removeAt(index);
      _sessionTopOrder.remove(removedItem.queueId);
      try {
        await _player.removeAudioSourceAt(index);
      } catch (e) {
        _effectiveQueue.insert(index, removedItem);
        rethrow;
      }
      _updateQueueNotifier();
      _savePlaybackState();
      await _updateCurrentSnapshotSongs();
    });
  }

  Future<void> insertIntoQueue(int index, QueueItem item) async {
    await _runSerializedQueueMutation(() async {
      final targetIndex = index.clamp(0, _effectiveQueue.length);
      _effectiveQueue.insert(targetIndex, item);
      try {
        final source = await _createAudioSource(item);
        await _player.insertAudioSource(targetIndex, source);
      } catch (e) {
        _effectiveQueue.removeAt(targetIndex);
        rethrow;
      }
      _updateQueueNotifier();
      _savePlaybackState();
      await _updateCurrentSnapshotSongs();
    });
  }

  Future<void> clearUpcoming() async {
    await _runSerializedQueueMutation(() async {
      final currentIndex = _player.currentIndex ?? -1;
      if (currentIndex < 0) return;
      if (currentIndex >= _effectiveQueue.length - 1) return;

      for (int i = _effectiveQueue.length - 1; i > currentIndex; i--) {
        if (i < 0 || i >= _effectiveQueue.length) continue;
        final removed = _effectiveQueue.removeAt(i);
        try {
          await _player.removeAudioSourceAt(i);
        } catch (e) {
          _effectiveQueue.insert(i, removed);
          rethrow;
        }
      }

      _sessionTopOrder.clear();
      _updateQueueNotifier();
      _savePlaybackState();
      await _updateCurrentSnapshotSongs();
    });
  }

  /// Plays a specific queued entry right now.
  ///
  /// An entry that is still upcoming is *moved* to just after the current
  /// track, so it exists once. An entry that has already played is *copied*
  /// there instead, leaving the played history intact. Either way nothing at or
  /// before the current track is disturbed, and playback then skips onto it.
  Future<void> jumpToQueueItem(String queueId) async {
    await _runSerializedQueueMutation(() async {
      final currentIndex = _player.currentIndex ?? -1;
      if (currentIndex < 0 || currentIndex >= _effectiveQueue.length) return;

      final sourceIndex =
          _effectiveQueue.indexWhere((item) => item.queueId == queueId);
      if (sourceIndex < 0 || sourceIndex == currentIndex) return;
      _tagSource(queueId, PlaySource.manual);

      final targetIndex = currentIndex + 1;

      if (sourceIndex > currentIndex) {
        if (sourceIndex != targetIndex) {
          final item = _effectiveQueue.removeAt(sourceIndex);
          _effectiveQueue.insert(targetIndex, item);
          try {
            await _player.moveAudioSource(sourceIndex, targetIndex);
          } catch (e) {
            _effectiveQueue.removeAt(targetIndex);
            _effectiveQueue.insert(sourceIndex, item);
            rethrow;
          }
        }
      } else {
        // A fresh QueueItem, so the original entry keeps its own identity in
        // the played section rather than being yanked out of history.
        final copy = QueueItem(song: _effectiveQueue[sourceIndex].song);
        _effectiveQueue.insert(targetIndex, copy);
        try {
          final source = await _createAudioSource(
            copy,
            resolveRemoteNow: true,
          );
          await _player.insertAudioSource(targetIndex, source);
        } catch (e) {
          _effectiveQueue.removeAt(targetIndex);
          rethrow;
        }
      }

      _updateQueueNotifier();
      _savePlaybackState();
      await _updateCurrentSnapshotSongs();

      await _player.seek(Duration.zero, index: targetIndex);
      unawaited(_player.play());
    });
  }

  Future<void> forceFlushCurrentStats() async {
    _flushStats(isTerminal: true);
    await _statsService.flush();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_settledSequenceController.close());
    unawaited(forceFlushCurrentStats());
    _volumeMonitorService?.dispose();
    _positionSubscription?.cancel();
    _sequenceSubscription?.cancel();
    for (final sub in _trackedSubscriptions) {
      sub.cancel();
    }
    _trackedSubscriptions.clear();
    _fadeTimer?.cancel();
    _gapTimer?.cancel();
    _releasePark();
    queuePlayedRevision.dispose();
    _clearGapState();
    // Flush before the player goes away: the state is read from it, and a
    // coalesced write may still be pending.
    unawaited(savePlaybackState());
    SyncService.instance.beforeRun = null;
    _player.dispose();
    shuffleNotifier.dispose();
    fastForwardNotifier.dispose();
    preferredMediaModeNotifier.dispose();
    effectiveMediaModeNotifier.dispose();
  }
}

enum _VirtualItemType { standalone, mergeGroup }

class _VirtualShuffleItem {
  final _VirtualItemType type;
  final List<QueueItem> items;
  final QueueItem representative;
  final String? groupId;

  _VirtualShuffleItem({
    required this.type,
    required this.items,
    required this.representative,
    this.groupId,
  });
}
