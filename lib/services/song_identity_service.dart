import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../data/repositories/song_identity_repository.dart';
import '../domain/services/audio_content_id.dart';
import '../domain/services/song_identity.dart';
import '../models/song.dart';
import 'database_service.dart';
import 'storage_service.dart';

class IdentityReport {
  /// Songs whose user data followed a renamed file.
  final List<IdentityMove> moves;

  /// Files read and hashed during the run.
  final int hashed;
  final bool cancelled;
  const IdentityReport(this.moves, {this.hashed = 0, this.cancelled = false});
  bool get changedUserData => moves.isNotEmpty;
}

/// A user-started run goes faster than the background one and reports
/// progress, but still yields between chunks and stops on request.
class IdentityRunOptions {
  /// Re-hash every file, ignoring stored mtimes and the unreadable cache.
  final bool force;
  final void Function(int done, int total)? onProgress;
  final bool Function()? isCancelled;
  const IdentityRunOptions(
      {this.force = false, this.onProgress, this.isCancelled});
}

/// Keeps `song_identity` current and re-attaches user data to files that were
/// renamed outside the app, restored from a backup under other names, or
/// described by another device under another name.
class SongIdentityService {
  SongIdentityService._();
  static final SongIdentityService instance = SongIdentityService._();

  // Small chunks plus a sleep proportional to the work keep the duty cycle low
  // so storage, CPU and the UI isolate stay free for playback and scrolling.
  static final bool _desktop =
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  static int _probeBatch(bool manual) =>
      manual ? (_desktop ? 32 : 24) : (_desktop ? 16 : 8);
  static double _restFactor(bool manual) =>
      manual ? (_desktop ? 0.5 : 1.0) : (_desktop ? 4.0 : 10.0);
  static int _minRestMs(bool manual) => manual ? 10 : 100;
  static const int _flushEvery = 200;
  static const double _mtimeTolerance = 2.0;

  static const int _statBatch = 500;

  // Files that exist but yield no id, keyed by the mtime they failed at, so
  // they are not re-read on every scan until they change.
  final Map<String, double?> _unreadable = {};

  bool _running = false;

  static int _workerCount(bool manual) => manual && _desktop ? 2 : 1;

  bool get isRunning => _running;

