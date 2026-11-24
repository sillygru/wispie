import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import '../../data/rust/native_database.dart';

import '../../data/repositories/song_identity_repository.dart';
import '../../domain/services/song_identity.dart';
import '../../models/song.dart';
import 'hlc.dart';
import 'song_refs.dart';

/// User-facing sync categories (one toggle each).
class SyncCategory {
  static const playStats = 'play_stats';
  static const favorites = 'favorites';
  static const suggestless = 'suggestless';
  static const hidden = 'hidden';
  static const playlists = 'playlists';
  static const mergedSongs = 'merged_songs';
  static const settings = 'settings';
  static const artistArt = 'artist_art';
  static const albumArt = 'album_art';
  static const queueHistory = 'queue_history';
  static const currentQueue = 'current_queue';

  static const List<String> all = [
    playStats,
    favorites,
    suggestless,
    hidden,
    playlists,
    mergedSongs,
    settings,
    artistArt,
    albumArt,
    queueHistory,
    currentQueue,
  ];
}

/// Settings keys that travel in the encrypted payload.
const List<String> kSyncableSettingsKeys = [
  'theme_mode',
  'use_cover_color',
  'apply_cover_color_to_all',
  'sort_order',
  'visualizer_enabled',
  'visualizer_mode',
  'show_song_duration',
  'animated_sound_wave_enabled',
  'show_waveform',
  'fade_out_duration',
  'fade_in_duration',
  'delay_duration',
  'play_fade_duration',
  'pause_fade_duration',
  'keep_screen_awake_on_lyrics',
  'desktop_sidebar_enabled',
  'cover_sizing_mode',
  'beat_reactive_cover_enabled',
  'beat_reactive_particles_enabled',
  'cover_motion_intensity',
  'particle_motion_intensity',
  'cover_motion_custom_intensity',
  'particle_motion_custom_intensity',
  'player_motion_latency_ms',
  'spin_artwork_while_playing',
  'show_quick_picks',
  'show_recent_queues',
  'show_for_you',
  'lyrics_target_language',
  'lyrics_auto_translate',
  'lyrics_translation_mode',
  'auto_hide_bottom_bar_on_scroll',
  'auto_pause_on_volume_zero',
  'auto_resume_on_volume_restore',
];

/// Value store for synced settings (values live outside the sync DBs).
abstract class SettingsAccess {
  Future<Object?> read(String key);
  Future<void> write(String key, Object value);
}

class PrefsSettingsAccess implements SettingsAccess {
  @override
  Future<Object?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.get(key);
  }

  @override
  Future<void> write(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is List) {
      await prefs.setStringList(key, value.map((e) => '$e').toList());
    }
  }
}

class _Spec {
  final String entity;
  final String category;
  final bool stats;
  final List<String> keyCols;
  const _Spec(this.entity, this.category, this.stats, this.keyCols);
}

const List<_Spec> _lwwSpecs = [
  _Spec('favorites', SyncCategory.favorites, false, ['filename']),
  _Spec('suggestless', SyncCategory.suggestless, false, ['filename']),
  _Spec('hidden', SyncCategory.hidden, false, ['filename']),
  _Spec('playlists', SyncCategory.playlists, false, ['id']),
  _Spec('playlist_songs', SyncCategory.playlists, false,
      ['playlist_id', 'song_filename']),
  _Spec('merged_groups', SyncCategory.mergedSongs, false, ['id']),
  _Spec('merged_songs', SyncCategory.mergedSongs, false, ['filename']),
  _Spec('artist_art', SyncCategory.artistArt, false, ['artist_name']),
  _Spec('album_art', SyncCategory.albumArt, false, ['album_key']),
  _Spec('queue_snapshots', SyncCategory.queueHistory, false, ['id']),
];

/// Merged by hand: remote copies are stashed and only applied on a manual sync
/// that prefers the cloud queue, so auto-sync never replaces what is playing.
const _Spec _currentQueueSpec =
    _Spec('current_queue', SyncCategory.currentQueue, false, ['id']);
