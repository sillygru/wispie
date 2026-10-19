import 'package:sqflite/sqflite.dart';

import '../../domain/services/song_identity.dart';

/// Storage for `song_identity`. All methods take an executor so callers can
/// join an existing transaction (renames, sync merges).
class SongIdentityRepository {
  SongIdentityRepository._();

  /// Bumped on every write so readers can keep a built index across calls.
  static int generation = 0;

  static IdentityStatus _status(Object? v) {
    switch ((v as num?)?.toInt()) {
      case 1:
        return IdentityStatus.orphan;
      case 2:
        return IdentityStatus.alias;
      default:
        return IdentityStatus.live;
    }
  }

  static IdentityRow _row(Map<String, Object?> m) => IdentityRow(
        filename: m['filename'] as String,
        cid: m['cid'] as String,
        mtime: (m['mtime'] as num?)?.toDouble(),
        status: _status(m['status']),
      );

  static Map<String, Object?> _map(IdentityRow r) => {
        'filename': r.filename,
        'cid': r.cid,
        'mtime': r.mtime,
        'status': r.status.index,
        'seen_at': DateTime.now().millisecondsSinceEpoch / 1000.0,
      };

  static Future<List<IdentityRow>> loadAll(DatabaseExecutor db) async =>
      (await db.query('song_identity')).map(_row).toList();

  static Future<void> upsertAll(
      DatabaseExecutor db, Iterable<IdentityRow> rows) async {
    generation++;
    final b = db.batch();
    for (final r in rows) {
      b.insert('song_identity', _map(r),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await b.commit(noResult: true);
  }

  static Future<void> setStatus(DatabaseExecutor db, Iterable<String> filenames,
      IdentityStatus status) async {
    generation++;
    final b = db.batch();
    for (final f in filenames) {
      b.update('song_identity', {'status': status.index},
          where: 'filename = ?', whereArgs: [f]);
    }
    await b.commit(noResult: true);
  }

  static Future<void> delete(DatabaseExecutor db, String filename) {
    generation++;
    return db
        .delete('song_identity', where: 'filename = ?', whereArgs: [filename]);
  }

  /// A file renamed through the app keeps its audio, so the new name inherits
  /// the id and the old one stays behind as an alias for stale references.
  static Future<void> markRenamed(
      DatabaseExecutor db, String from, String to) async {
    generation++;
    if (from == to) return;
    final old = await db.query('song_identity',
        where: 'filename = ?', whereArgs: [from], limit: 1);
    if (old.isEmpty) return;
    final oldRow = _row(old.first);
    final existing = await db.query('song_identity',
        where: 'filename = ?', whereArgs: [to], limit: 1);
    final sameAudio =
        existing.isNotEmpty && _row(existing.first).cid == oldRow.cid;
    if (!sameAudio) {
      await db.insert('song_identity',
          _map(IdentityRow(filename: to, cid: oldRow.cid, mtime: oldRow.mtime)),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await db.update('song_identity', {'status': IdentityStatus.alias.index},
        where: 'filename = ?', whereArgs: [from]);
  }

  /// Names learned from another device or a backup whose audio is not here.
  /// Never overwrites what this device already knows.
  static Future<void> learnOrphans(
      DatabaseExecutor db, Map<String, String> cidByFilename) async {
    generation++;
    if (cidByFilename.isEmpty) return;
    final b = db.batch();
    cidByFilename.forEach((fn, cid) {
      b.insert(
          'song_identity',
          _map(IdentityRow(
              filename: fn, cid: cid, status: IdentityStatus.orphan)),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    });
    await b.commit(noResult: true);
  }

  /// Merges the identity table of a backup into [local] as orphans, so the
  /// restored user data can be re-attached to files that were renamed since.
  static Future<void> importFrom(
      Database imported, DatabaseExecutor local) async {
    final has = await imported.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='song_identity'");
    if (has.isEmpty) return;
    final rows = await loadAll(imported);
    await learnOrphans(local, {for (final r in rows) r.filename: r.cid});
  }
}
