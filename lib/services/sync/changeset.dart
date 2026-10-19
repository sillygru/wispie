import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/repositories/song_identity_repository.dart';
import '../../domain/services/song_identity.dart';
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
  final String table;
  final bool stats;
  final List<String> keyCols;
  final List<String> dataCols;
  const _Spec(this.entity, this.category, this.table, this.stats, this.keyCols,
      this.dataCols);
}

const List<_Spec> _lwwSpecs = [
  _Spec('favorites', SyncCategory.favorites, 'favorite', false, ['filename'],
      ['added_at']),
  _Spec('suggestless', SyncCategory.suggestless, 'suggestless', false,
      ['filename'], ['added_at']),
  _Spec('hidden', SyncCategory.hidden, 'hidden', false, ['filename'],
      ['hidden_at']),
  _Spec('playlists', SyncCategory.playlists, 'playlist', false, ['id'],
      ['name', 'description', 'is_recommendation', 'created_at', 'updated_at']),
  _Spec('playlist_songs', SyncCategory.playlists, 'playlist_song', false,
      ['playlist_id', 'song_filename'], ['added_at']),
  _Spec('merged_groups', SyncCategory.mergedSongs, 'merged_song_group', false,
      ['id'], ['priority_filename', 'created_at']),
  _Spec('merged_songs', SyncCategory.mergedSongs, 'merged_song', false,
      ['filename'], ['group_id', 'added_at']),
  _Spec('artist_art', SyncCategory.artistArt, 'artist_art', false,
      ['artist_name'], ['image_url', 'source', 'updated_at']),
  _Spec('album_art', SyncCategory.albumArt, 'album_art', false, ['album_key'],
      ['album_name', 'artist_name', 'image_url', 'source', 'updated_at']),
  _Spec('queue_snapshots', SyncCategory.queueHistory, 'queue_snapshot', false,
      ['id'], ['name', 'created_at', 'source', 'song_count', 'songs_json']),
];

/// Merged by hand: remote copies are stashed and only applied on a manual sync
/// that prefers the cloud queue, so auto-sync never replaces what is playing.
const _Spec _currentQueueSpec = _Spec(
    'current_queue',
    SyncCategory.currentQueue,
    'current_queue',
    false,
    ['id'],
    ['queue_json', 'updated_at']);
const String kStashedQueueKey = 'sync_stashed_remote_queue';

const _Spec _sessionSpec = _Spec(
    'play_sessions',
    SyncCategory.playStats,
    'playsession',
    true,
    ['id'],
    ['start_time', 'end_time', 'platform', 'device_id']);
const _Spec _eventSpec =
    _Spec('play_events', SyncCategory.playStats, 'playevent', true, [
  'uid'
], [
  'session_id',
  'song_filename',
  'timestamp',
  'duration_played',
  'total_length',
  'play_ratio',
  'foreground_duration',
  'background_duration',
  'source',
  'queue_id',
]);

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
const String _sep = '\u0000';

class _Clear {
  final bool stats;
  final String table;
  final String where;
  final List<Object?> args;
  final int hlc;
  const _Clear(this.stats, this.table, this.where, this.args, this.hlc);
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
    await _attachIdentity(batches.map((b) => b.payload));
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
    final remapped = remapSongNames(records, (name) {
      final cid = remote[name];
      final target = index.resolve(name, remoteCid: cid);
      if (target == name &&
          cid != null &&
          index.byFilename[name] == null &&
          index.liveFilesFor(cid).isEmpty) {
        learned[name] = cid;
      }
      return target;
    });
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

  /// Rows migrated from before sync have a null hlc; LWW needs a real one.
  Future<void> _stampLegacy(Set<String>? cats) async {
    for (final s in _allSpecs) {
      if (!_on(cats, s.category)) continue;
      await _db(s).rawUpdate(
          'UPDATE ${s.table} SET hlc = ? WHERE hlc IS NULL AND dirty = 1',
          [Hlc.instance.now()]);
    }
    await stats.rawUpdate('UPDATE sync_tombstone SET hlc = ? WHERE hlc IS NULL',
        [Hlc.instance.now()]);
    await userData.rawUpdate(
        'UPDATE sync_tombstone SET hlc = ? WHERE hlc IS NULL',
        [Hlc.instance.now()]);
  }