const String kStashedQueueKey = 'sync_stashed_remote_queue';

const _Spec _sessionSpec =
    _Spec('play_sessions', SyncCategory.playStats, true, ['id']);
const _Spec _eventSpec =
    _Spec('play_events', SyncCategory.playStats, true, ['uid']);

final List<_Spec> _allSpecs = [
  _sessionSpec,
  _eventSpec,
  ..._lwwSpecs,
  _currentQueueSpec,
];
final Map<String, _Spec> _specByEntity = {
  for (final s in _allSpecs) s.entity: s
};

const Duration kTombstoneRetention = Duration(days: 180);
const int kDeltaPlaintextBudget = 3500 * 1024;
const int kMergeBatchSize = 500;

class _Clear {
  final bool stats;
  final String entity;
  final List<Object?> args;
  final int hlc;
  const _Clear(this.stats, this.entity, this.args, this.hlc);
}

/// One payload plus the bookkeeping needed to clear dirty flags after upload.
class ChangesetBatch {
  final Map<String, dynamic> payload;
  final List<_Clear> _clears;
  final int recordCount;
  ChangesetBatch._(this.payload, this._clears, this.recordCount);

  bool get isEmpty => recordCount == 0;
}

typedef MergeProgress = void Function(int done, int total);

class MergeResult {
  final int total;
  final int skippedCategories;
  const MergeResult(this.total, this.skippedCategories);
}

class _Item {
  final String array;
  final Map<String, Object?> record;
  final _Clear? clear;
  _Item(this.array, this.record, this.clear);
}

/// Local-only changeset engine: builds deltas/snapshots from dirty rows and
/// merges remote payloads under the rules in plan_sync.md sec 1.5. No network.
class Changeset {
  final Database stats;
  final Database userData;
  final String deviceId;
  final String deviceName;
  final SettingsAccess settings;
  final int Function() nowMs;

  Changeset({
    required this.stats,
    required this.userData,
    required this.deviceId,
    this.deviceName = '',
    SettingsAccess? settings,
    int Function()? nowMs,
  })  : settings = settings ?? PrefsSettingsAccess(),
        nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  IdentityIndex? _identityCache;
  int _identityGeneration = -1;

  Future<IdentityIndex> _identityIndex() async {
    final cached = _identityCache;
    if (cached != null &&
        _identityGeneration == SongIdentityRepository.generation) {
      return cached;
    }
    final gen = SongIdentityRepository.generation;
    final built = IdentityIndex(await SongIdentityRepository.loadAll(userData));
    _identityCache = built;
    _identityGeneration = gen;
    return built;
  }

  Database _db(_Spec s) => s.stats ? stats : userData;

  static bool _on(Set<String>? cats, String c) =>
      cats == null || cats.contains(c);

  static String entityCategory(String entity) =>
      _specByEntity[entity]?.category ?? '';

  // ------------------------------------------------------------------ build

  /// Dirty rows/tombstones/settings for [categories], split into payloads of
  /// at most [maxBytes] of JSON each. Empty list when nothing is dirty.
  Future<List<ChangesetBatch>> buildDeltas({
    Set<String>? categories,
    int maxBytes = kDeltaPlaintextBudget,
  }) async {
    await _stampLegacy(categories);
    final batches = <ChangesetBatch>[];
    var records = <String, List<Map<String, Object?>>>{};
    var clears = <_Clear>[];
    var count = 0;
    var size = 0;

    void flush() {
      if (count == 0) return;
      batches.add(_wrap('delta', records, clears, count, categories));
      records = {};
      clears = [];
      count = 0;
      size = 0;
    }

    await for (final item in _collect(categories, dirtyOnly: true)) {
      final len = jsonEncode(item.record).length + 1;
      if (count > 0 && size + len > maxBytes) flush();
      records.putIfAbsent(item.array, () => []).add(item.record);
      if (item.clear != null) clears.add(item.clear!);
      size += len;
      count++;
    }
    flush();
    final payloads = [for (final batch in batches) batch.payload];
    await _attachIdentity(payloads);
    await _attachRemoteSongs(payloads);
    return batches;
  }

