import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'blob_codec.dart';
import 'changeset.dart';

enum SyncPhase {
  derivingKeys,
  authenticating,
  checking,
  downloadingSnapshot,
  applyingSnapshot,
  downloadingChanges,
  merging,
  preparingUpload,
  encrypting,
  uploading,
  finalizing,
  done,
  error,
}

class SyncProgress {
  final SyncPhase phase;
  final String message;
  final int bytesDone;
  final int bytesTotal;
  final int itemsDone;
  final int itemsTotal;
  const SyncProgress(
    this.phase, {
    this.message = '',
    this.bytesDone = 0,
    this.bytesTotal = 0,
    this.itemsDone = 0,
    this.itemsTotal = 0,
  });

  /// 0..1 when a determinate figure exists, otherwise null.
  double? get fraction {
    if (bytesTotal > 0) return (bytesDone / bytesTotal).clamp(0.0, 1.0);
    if (itemsTotal > 0) return (itemsDone / itemsTotal).clamp(0.0, 1.0);
    return null;
  }
}

typedef ProgressSink = void Function(SyncProgress);

/// Another device replaced the cloud data; auto-sync is paused until the user
/// picks a resolution.
class SyncEpochChangedException implements Exception {
  final int serverEpoch;
  const SyncEpochChangedException(this.serverEpoch);
  @override
  String toString() => 'Cloud data was replaced by another device';
}

class SyncRollbackException implements Exception {
  @override
  String toString() => 'Server state rolled back';
}

class SyncNotReadyException implements Exception {
  @override
  String toString() => 'Initial sync has not been completed';
}

/// Small key/value store for engine state (prefs in the app, a map in tests).
abstract class SyncKv {
  Object? get(String key);
  Future<void> set(String key, Object? value);
}

class PrefsSyncKv implements SyncKv {
  PrefsSyncKv(this._p);
  final SharedPreferences _p;

  static Future<PrefsSyncKv> open() async =>
      PrefsSyncKv(await SharedPreferences.getInstance());

  @override
  Object? get(String key) => _p.get(key);

  @override
  Future<void> set(String key, Object? value) async {
    if (value == null) {
      await _p.remove(key);
    } else if (value is bool) {
      await _p.setBool(key, value);
    } else if (value is int) {
      await _p.setInt(key, value);
    } else if (value is String) {
      await _p.setString(key, value);
    }
  }
}