  // Low-priority housekeeping: it only advances while the user has the app
  // open, and waits (progress is already saved) otherwise.
  static Future<void> _waitForeground() async {
    while (true) {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed) return;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  /// Reconciles [songs] (rows believed to be in the library) against disk.
  ///
  /// Hashing only touches files that are new or whose mtime changed, so after
  /// the first pass this is a stat sweep plus a handful of reads.
  Future<IdentityReport> reconcile(List<Song> songs,
      {IdentityRunOptions? options}) async {
    if (_running) return const IdentityReport([]);
    _running = true;
    try {
      return await _reconcile(songs, options);
    } catch (e, st) {
      debugPrint('Song identity reconcile failed: $e\n$st');
      return const IdentityReport([]);
    } finally {
      _running = false;
    }
  }

  Future<IdentityReport> reconcileFromLibrary(
          {IdentityRunOptions? options}) async =>
      reconcile(await DatabaseService.instance.getAllSongs(), options: options);

  Future<IdentityReport> _reconcile(
      List<Song> songs, IdentityRunOptions? options) async {
    final manual = options != null;
    final force = options?.force ?? false;
    bool cancelled() => options?.isCancelled?.call() ?? false;
    if (songs.isEmpty) return const IdentityReport([]);
    final db = await DatabaseService.instance.userDataDb;
    final known = {
      for (final r in await SongIdentityRepository.loadAll(db)) r.filename: r
    };

    // A missing music folder (unmounted card, revoked permission) makes every
    // file on it look deleted, which must not read as a rename source.
    final folders = await StorageService().getMusicFolders();
    var foldersReadable = folders.isNotEmpty;
    for (final f in folders) {
      final path = f['path'];
      if (path == null || path.isEmpty) continue;
      if (!await Directory(path).exists()) foldersReadable = false;
    }

    final byName = <String, Song>{};
    for (final s in songs) {
      byName.putIfAbsent(s.filename, () => s);
    }
    final urls = byName.values.map((s) => s.url).toList();
    final nameByUrl = {for (final s in byName.values) s.url: s.filename};

    // Stats are cheap; deciding freshness from a real stat also covers rows
    // whose scanned mtime is missing.
    final present = <String>{};
    final upserts = <IdentityRow>[];
    final toHash = <String>[];
    for (var i = 0; i < urls.length; i += _statBatch) {
      await _waitForeground();
      final chunk = urls.sublist(i, min(i + _statBatch, urls.length));
      final probes = await Isolate.run(() => probeFilesSync(chunk, const {}));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      for (final probe in probes) {
        if (!probe.exists) continue;
        final name = nameByUrl[probe.path]!;
        present.add(name);
        final row = known[name];
        final fresh = !force &&
            row != null &&
            row.mtime != null &&
            probe.mtime != null &&
            (row.mtime! - probe.mtime!).abs() < _mtimeTolerance;
        if (fresh) {
          if (row.status != IdentityStatus.live) {
            upserts.add(row.copyWith(status: IdentityStatus.live));
          }
        } else if (force ||
            !(_unreadable.containsKey(probe.path) &&
                _unreadable[probe.path] == probe.mtime)) {
          toHash.add(probe.path);
        }
      }
    }

    var flushed = 0;
    var hashedCount = 0;
    options?.onProgress?.call(0, toHash.length);
    var flushing = false;
    final workers = _workerCount(manual);
    final queue = toHash.iterator;
    Future<void> worker() async {
      while (true) {
        await _waitForeground();
        if (cancelled()) return;
        final chunk = <String>[];
        while (chunk.length < _probeBatch(manual) && queue.moveNext()) {
          chunk.add(queue.current);
        }
        if (chunk.isEmpty) return;
        final hashSet = chunk.toSet();
        final clock = Stopwatch()..start();
        final probes = await Isolate.run(() => probeFilesSync(chunk, hashSet));
        for (final probe in probes) {
          if (!probe.exists) continue;
          final cid = probe.contentId;
          if (cid != null) {
            _unreadable.remove(probe.path);
            upserts.add(IdentityRow(
                filename: nameByUrl[probe.path]!,
                cid: cid,
                mtime: probe.mtime));
          } else {
            _unreadable[probe.path] = probe.mtime;
          }
        }
        hashedCount += chunk.length;
        options?.onProgress?.call(hashedCount, toHash.length);
        if (upserts.length - flushed >= _flushEvery && !flushing) {
          flushing = true;
          final batch = upserts.sublist(flushed);
          flushed = upserts.length;
          await SongIdentityRepository.upsertAll(db, batch);
          flushing = false;
        }
        final rest = (clock.elapsedMilliseconds * _restFactor(manual)).round();
        await Future<void>.delayed(
            Duration(milliseconds: max(_minRestMs(manual), rest)));
      }
    }

    await Future.wait([for (var i = 0; i < workers; i++) worker()]);

    if (cancelled()) {
      await SongIdentityRepository.upsertAll(db, upserts.sublist(flushed));
      return IdentityReport(const [], hashed: hashedCount, cancelled: true);
    }

    for (final u in upserts) {
      known[u.filename] = u;
    }
    final demoted = <String>[];
    if (foldersReadable) {
      for (final r in known.values.toList()) {
        if (r.status == IdentityStatus.live && !present.contains(r.filename)) {
          known[r.filename] = r.copyWith(status: IdentityStatus.orphan);
          demoted.add(r.filename);
        }
      }
    }
    await SongIdentityRepository.upsertAll(db, upserts.sublist(flushed));
    await SongIdentityRepository.setStatus(db, demoted, IdentityStatus.orphan);

    if (!foldersReadable) return IdentityReport(const [], hashed: hashedCount);

    final moves = IdentityIndex(known.values).planHeals();
    if (moves.isEmpty) return IdentityReport(const [], hashed: hashedCount);

    // The scan already wrote a row for the new name; a stale row under the old
    // name would otherwise be moved on top of it with the wrong folder.
    await DatabaseService.instance
        .deleteSongsByFilenames(moves.map((m) => m.from));
    await DatabaseService.instance
        .renameFiles([for (final m in moves) (from: m.from, to: m.to)]);
    debugPrint('Song identity: followed ${moves.length} renamed files');
    return IdentityReport(moves, hashed: hashedCount);
  }
}