  /// Full current state of [categories]; tombstones older than 180 days are
  /// dropped.
  Future<ChangesetBatch> buildSnapshot({Set<String>? categories}) async {
    await _stampLegacy(categories);
    final records = <String, List<Map<String, Object?>>>{};
    final clears = <_Clear>[];
    var count = 0;
    await for (final item in _collect(categories, dirtyOnly: false)) {
      records.putIfAbsent(item.array, () => []).add(item.record);
      if (item.clear != null) clears.add(item.clear!);
      count++;
    }
    final batch = _wrap('snapshot', records, clears, count, categories);
    await _attachIdentity([batch.payload]);
    await _attachRemoteSongs([batch.payload]);
    return batch;
  }

  /// Ships the audio content id of every song a payload names, so a device
  /// that knows the file under another name can still match it.
  Future<void> _attachIdentity(Iterable<Map<String, dynamic>> payloads) async {
    final index = await _identityIndex();
    if (index.byFilename.isEmpty) return;
    for (final payload in payloads) {
      final names = collectSongNames(payload['records'] as Map);
      final ids = {
        for (final n in names)
          if (index.byFilename[n] != null) n: index.byFilename[n]!.cid
      };
      if (ids.isNotEmpty) payload['identity'] = ids;
    }
  }

  /// Ships the catalogue metadata of every streamed track a payload names.
  ///
  /// A streamed track's row lives in `remote_song`, not in the library, so a
  /// device that never imported that playlist would receive a filename with
  /// nothing behind it: no title, no cover, nothing to play. The rows are public
  /// catalogue data, so they ride along with the records that name them.
  Future<void> _attachRemoteSongs(
      Iterable<Map<String, dynamic>> payloads) async {
    for (final payload in payloads) {
      final names = collectSongNames(payload['records'] as Map)
          .where((name) => name.startsWith(Song.youtubePrefix))
          .toList();
      if (names.isEmpty) continue;

      final tracks = <String, Map<String, Object?>>{};
      for (final row
          in await _rows(userData, 'remote_rows', {'filenames': names})) {
        tracks[row['filename'] as String] = {
          for (final key in [
            'remote_id',
            'title',
            'artist',
            'album',
            'cover_url',
            'duration_ms',
            'is_available',
          ])
            key: row[key],
        };
      }
      if (tracks.isNotEmpty) payload['remote_tracks'] = tracks;
    }
  }

  /// Recreates the catalogue rows a payload names, so a playlist merged from
  /// another device lists real tracks instead of bare filenames.
  ///
  /// Existing rows are kept: this is public metadata that the device may
  /// already have fresher, and nothing here is user-owned.
  Future<void> _importRemoteTracks(Map<String, dynamic> payload) async {
    final tracks = payload['remote_tracks'];
    if (tracks is! Map || tracks.isEmpty) return;

    final rows = <Map<String, Object?>>[];
    for (final entry in tracks.entries) {
      final row = entry.value;
      if (row is! Map) continue;
      final filename = '${entry.key}';
      final id = '${row['remote_id'] ?? ''}';
      if (!filename.startsWith(Song.youtubePrefix) || id.isEmpty) continue;
      final title = '${row['title'] ?? ''}'.trim();
      rows.add({
        'filename': filename,
        'remote_id': id,
        'title': title.isEmpty ? id : title,
        'artist': '${row['artist'] ?? ''}',
        'album': '${row['album'] ?? ''}',
        'cover_url': row['cover_url'],
        'duration_ms': row['duration_ms'],
        'is_available': row['is_available'] ?? 1,
        'updated_at': nowMs() / 1000.0,
      });
    }
    if (rows.isEmpty) return;

    await _store(userData, 'remote_write', {'rows': rows});
  }