class MemorySyncKv implements SyncKv {
  final Map<String, Object?> values = {};
  @override
  Object? get(String key) => values[key];
  @override
  Future<void> set(String key, Object? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

/// Orchestrates the cycle of plan_sync.md section 1.9 against one account.
/// Single-flight is the caller's job ([SyncService]).
class SyncEngine {
  SyncEngine({
    required this.client,
    required this.dataKey,
    required this.accountId,
    required this.changeset,
    required this.kv,
    required this.tmpDir,
    required this.stampSetting,
    Set<String> Function()? categories,
    bool Function()? preferCloudQueue,
    void Function()? onQueueApplied,
    ProgressSink? onProgress,
    int Function()? nowMs,
  })  : _categories = categories ?? (() => SyncCategory.all.toSet()),
        _preferCloudQueue = preferCloudQueue ?? (() => false),
        _onQueueApplied = onQueueApplied,
        _onProgress = onProgress,
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final SyncApiClient client;
  final Uint8List dataKey;
  final String accountId;
  final Changeset changeset;
  final SyncKv kv;
  final Directory tmpDir;
  final Future<void> Function(String key) stampSetting;
  final Set<String> Function() _categories;
  final bool Function() _preferCloudQueue;
  final void Function()? _onQueueApplied;
  final int Function() _nowMs;
  ProgressSink? _onProgress;

  set onProgress(ProgressSink? p) => _onProgress = p;

  static const kEpoch = 'sync_epoch';
  static const kCursor = 'sync_cursor_seq';
  static const kHighEpoch = 'sync_highest_epoch';
  static const kHighHead = 'sync_highest_head';
  static const kInitialDone = 'sync_initial_done';
  static const kSnapshotApplied = 'sync_snapshot_applied';
  static const kEpochChanged = 'sync_epoch_changed';
  static const kLastSync = 'sync_last_sync_ms';
  static const kLastCompaction = 'sync_last_compaction_ms';
  static const kSettingsSeen = 'sync_settings_seen';
  static const kPendingPull = 'sync_pending_category_pull';
  static const kDownloadId = 'sync_download_snapshot_id';
  static const _maxPushAttempts = 3;

  Set<String> get categories => _categories();
  int get _epoch => (kv.get(kEpoch) as int?) ?? 0;
  int get _cursor => (kv.get(kCursor) as int?) ?? 0;
  bool get initialDone => kv.get(kInitialDone) == true;
  int? get pausedForEpoch => kv.get(kEpochChanged) as int?;
  int? get lastSyncMs => kv.get(kLastSync) as int?;

  void _emit(SyncPhase p,
      {String message = '',
      int bytesDone = 0,
      int bytesTotal = 0,
      int itemsDone = 0,
      int itemsTotal = 0}) {
    _onProgress?.call(SyncProgress(p,
        message: message,
        bytesDone: bytesDone,
        bytesTotal: bytesTotal,
        itemsDone: itemsDone,
        itemsTotal: itemsTotal));
  }

  /// Categories that were switched on since the last sync need one full pull.
  Future<void> queueCategoryPull(Set<String> cats) async {
    if (cats.isEmpty) return;
    final cur = _pending()..addAll(cats);
    await kv.set(kPendingPull, jsonEncode(cur.toList()));
  }

  Set<String> _pending() {
    final raw = kv.get(kPendingPull) as String?;
    if (raw == null) return {};
    return (jsonDecode(raw) as List).cast<String>().toSet();
  }

  // ------------------------------------------------------------ sync cycle

  /// [manual] is a user-pressed sync; only then may the cloud's current queue
  /// replace the local one, and only when the user prefers the cloud queue.
  Future<void> sync({bool manual = false}) async {
    if (!initialDone) throw SyncNotReadyException();
    final paused = pausedForEpoch;
    if (paused != null) throw SyncEpochChangedException(paused);

    _emit(SyncPhase.checking, message: 'Checking cloud');
    var st = await client.state();
    await _guardEpoch(st);
    await _detectSettingsChanges();

    final pending = _pending().intersection(categories);
    if (pending.isNotEmpty) {
      await _pullCategories(st, pending);
    }

    await _pull(st);
    if (manual &&
        _preferCloudQueue() &&
        categories.contains(SyncCategory.currentQueue) &&
        await changeset.applyStashedQueue()) {
      _onQueueApplied?.call();
    }
    final pushed = await _push();
    if (pushed) st = await client.state();
    await _compactIfNeeded(st);

    await _recordHighest(st);
    await kv.set(kLastSync, _nowMs());
    await changeset.gcTombstones();
    _emit(SyncPhase.done, message: 'Up to date');
  }

  Future<void> _guardEpoch(SyncState st) async {
    if (st.epoch != _epoch) {
      await kv.set(kEpochChanged, st.epoch);
      throw SyncEpochChangedException(st.epoch);
    }
    final he = (kv.get(kHighEpoch) as int?) ?? 0;
    final hh = (kv.get(kHighHead) as int?) ?? 0;
    if (st.epoch < he || (st.epoch == he && st.headSeq < hh)) {
      throw SyncRollbackException();
    }
  }

  Future<void> _recordHighest(SyncState st) async {
    final he = (kv.get(kHighEpoch) as int?) ?? 0;
    final hh = (kv.get(kHighHead) as int?) ?? 0;
    final head = st.headSeq > _cursor ? st.headSeq : _cursor;
    if (st.epoch > he || (st.epoch == he && head > hh)) {
      await kv.set(kHighEpoch, st.epoch);
      await kv.set(kHighHead, head);
    }
  }

  // ------------------------------------------------------------------ pull

  Future<void> _pull(SyncState st, {bool bulk = false}) async {
    var cursor = _cursor;
    final needSnapshot = st.hasSnapshot &&
        (cursor < st.snapshotBaseSeq || kv.get(kSnapshotApplied) != true);
    if (needSnapshot) {
      await _applySnapshot(st, bulk: bulk);
      cursor = _cursor;
    }
    for (var gone = false;;) {
      try {
        await _pullDeltas(cursor, categories, advance: true);
        return;
      } on SyncApiException catch (e) {
        if (!e.isGone || gone) rethrow;
        gone = true;
        await _applySnapshot(await client.state(), bulk: false);
        cursor = _cursor;
      }
    }
  }

  Future<Map<String, dynamic>> _downloadSnapshot(
      SyncState st, int epoch) async {
    await tmpDir.create(recursive: true);
    final file = File('${tmpDir.path}/snapshot.dl');
    if (kv.get(kDownloadId) != st.snapshotId && await file.exists()) {
      await file.delete();
    }
    await kv.set(kDownloadId, st.snapshotId);
    _emit(SyncPhase.downloadingSnapshot, message: 'Downloading snapshot');
    final meta = await client.downloadSnapshot(
      file,
      onProgress: (d, t) => _emit(SyncPhase.downloadingSnapshot,
          message: 'Downloading snapshot', bytesDone: d, bytesTotal: t),
    );
    try {
      final json = await BlobCodec.decode(
        dataKey: dataKey,
        accountIdHex: accountId,
        expectedKind: BlobKind.snapshot,
        expectedEpoch: meta.epoch == 0 ? epoch : meta.epoch,
        input: file.openRead(),
      );
      final payload = BlobCodec.parsePayload(json);
      payload['__base_seq'] = meta.baseSeq;
      return payload;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    } finally {
      await kv.set(kDownloadId, null);
    }
  }

  Future<void> _deleteDownload() async {
    final f = File('${tmpDir.path}/snapshot.dl');
    if (await f.exists()) await f.delete();
  }

  Future<void> _applySnapshot(SyncState st, {required bool bulk}) async {
    final payload = await _downloadSnapshot(st, st.epoch);
    final base = payload.remove('__base_seq') as int;
    _emit(SyncPhase.applyingSnapshot, message: 'Applying snapshot');
    void progress(int d, int t) => _emit(SyncPhase.applyingSnapshot,
        message: 'Applying snapshot', itemsDone: d, itemsTotal: t);
    if (bulk) {
      await changeset.bulkImport(payload,
          categories: categories, onProgress: progress);
    } else {
      await changeset.merge(payload,
          categories: categories, onProgress: progress);
    }
    await _refreshSettingsSeen();
    await _deleteDownload();
    await kv.set(kCursor, base);
    await kv.set(kSnapshotApplied, true);
  }

  Future<void> _pullDeltas(int from, Set<String> cats,
      {required bool advance}) async {
    var cursor = from;
    while (true) {
      _emit(SyncPhase.downloadingChanges, message: 'Downloading changes');
      final page = await client.pullDeltas(
        cursor,
        onProgress: (d, t) => _emit(SyncPhase.downloadingChanges,
            message: 'Downloading changes', bytesDone: d, bytesTotal: t),
      );
      for (final f in page.frames) {
        final json = await BlobCodec.decode(
          dataKey: dataKey,
          accountIdHex: accountId,
          expectedKind: BlobKind.delta,
          expectedEpoch: _epoch,
          input: Stream.value(f.blob),
        );
        _emit(SyncPhase.merging, message: 'Merging changes');
        await changeset.merge(
          BlobCodec.parsePayload(json),
          categories: cats,
          onProgress: (d, t) => _emit(SyncPhase.merging,
              message: 'Merging changes', itemsDone: d, itemsTotal: t),
        );
        cursor = f.seq;
        if (advance) await kv.set(kCursor, cursor);
      }
      await _refreshSettingsSeen();
      if (!page.more || page.frames.isEmpty) return;
    }
  }

  Future<void> _pullCategories(SyncState st, Set<String> cats) async {
    var base = 0;
    if (st.hasSnapshot) {
      final payload = await _downloadSnapshot(st, st.epoch);
      base = payload.remove('__base_seq') as int;
      await changeset.merge(payload, categories: cats);
      await _deleteDownload();
    }
    await _pullDeltas(base, cats, advance: false);
    await _refreshSettingsSeen();
    final left = _pending()..removeAll(cats);
    await kv.set(kPendingPull, left.isEmpty ? null : jsonEncode(left.toList()));
  }

  // ------------------------------------------------------------------ push

  /// Returns true when something was uploaded.
  Future<bool> _push() async {
    var pushed = false;
    for (var attempt = 0; attempt < _maxPushAttempts; attempt++) {
      _emit(SyncPhase.preparingUpload, message: 'Preparing changes');
      final batches = await changeset.buildDeltas(categories: categories);
      if (batches.isEmpty) return pushed;
      var moved = false;
      for (final b in batches) {
        _emit(SyncPhase.encrypting, message: 'Encrypting changes');
        final blob = await BlobCodec.encode(
          dataKey: dataKey,
          accountIdHex: accountId,
          kind: BlobKind.delta,
          epoch: _epoch,
          payloadJson: utf8.encode(jsonEncode(b.payload)),
        );
        try {
          final seq = await client.pushDelta(
            blob,
            epoch: _epoch,
            expectHead: _cursor,
            onProgress: (d, t) => _emit(SyncPhase.uploading,
                message: 'Uploading changes', bytesDone: d, bytesTotal: t),
          );
          await kv.set(kCursor, seq);
          await changeset.markPushed(b);
          pushed = true;
        } on SyncApiException catch (e) {
          if (e.isEpochChanged) {
            final ep = (e.extra['epoch'] as int?) ?? _epoch + 1;
            await kv.set(kEpochChanged, ep);
            throw SyncEpochChangedException(ep);
          }
          if (!e.isHeadMoved) rethrow;
          moved = true;
          break;
        }
      }
      if (!moved) return pushed;
      await _pull(await client.state());
    }
    throw const SyncApiException(
        409, 'head_moved', 'Cloud kept changing; try again');
  }

  // ------------------------------------------------------------ compaction

  Future<void> _compactIfNeeded(SyncState st) async {
    if (!st.compactionRecommended) return;
    // A snapshot of fewer categories would erase the others from the cloud.
    if (!categories.containsAll(SyncCategory.all)) return;
    final last = (kv.get(kLastCompaction) as int?) ?? 0;
    if (_nowMs() - last < const Duration(hours: 24).inMilliseconds) return;
    try {
      _emit(SyncPhase.preparingUpload, message: 'Compacting cloud data');
      final snap = await changeset.buildSnapshot(categories: categories);
      final blob = await _encodeSnapshot(snap, _epoch);
      await client.uploadBlob(
        blob,
        kind: 'snapshot',
        epoch: _epoch,
        baseSeq: _cursor,
        onProgress: _uploadProgress,
      );
      await kv.set(kLastCompaction, _nowMs());
    } on SyncApiException {
      // Compaction is an optimisation; the next sync retries.
    }
  }

  @visibleForTesting
  Future<Uint8List> testEncodeSnapshot(ChangesetBatch snap) =>
      _encodeSnapshot(snap, _epoch);

  Future<Uint8List> _encodeSnapshot(ChangesetBatch snap, int epoch) async {
    _emit(SyncPhase.encrypting, message: 'Encrypting');
    return BlobCodec.encode(
      dataKey: dataKey,
      accountIdHex: accountId,
      kind: BlobKind.snapshot,
      epoch: epoch,
      payloadJson: utf8.encode(jsonEncode(snap.payload)),
    );
  }

  void _uploadProgress(int d, int t) => _emit(SyncPhase.uploading,
      message: 'Uploading', bytesDone: d, bytesTotal: t);

  // -------------------------------------------------- whole-state operations

  /// Replaces the cloud with this device's data (initial upload and
  /// "overwrite cloud"). Everything local ends clean.
  Future<void> overwriteCloud() async {
    _emit(SyncPhase.checking, message: 'Checking cloud');
    final st = await client.state();
    _emit(SyncPhase.preparingUpload, message: 'Preparing upload');
    await _detectSettingsChanges();
    final snap = await changeset.buildSnapshot(categories: categories);
    final newEpoch = st.epoch + 1;
    final blob = await _encodeSnapshot(snap, newEpoch);
    final after = await client.uploadBlob(
      blob,
      kind: 'reset',
      epoch: st.epoch,
      baseSeq: 0,
      onProgress: _uploadProgress,
    );
    _emit(SyncPhase.finalizing, message: 'Finishing');
    await changeset.markPushed(snap);
    await kv.set(kEpoch, after.epoch);
    await kv.set(kCursor, 0);
    await kv.set(kSnapshotApplied, true);
    await kv.set(kHighEpoch, after.epoch);
    await kv.set(kHighHead, 0);
    await kv.set(kEpochChanged, null);
    await kv.set(kPendingPull, null);
    await kv.set(kInitialDone, true);
    await kv.set(kLastSync, _nowMs());
    _emit(SyncPhase.done, message: 'Cloud overwritten');
  }

  /// Login choice 1 and "merge into the new cloud data".
  Future<void> mergeWithCloud() async {
    _emit(SyncPhase.checking, message: 'Checking cloud');
    final st = await client.state();
    final adopting = st.epoch != _epoch || !initialDone;
    if (adopting) {
      await kv.set(kEpoch, st.epoch);
      await kv.set(kCursor, 0);
      await kv.set(kSnapshotApplied, null);
      await kv.set(kHighEpoch, st.epoch);
      await kv.set(kHighHead, 0);
      await kv.set(kEpochChanged, null);
      // The cloud lost everything we pushed before; send it all again.
      await changeset.markAllDirty(categories: categories);
    }
    await kv.set(kInitialDone, true);
    await sync();
  }

  /// Login choice 2, "replace this device with cloud" and overwrite-local.
  Future<void> setUpAsNewDevice() async {
    _emit(SyncPhase.checking, message: 'Checking cloud');
    final st = await client.state();
    await changeset.wipe(categories: categories);
    await kv.set(kEpoch, st.epoch);
    await kv.set(kCursor, 0);
    await kv.set(kSnapshotApplied, null);
    await kv.set(kHighEpoch, st.epoch);
    await kv.set(kHighHead, 0);
    await kv.set(kEpochChanged, null);
    await kv.set(kPendingPull, null);
    await kv.set(kSettingsSeen, null);
    await _pull(st, bulk: true);
    await _refreshSettingsSeen();
    await kv.set(kInitialDone, true);
    await _recordHighest(await client.state());
    await kv.set(kLastSync, _nowMs());
    _emit(SyncPhase.done, message: 'Device set up');
  }

  // ------------------------------------------------------ settings tracking

  Future<Map<String, String>> _readSettings() async {
    final out = <String, String>{};
    for (final key in kSyncableSettingsKeys) {
      final v = await changeset.settings.read(key);
      if (v != null) out[key] = jsonEncode(v);
    }
    return out;
  }

  /// There is no central settings write path, so local edits are found by
  /// diffing against the values seen at the last sync.
  Future<void> _detectSettingsChanges() async {
    if (!categories.contains(SyncCategory.settings)) return;
    final raw = kv.get(kSettingsSeen) as String?;
    final seen = raw == null
        ? <String, dynamic>{}
        : (jsonDecode(raw) as Map).cast<String, dynamic>();
    final now = await _readSettings();
    for (final e in now.entries) {
      if (seen[e.key] != e.value) await stampSetting(e.key);
    }
    await kv.set(kSettingsSeen, jsonEncode(now));
  }

  Future<void> _refreshSettingsSeen() async {
    if (!categories.contains(SyncCategory.settings)) return;
    await kv.set(kSettingsSeen, jsonEncode(await _readSettings()));
  }
}