  Stream<_Item> _collect(Set<String>? cats, {required bool dirtyOnly}) async* {
    const page = 2000;
    for (final s in _allSpecs) {
      if (!_on(cats, s.category)) continue;
      final cols = [...s.keyCols, ...s.dataCols, 'hlc'];
      var offset = 0;
      while (true) {
        final rows = await _db(s).query(
          s.table,
          columns: cols,
          where: dirtyOnly ? 'dirty = 1' : null,
          orderBy: 'rowid',
          limit: page,
          offset: offset,
        );
        for (final row in rows) {
          if (s == _eventSpec && row['uid'] == null) continue;
          final rec = <String, Object?>{for (final c in cols) c: row[c]};
          yield _Item(
            s.entity,
            rec,
            _Clear(
              s.stats,
              s.table,
              s.keyCols.map((c) => '$c = ?').join(' AND '),
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
      final rows = await (isStats ? stats : userData).query(
        'sync_tombstone',
        where: dirtyOnly ? 'dirty = 1' : null,
      );
      for (final row in rows) {
        final entity = row['entity'] as String;
        final spec = _specByEntity[entity];
        if (spec == null || !_on(cats, spec.category)) continue;
        final hlc = (row['hlc'] as num).toInt();
        if (!dirtyOnly && hlc < cutoff) continue;
        yield _Item(
          'tombstones',
          {'entity': entity, 'key': row['key'], 'hlc': hlc},
          _Clear(isStats, 'sync_tombstone', 'entity = ? AND key = ?',
              [entity, row['key']], hlc),
        );
      }
    }

    if (_on(cats, SyncCategory.settings)) {
      final metas = await userData.query('sync_setting_meta',
          where: dirtyOnly ? 'dirty = 1' : null);
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
          meta == null
              ? null
              : _Clear(false, 'sync_setting_meta', 'key = ?', [key], hlc),
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
      await (isStats ? stats : userData).transaction((txn) async {
        final b = txn.batch();
        for (final c in mine) {
          b.rawUpdate(
              'UPDATE ${c.table} SET dirty = 0 WHERE ${c.where} AND hlc = ?',
              [...c.args, c.hlc]);
        }
        await b.commit(noResult: true);
      });
    }
  }

  /// Flags everything of [categories] dirty so the next push re-uploads it
  /// (used when the cloud was replaced by another device and we merge into it).
  Future<void> markAllDirty({Set<String>? categories}) async {
    for (final s in _allSpecs) {
      if (!_on(categories, s.category)) continue;
      await _db(s).rawUpdate(
          'UPDATE ${s.table} SET dirty = 1, hlc = COALESCE(hlc, ?)',
          [Hlc.instance.now()]);
    }
    for (final isStats in [true, false]) {
      final entities = [
        for (final s in _allSpecs)
          if (s.stats == isStats && _on(categories, s.category)) s.entity
      ];
      if (entities.isEmpty) continue;
      await (isStats ? stats : userData).update('sync_tombstone', {'dirty': 1},
          where: 'entity IN (${List.filled(entities.length, '?').join(',')})',
          whereArgs: entities);
    }
    if (_on(categories, SyncCategory.settings)) {
      for (final key in kSyncableSettingsKeys) {
        if (await settings.read(key) == null) continue;
        final meta = await userData.query('sync_setting_meta',
            columns: ['hlc'], where: 'key = ?', whereArgs: [key]);
        await userData.insert(
          'sync_setting_meta',
          {
            'key': key,
            'hlc': meta.isEmpty
                ? Hlc.instance.now()
                : (meta.first['hlc'] as num?)?.toInt() ?? Hlc.instance.now(),
            'dirty': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  /// Drops tombstones past the retention window.
  Future<void> gcTombstones() async {
    final cutoff = (nowMs() - kTombstoneRetention.inMilliseconds) << 16;
    for (final db in [stats, userData]) {
      await db.delete('sync_tombstone', where: 'hlc < ?', whereArgs: [cutoff]);
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
    final records =
        ((payload['records'] as Map?) ?? const {}).cast<String, dynamic>();
    final remoteDevice = '${payload['device_id'] ?? ''}';
    final total = _countRecords(payload, categories);
    _observeClocks(payload);
    var done = 0;

    Future<void> run(Database db, List<Map> items,
        Future<void> Function(DatabaseExecutor, Map) fn) async {
      for (var i = 0; i < items.length; i += kMergeBatchSize) {
        final chunk = items.skip(i).take(kMergeBatchSize);
        await db.transaction((txn) async {
          for (final item in chunk) {
            await fn(txn, item);
          }
        });
        done += chunk.length;
        onProgress?.call(done, total);
      }
    }

    List<Map> listOf(String array) =>
        ((records[array] as List?) ?? const []).whereType<Map>().toList();

    if (_on(categories, SyncCategory.playStats)) {
      await run(stats, listOf('play_sessions'), _mergeSession);
      await run(stats, listOf('play_events'), _mergeEvent);
    }
    for (final s in _lwwSpecs) {
      if (!_on(categories, s.category)) continue;
      await run(userData, listOf(s.entity),
          (txn, rec) => _mergeLww(txn, s, rec, remoteDevice));
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
        tombs
            .where((t) => _specByEntity['${t['entity']}']!.stats == isStats)
            .toList(),
        _mergeTombstone,
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

  Future<int?> _tombHlc(DatabaseExecutor txn, String entity, String key) async {
    final r = await txn.query('sync_tombstone',
        columns: ['hlc'],
        where: 'entity = ? AND key = ?',
        whereArgs: [entity, key],
        limit: 1);
    if (r.isEmpty) return null;
    return (r.first['hlc'] as num?)?.toInt() ?? 0;
  }

  Future<void> _dropTomb(DatabaseExecutor txn, String entity, String key) =>
      txn.delete('sync_tombstone',
          where: 'entity = ? AND key = ?', whereArgs: [entity, key]);

  static String _keyOf(_Spec s, Map rec) =>
      s.keyCols.map((c) => '${rec[c]}').join(_sep);

  static bool _keyValid(_Spec s, Map rec) =>
      s.keyCols.every((c) => rec[c] != null && '${rec[c]}'.isNotEmpty);

  static String _where(_Spec s) => s.keyCols.map((c) => '$c = ?').join(' AND ');

  Future<void> _mergeLww(
      DatabaseExecutor txn, _Spec s, Map rec, String remoteDevice) async {
    if (!_keyValid(s, rec)) return;
    final key = _keyOf(s, rec);
    final hlc = (rec['hlc'] as num?)?.toInt() ?? 0;
    final tomb = await _tombHlc(txn, s.entity, key);
    if (tomb != null) {
      if (tomb > hlc) return;
      await _dropTomb(txn, s.entity, key);
    }
    final args = s.keyCols.map((c) => rec[c]).toList();
    final local = await txn.query(s.table,
        columns: ['hlc'], where: _where(s), whereArgs: args, limit: 1);
    final data = {for (final c in s.dataCols) c: rec[c]};
    if (local.isEmpty) {
      await txn.insert(s.table, {
        for (final c in s.keyCols) c: rec[c],
        ...data,
        'hlc': hlc,
        'dirty': 0,
      });
      await _rebuildSnapshotSongs(txn, s, rec);
      return;
    }
    final lh = (local.first['hlc'] as num?)?.toInt() ?? 0;
    if (hlc > lh || (hlc == lh && remoteDevice.compareTo(deviceId) > 0)) {
      await txn.update(s.table, {...data, 'hlc': hlc, 'dirty': 0},
          where: _where(s), whereArgs: args);
      await _rebuildSnapshotSongs(txn, s, rec);
    }
  }

  /// `queue_snapshot_song` is the local read model; `songs_json` is what syncs.
  Future<void> _rebuildSnapshotSongs(
      DatabaseExecutor txn, _Spec s, Map rec) async {
    if (s.table != 'queue_snapshot') return;
    final id = '${rec['id']}';
    await txn.delete('queue_snapshot_song',
        where: 'snapshot_id = ?', whereArgs: [id]);
    final raw = rec['songs_json'];
    if (raw is! String) return;
    List songs;
    try {
      songs = jsonDecode(raw) as List;
    } catch (_) {
      return;
    }
    final b = txn.batch();
    for (var i = 0; i < songs.length; i++) {
      b.insert('queue_snapshot_song',
          {'snapshot_id': id, 'song_filename': '${songs[i]}', 'position': i});
    }
    await b.commit(noResult: true);
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
    final local = await userData.query('current_queue',
        columns: ['hlc', 'dirty'],
        where: 'id = ?',
        whereArgs: [rec['id'] ?? 'current'],
        limit: 1);
    // A clean local row with a newer clock was pushed after the stashed copy,
    // so it already is the newest queue in the cloud.
    if (local.isNotEmpty &&
        local.first['dirty'] == 0 &&
        ((local.first['hlc'] as num?)?.toInt() ?? 0) > remoteHlc) {
      await settings.write(kStashedQueueKey, jsonEncode({'hlc': remoteHlc}));
      return null;
    }
    await userData.insert(
      'current_queue',
      {
        'id': rec['id'] ?? 'current',
        'queue_json': rec['queue_json'],
        'updated_at': rec['updated_at'],
        'hlc': (rec['hlc'] as num?)?.toInt() ?? 0,
        'dirty': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await settings.write(kStashedQueueKey, jsonEncode({'hlc': rec['hlc']}));
    return queue;
  }

  Future<void> _mergeTombstone(DatabaseExecutor txn, Map t) async {
    final entity = '${t['entity']}';
    final spec = _specByEntity[entity]!;
    final key = '${t['key']}';
    final hlc = (t['hlc'] as num?)?.toInt() ?? 0;
    final parts = key.split(_sep);
    if (parts.length != spec.keyCols.length) return;

    final row = await txn.query(spec.table,
        columns: ['hlc'], where: _where(spec), whereArgs: parts, limit: 1);
    if (row.isNotEmpty) {
      final lh = (row.first['hlc'] as num?)?.toInt() ?? 0;
      if (hlc <= lh) return;
      await txn.delete(spec.table, where: _where(spec), whereArgs: parts);
      if (spec.table == 'queue_snapshot') {
        await txn.delete('queue_snapshot_song',
            where: 'snapshot_id = ?', whereArgs: parts);
      }
    }
    final existing = await _tombHlc(txn, entity, key);
    if (existing == null || hlc > existing) {
      await txn.insert(
        'sync_tombstone',
        {'entity': entity, 'key': key, 'hlc': hlc, 'dirty': 0},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static double? _d(Object? v) => (v as num?)?.toDouble();

  static String? _maxStr(String? a, String? b) {
    if (a == null || a.isEmpty) return b;
    if (b == null || b.isEmpty) return a;
    return a.compareTo(b) >= 0 ? a : b;
  }

  static bool _sameFields(
      Map<String, Object?> a, Map b, Iterable<String> cols) {
    for (final c in cols) {
      if (a[c] != b[c]) return false;
    }
    return true;
  }

  Future<void> _mergeSession(DatabaseExecutor txn, Map rec) async {
    final id = rec['id'] as String?;
    if (id == null || id.isEmpty) return;
    final hlc = (rec['hlc'] as num?)?.toInt() ?? 0;
    final tomb = await _tombHlc(txn, 'play_sessions', id);
    if (tomb != null) {
      if (tomb > hlc) return;
      await _dropTomb(txn, 'play_sessions', id);
    }
    final incoming = <String, Object?>{
      'start_time': _d(rec['start_time']),
      'end_time': _d(rec['end_time']),
      'platform': rec['platform'] as String?,
      'device_id': rec['device_id'] as String?,
    };
    final local = await txn.query('playsession',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (local.isEmpty) {
      await txn.insert(
          'playsession', {'id': id, ...incoming, 'hlc': hlc, 'dirty': 0});
      return;
    }
    final l = local.first;
    double? pick(double? a, double? b, bool wantMin) {
      if (a == null) return b;
      if (b == null) return a;
      return wantMin ? min(a, b) : max(a, b);
    }

    String? platform(String? a, String? b) {
      final x = a == 'unknown' ? null : a;
      final y = b == 'unknown' ? null : b;
      return _maxStr(x, y) ?? a ?? b;
    }

    String? device(String? a, String? b) {
      if (a == null || a.isEmpty) return b;
      if (b == null || b.isEmpty) return a;
      return a.compareTo(b) <= 0 ? a : b;
    }

    final merged = <String, Object?>{
      'start_time':
          pick(_d(l['start_time']), incoming['start_time'] as double?, true),
      'end_time':
          pick(_d(l['end_time']), incoming['end_time'] as double?, false),
      'platform':
          platform(l['platform'] as String?, incoming['platform'] as String?),
      'device_id':
          device(l['device_id'] as String?, incoming['device_id'] as String?),
    };
    const cols = ['start_time', 'end_time', 'platform', 'device_id'];
    if (_sameFields(merged, l, cols)) return;
    final lh = (l['hlc'] as num?)?.toInt() ?? 0;
    await txn.update(
        'playsession',
        {
          ...merged,
          'hlc': max(lh, hlc),
          'dirty': _sameFields(merged, incoming, cols) ? 0 : 1,
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  /// Same bounds as the legacy `isSync` path: duration beyond
  /// `total*1.05+10` collapses to the track length. Returns null if unusable.
  static Map<String, Object?>? sanitizeEvent(Map rec) {
    final uid = rec['uid'] as String?;
    final sid = rec['session_id'] as String?;
    final fn = rec['song_filename'] as String?;
    final ts = _d(rec['timestamp']);
    if (uid == null || uid.isEmpty || sid == null || sid.isEmpty) return null;
    if (fn == null || fn.isEmpty || ts == null) return null;
    final total = max(0.0, _d(rec['total_length']) ?? 0.0);
    var dur = max(0.0, _d(rec['duration_played']) ?? 0.0);
    if (total > 0 && dur > total * 1.05 + 10.0) dur = total;
    final ratio = total > 0
        ? min(1.0, dur / total)
        : max(0.0, _d(rec['play_ratio']) ?? 0.0);
    return {
      'uid': uid,
      'session_id': sid,
      'song_filename': fn,
      'timestamp': ts,
      'duration_played': dur,
      'total_length': total,
      'play_ratio': ratio,
      'foreground_duration': max(0.0, _d(rec['foreground_duration']) ?? 0.0),
      'background_duration': max(0.0, _d(rec['background_duration']) ?? 0.0),
      'source': rec['source'] as String?,
      'queue_id': rec['queue_id'] as String?,
    };
  }

  Future<void> _mergeEvent(DatabaseExecutor txn, Map rec) async {
    final inc = sanitizeEvent(rec);
    if (inc == null) return;
    final uid = inc['uid'] as String;
    final hlc = (rec['hlc'] as num?)?.toInt() ?? 0;
    final tomb = await _tombHlc(txn, 'play_events', uid);
    if (tomb != null) {
      if (tomb > hlc) return;
      await _dropTomb(txn, 'play_events', uid);
    }
    final local = await txn.query('playevent',
        where: 'uid = ?', whereArgs: [uid], limit: 1);
    if (local.isEmpty) {
      await txn.insert('playevent', {...inc, 'hlc': hlc, 'dirty': 0});
      return;
    }
    final l = local.first;
    final lh = (l['hlc'] as num?)?.toInt() ?? 0;
    double m(String c) => max(_d(l[c]) ?? 0.0, _d(inc[c]) ?? 0.0);
    final dur = m('duration_played');
    final total = m('total_length');
    final incomingWins = hlc > lh ||
        (hlc == lh &&
            '${inc['session_id']}${inc['song_filename']}'
                    .compareTo('${l['session_id']}${l['song_filename']}') >
                0);
    final src = incomingWins ? inc : l;
    final merged = <String, Object?>{
      'session_id': src['session_id'],
      'song_filename': src['song_filename'],
      'timestamp': m('timestamp'),
      'duration_played': dur,
      'total_length': total,
      'play_ratio': total > 0 ? min(1.0, dur / total) : m('play_ratio'),
      'foreground_duration': m('foreground_duration'),
      'background_duration': m('background_duration'),
      'source': _maxStr(l['source'] as String?, inc['source'] as String?),
      // Events from clients that predate queue ids carry none; never let that
      // erase a known one.
      'queue_id': (src['queue_id'] as String?) ??
          (incomingWins ? l['queue_id'] : inc['queue_id']) as String?,
    };
    final cols = merged.keys;
    if (_sameFields(merged, l, cols)) return;
    await txn.update(
        'playevent',
        {
          ...merged,
          'hlc': max(lh, hlc),
          'dirty': _sameFields(merged, inc, cols) ? 0 : 1,
        },
        where: 'uid = ?',
        whereArgs: [uid]);
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
      final meta = await userData.query('sync_setting_meta',
          where: 'key = ?', whereArgs: [key], limit: 1);
      final lh = meta.isEmpty ? -1 : (meta.first['hlc'] as num?)?.toInt() ?? 0;
      if (hlc <= lh) continue;
      await settings.write(key, value);
      await userData.insert(
        'sync_setting_meta',
        {'key': key, 'hlc': hlc, 'dirty': 0},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
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
    final records =
        ((payload['records'] as Map?) ?? const {}).cast<String, dynamic>();
    final total = _countRecords(payload, categories);
    _observeClocks(payload);
    var done = 0;

    Future<void> insertAll(
        Database db, String table, List<Map<String, Object?>> rows) async {
      for (var i = 0; i < rows.length; i += kMergeBatchSize) {
        final chunk = rows.skip(i).take(kMergeBatchSize).toList();
        await db.transaction((txn) async {
          final b = txn.batch();
          for (final r in chunk) {
            b.insert(table, r, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
          await b.commit(noResult: true);
        });
        done += chunk.length;
        onProgress?.call(done, total);
      }
    }

    List<Map> listOf(String array) =>
        ((records[array] as List?) ?? const []).whereType<Map>().toList();

    for (final s in _allSpecs) {
      if (!_on(categories, s.category)) continue;
      final rows = <Map<String, Object?>>[];
      for (final rec in listOf(s.entity)) {
        if (s == _eventSpec) {
          final inc = sanitizeEvent(rec);
          if (inc == null) continue;
          rows.add(
              {...inc, 'hlc': (rec['hlc'] as num?)?.toInt() ?? 0, 'dirty': 0});
          continue;
        }
        if (!_keyValid(s, rec)) continue;
        rows.add({
          for (final c in [...s.keyCols, ...s.dataCols]) c: rec[c],
          'hlc': (rec['hlc'] as num?)?.toInt() ?? 0,
          'dirty': 0,
        });
      }
      await insertAll(_db(s), s.table, rows);
      if (s.table == 'queue_snapshot') {
        await userData.transaction((txn) async {
          for (final r in rows) {
            await _rebuildSnapshotSongs(txn, s, r);
          }
        });
      }
    }

    for (final isStats in [true, false]) {
      final rows = <Map<String, Object?>>[];
      for (final t in listOf('tombstones')) {
        final spec = _specByEntity['${t['entity']}'];
        if (spec == null || !_on(categories, spec.category)) continue;
        if (spec.stats != isStats) continue;
        rows.add({
          'entity': t['entity'],
          'key': '${t['key']}',
          'hlc': (t['hlc'] as num?)?.toInt() ?? 0,
          'dirty': 0,
        });
      }
      await insertAll(isStats ? stats : userData, 'sync_tombstone', rows);
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
      final db = isStats ? stats : userData;
      await db.transaction((txn) async {
        final entities = <String>[];
        for (final s in _allSpecs) {
          if (s.stats != isStats || !_on(categories, s.category)) continue;
          await txn.delete(s.table);
          if (s.table == 'queue_snapshot') {
            await txn.delete('queue_snapshot_song');
          }
          entities.add(s.entity);
        }
        if (entities.isNotEmpty) {
          await txn.delete('sync_tombstone',
              where:
                  'entity IN (${List.filled(entities.length, '?').join(',')})',
              whereArgs: entities);
        }
        if (!isStats && _on(categories, SyncCategory.settings)) {
          await txn.delete('sync_setting_meta');
        }
      });
    }
  }
}