  /// Rewrites every song name in [payload] to the local file holding the same
  /// audio. Names whose audio is absent are remembered as orphans so the data
  /// they carry attaches itself if the file turns up later.
  Future<Map<String, dynamic>> _remapIncoming(
      Map<String, dynamic> payload) async {
    final records = payload['records'];
    if (records is! Map) return payload;
    final remote = <String, String>{
      for (final e in ((payload['identity'] as Map?) ?? const {}).entries)
        if (e.value is String) '${e.key}': e.value as String
    };
    final index = await _identityIndex();
    if (remote.isEmpty && index.byFilename.isEmpty) return payload;

    final learned = <String, String>{};
    final mapping = <String, String?>{};
    for (final name in collectSongNames(records)) {
      final cid = remote[name];
      final target = index.resolve(name, remoteCid: cid);
      if (target == name &&
          cid != null &&
          index.byFilename[name] == null &&
          index.liveFilesFor(cid).isEmpty) {
        learned[name] = cid;
      }
      mapping[name] = target;
    }
    // Every name landing on itself is a no-op rewrite; skip the payload round
    // trip a fresh device would pay on every incoming delta.
    final unchanged =
        mapping.entries.every((entry) => entry.key == entry.value);
    final remapped = unchanged ? records : remapSongNames(records, mapping);
    if (learned.isNotEmpty) {
      await SongIdentityRepository.learnOrphans(userData, learned);
      learned.forEach(index.addOrphan);
      _identityGeneration = SongIdentityRepository.generation;
    }
    return {...payload, 'records': remapped};
  }

  ChangesetBatch _wrap(
    String kind,
    Map<String, List<Map<String, Object?>>> records,
    List<_Clear> clears,
    int count,
    Set<String>? categories,
  ) {
    var maxHlc = 0;
    for (final list in records.values) {
      for (final r in list) {
        final h = (r['hlc'] as num?)?.toInt() ?? 0;
        if (h > maxHlc) maxHlc = h;
      }
    }
    return ChangesetBatch._(
      {
        'v': 1,
        'kind': kind,
        'device_id': deviceId,
        'device_name': deviceName,
        'max_hlc': maxHlc,
        'categories': (categories ?? SyncCategory.all.toSet()).toList()..sort(),
        'records': records,
      },
      clears,
      count,
    );
  }

  Future<Map<String, Object?>> _store(
    Database db,
    String op, [
    Map<String, Object?> fields = const {},
  ]) =>
      db.coreCommand('sync_store', {'op': op, ...fields});

  Future<List<Map<String, Object?>>> _rows(
    Database db,
    String op,
    Map<String, Object?> fields,
  ) async =>
      ((await _store(db, op, fields))['rows'] as List)
          .cast<Map<String, Object?>>();

  List<String> _entities(bool isStats, Set<String>? categories) => [
        for (final s in _allSpecs)
          if (s.stats == isStats && _on(categories, s.category)) s.entity,
      ];

  Future<void> _stampLegacy(Set<String>? cats) async {
    for (final isStats in [true, false]) {
      await _store(isStats ? stats : userData, 'stamp', {
        'entities': [..._entities(isStats, cats), 'tombstones'],
        'hlc': Hlc.instance.now(),
      });
    }
  }

