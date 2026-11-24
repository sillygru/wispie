import '../rust/native_database.dart';

import '../../domain/services/song_identity.dart';

/// Converts identity rows at the native database boundary.
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

  static double _now() => DateTime.now().millisecondsSinceEpoch / 1000;

  static Future<List<IdentityRow>> loadAll(Database db) async {
    final result = await db.coreCommand('identity', {'op': 'list'});
    return (result['rows'] as List)
        .cast<Map<String, Object?>>()
        .map(_row)
        .toList();
  }

  static Future<void> upsertAll(Database db, Iterable<IdentityRow> rows) async {
    await db.coreCommand('identity', {
      'op': 'upsert',
      'now': _now(),
      'rows': [
        for (final row in rows)
          {
            'filename': row.filename,
            'cid': row.cid,
            'mtime': row.mtime,
            'status': row.status.index,
          },
      ],
    });
    generation++;
  }

  static Future<void> setStatus(
      Database db, Iterable<String> filenames, IdentityStatus status) async {
    await db.coreCommand('identity', {
      'op': 'status',
      'filenames': filenames.toList(),
      'status': status.index,
    });
    generation++;
  }

  /// Learns remote names without overwriting identities already on this device.
  static Future<void> learnOrphans(
      Database db, Map<String, String> cidByFilename) async {
    if (cidByFilename.isEmpty) return;
    await db.coreCommand('identity', {
      'op': 'learn',
      'now': _now(),
      'rows': [
        for (final entry in cidByFilename.entries)
          {'filename': entry.key, 'cid': entry.value},
      ],
    });
    generation++;
  }
}