  Stream<_Item> _collect(Set<String>? cats, {required bool dirtyOnly}) async* {
    const page = 2000;
    for (final s in _allSpecs) {
      if (!_on(cats, s.category)) continue;
      var offset = 0;
      while (true) {
        final rows = await _rows(_db(s), 'collect', {
          'entity': s.entity,
          'dirty_only': dirtyOnly,
          'offset': offset,
        });
        for (final row in rows) {
          if (s == _eventSpec && row['uid'] == null) continue;
          yield _Item(
            s.entity,
            row,
            _Clear(
              s.stats,
              s.entity,
              s.keyCols.map((c) => row[c]).toList(),
              (row['hlc'] as num).toInt(),
            ),
          );
        }
        if (rows.length < page) break;
        offset += page;
      }
    }

    final cutoff = (nowMs() - kTombstoneRetention.inMilliseconds) << 16;
    for (final isStats in [true, false]) {
      final rows = await _rows(isStats ? stats : userData, 'collect', {
        'entity': 'tombstones',
        'dirty_only': dirtyOnly,
      });
      for (final row in rows) {
        final entity = row['entity'] as String;
        final spec = _specByEntity[entity];
        if (spec == null || !_on(cats, spec.category)) continue;
        final hlc = (row['hlc'] as num).toInt();
        if (!dirtyOnly && hlc < cutoff) continue;
        yield _Item(
          'tombstones',
          {'entity': entity, 'key': row['key'], 'hlc': hlc},
          _Clear(isStats, 'tombstones', [entity, row['key']], hlc),
        );
      }
    }

    if (_on(cats, SyncCategory.settings)) {
      final metas = await _rows(userData, 'collect', {
        'entity': 'settings',
        'dirty_only': dirtyOnly,
      });
      final metaByKey = {for (final m in metas) m['key'] as String: m};
      final keys = dirtyOnly
          ? metaByKey.keys.where(kSyncableSettingsKeys.contains)
          : kSyncableSettingsKeys;
      for (final key in keys) {
        final value = await settings.read(key);
        if (value == null) continue;
        final meta = metaByKey[key];
        final hlc = (meta?['hlc'] as num?)?.toInt() ?? 0;
        yield _Item(
          'settings',
          {'key': key, 'value': value, 'hlc': hlc},
          meta == null ? null : _Clear(false, 'settings', [key], hlc),
        );
      }
    }
  }

  /// Clears dirty only where the hlc is unchanged since the batch was built, so
  /// a write that raced the upload stays dirty.
  Future<void> markPushed(ChangesetBatch batch) async {
    for (final isStats in [true, false]) {
      final mine = batch._clears.where((c) => c.stats == isStats).toList();
      if (mine.isEmpty) continue;
      await _store(isStats ? stats : userData, 'ack', {
        'rows': [
          for (final row in mine)
            {'entity': row.entity, 'keys': row.args, 'hlc': row.hlc},
        ],
      });
    }
  }

  Future<void> markAllDirty({Set<String>? categories}) async {
    for (final isStats in [true, false]) {
      await _store(isStats ? stats : userData, 'mark', {
        'entities': _entities(isStats, categories),
        'hlc': Hlc.instance.now(),
      });
    }
    if (_on(categories, SyncCategory.settings)) {
      for (final key in kSyncableSettingsKeys) {
        if (await settings.read(key) == null) continue;
        await _store(
            userData, 'setting_dirty', {'key': key, 'hlc': Hlc.instance.now()});
      }
    }
  }

  Future<void> gcTombstones() async {
    final cutoff = (nowMs() - kTombstoneRetention.inMilliseconds) << 16;
    for (final db in [stats, userData]) {
      await _store(db, 'gc', {'hlc': cutoff});
    }
  }

  // ------------------------------------------------------------------ merge

  static int _countRecords(Map<String, dynamic> payload, Set<String>? cats) {
    final records = (payload['records'] as Map?) ?? const {};
    var n = 0;
    records.forEach((array, list) {
      if (list is! List) return;
      if (array == 'tombstones') {
        for (final t in list) {
          if (t is Map && _on(cats, entityCategory('${t['entity']}'))) n++;
        }
      } else if (array == 'settings') {
        if (_on(cats, SyncCategory.settings)) n += list.length;
      } else {
        final s = _specByEntity[array];
        if (s != null && _on(cats, s.category)) n += list.length;
      }
    });
    return n;
  }

  static void _observeClocks(Map<String, dynamic> payload) {
    var maxHlc = (payload['max_hlc'] as num?)?.toInt() ?? 0;
    final records = (payload['records'] as Map?) ?? const {};
    for (final list in records.values) {
      if (list is! List) continue;
      for (final r in list) {
        if (r is Map && r['hlc'] is num) {
          maxHlc = max(maxHlc, (r['hlc'] as num).toInt());
        }
      }
    }
    if (maxHlc > 0) Hlc.instance.observe(maxHlc);
  }

  /// Merges [payload] into the local DBs in batches of [kMergeBatchSize] rows
  /// per transaction. Records of categories not in [categories] are skipped.
  /// Merged rows are stored clean (no echo).
  Future<MergeResult> merge(
    Map<String, dynamic> payload, {
    Set<String>? categories,
    MergeProgress? onProgress,
  }) async {
    payload = await _remapIncoming(payload);
    await _importRemoteTracks(payload);
    final records =
        ((payload['records'] as Map?) ?? const {}).cast<String, dynamic>();
    final remoteDevice = '${payload['device_id'] ?? ''}';
    final total = _countRecords(payload, categories);
    _observeClocks(payload);
    var done = 0;

    Future<void> run(Database db, String entity, List<Map> items) async {
      for (var i = 0; i < items.length; i += kMergeBatchSize) {
        final chunk = items.skip(i).take(kMergeBatchSize).toList();
        await _store(db, 'merge', {
          'entity': entity,
          'rows': chunk,
          'remote_device': remoteDevice,
          'device': deviceId,
        });
        done += chunk.length;
        onProgress?.call(done, total);
      }
    }

    List<Map> listOf(String array) =>
        ((records[array] as List?) ?? const []).whereType<Map>().toList();

    if (_on(categories, SyncCategory.playStats)) {
      await run(stats, 'play_sessions', listOf('play_sessions'));
      await run(stats, 'play_events', listOf('play_events'));
    }
    for (final s in _lwwSpecs) {
      if (!_on(categories, s.category)) continue;
      await run(userData, s.entity, listOf(s.entity));
    }

    if (_on(categories, SyncCategory.currentQueue)) {
      await _stashQueue(listOf('current_queue'), remoteDevice);
      done += listOf('current_queue').length;
      onProgress?.call(done, total);
    }

    final tombs = listOf('tombstones').where((t) {
      final spec = _specByEntity['${t['entity']}'];
      return spec != null && _on(categories, spec.category);
    }).toList();
    for (final isStats in [true, false]) {
      await run(
        isStats ? stats : userData,
        'tombstones',
        tombs
            .where((t) => _specByEntity['${t['entity']}']!.stats == isStats)
            .toList(),
      );
    }

    if (_on(categories, SyncCategory.settings)) {
      final items = listOf('settings');
      await _mergeSettings(items);
      done += items.length;
      onProgress?.call(done, total);
    }
    return MergeResult(total, 0);
  }

  Future<void> _stashQueue(List<Map> items, String remoteDevice) async {
    // A snapshot this device compacted carries its own queue back; that is not
    // a cloud queue to adopt.
    if (remoteDevice == deviceId) return;
    Map? best;
    for (final r in items) {
      if (r['queue_json'] is! String) continue;
      final h = (r['hlc'] as num?)?.toInt() ?? 0;
      if (best == null || h > ((best['hlc'] as num?)?.toInt() ?? 0)) best = r;
    }
    if (best == null) return;
    final cur = await settings.read(kStashedQueueKey);
    if (cur is String) {
      try {
        final ch = ((jsonDecode(cur) as Map)['hlc'] as num?)?.toInt() ?? 0;
        if (ch >= ((best['hlc'] as num?)?.toInt() ?? 0)) return;
      } catch (_) {}
    }
    await settings.write(kStashedQueueKey, jsonEncode(best));
  }

  /// Replaces the local current queue with the newest stashed cloud copy.
  /// Returns the applied queue, or null when there was nothing to apply.
  Future<Map<String, dynamic>?> applyStashedQueue() async {
    final raw = await settings.read(kStashedQueueKey);
    if (raw is! String || raw.isEmpty) return null;
    Map rec;
    Map<String, dynamic> queue;
    try {
      rec = jsonDecode(raw) as Map;
      // Already applied: only the clock is kept, so an older copy arriving
      // later (e.g. inside a compacted snapshot) is not stashed again.
      if (rec['queue_json'] is! String) return null;
      queue = Map<String, dynamic>.from(jsonDecode(rec['queue_json']) as Map);
    } catch (_) {
      await settings.write(kStashedQueueKey, '');
      return null;
    }
    final remoteHlc = (rec['hlc'] as num?)?.toInt() ?? 0;
    final result = await _store(userData, 'apply_queue', {'record': rec});
    if (result['applied'] != true) {
      await settings.write(kStashedQueueKey, jsonEncode({'hlc': remoteHlc}));
      return null;
    }
    await settings.write(kStashedQueueKey, jsonEncode({'hlc': rec['hlc']}));
    return queue;
  }

  Future<void> _mergeSettings(List<Map> items) async {
    for (final rec in items) {
      final key = rec['key'] as String?;
      final value = rec['value'];
      if (key == null ||
          value == null ||
          !kSyncableSettingsKeys.contains(key)) {
        continue;
      }
      final hlc = (rec['hlc'] as num?)?.toInt() ?? 0;
      final meta = await _rows(userData, 'settings_meta', {'key': key});
      final lh = meta.isEmpty ? -1 : (meta.first['hlc'] as num?)?.toInt() ?? 0;
      if (hlc <= lh) continue;
      await settings.write(key, value);
      await _store(userData, 'setting_write', {'key': key, 'hlc': hlc});
    }
  }

  // ------------------------------------------------------------- bulk paths

  /// Fast path for "set up as new device": plain batched inserts into tables
  /// that [wipe] just emptied. No per-row lookups; everything lands clean.
  Future<MergeResult> bulkImport(
    Map<String, dynamic> payload, {
    Set<String>? categories,
    MergeProgress? onProgress,
  }) async {
    await _importRemoteTracks(payload);
    final records =
        ((payload['records'] as Map?) ?? const {}).cast<String, dynamic>();
    final total = _countRecords(payload, categories);
    _observeClocks(payload);
    var done = 0;

    Future<void> insertAll(Database db, String entity, List<Map> rows) async {
      for (var i = 0; i < rows.length; i += kMergeBatchSize) {
        final chunk = rows.skip(i).take(kMergeBatchSize).toList();
        final result =
            await _store(db, 'bulk', {'entity': entity, 'rows': chunk});
        done += result['count'] as int;
        onProgress?.call(done, total);
      }
    }

    List<Map> listOf(String array) =>
        ((records[array] as List?) ?? const []).whereType<Map>().toList();

    for (final s in _allSpecs) {
      if (!_on(categories, s.category)) continue;
      await insertAll(_db(s), s.entity, listOf(s.entity));
    }

    for (final isStats in [true, false]) {
      final entities = _entities(isStats, categories).toSet();
      await insertAll(isStats ? stats : userData, 'tombstones', [
        for (final row in listOf('tombstones'))
          if (entities.contains(row['entity'])) row,
      ]);
    }

    if (_on(categories, SyncCategory.settings)) {
      final items = listOf('settings');
      await _mergeSettings(items);
      done += items.length;
      onProgress?.call(done, total);
    }
    return MergeResult(total, 0);
  }

  /// Deletes all synced rows, tombstones and setting metadata of [categories]
  /// (for "replace this device with cloud"). Setting values are left alone and
  /// get overwritten by the import.
  Future<void> wipe({Set<String>? categories}) async {
    for (final isStats in [true, false]) {
      await _store(isStats ? stats : userData, 'wipe', {
        'entities': [
          ..._entities(isStats, categories),
          if (!isStats && _on(categories, SyncCategory.settings)) 'settings',
        ],
      });
    }
  }
}
