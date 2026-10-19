import 'dart:convert';

/// Where each sync entity names a song, so payloads can be annotated with
/// content ids on the way out and have names rewritten to the local filename
/// on the way in.
const Map<String, String> _nameField = {
  'favorites': 'filename',
  'suggestless': 'filename',
  'hidden': 'filename',
  'merged_songs': 'filename',
  'merged_groups': 'priority_filename',
  'playlist_songs': 'song_filename',
  'play_events': 'song_filename',
};

/// Index of the filename inside a tombstone key (parts joined by NUL).
const Map<String, int> _tombstoneNamePart = {
  'favorites': 0,
  'suggestless': 0,
  'hidden': 0,
  'merged_songs': 0,
  'playlist_songs': 1,
};

const String _sep = '\u0000';

/// Returns the new filename, or null to drop the record.
typedef NameMapper = String? Function(String filename);

List<String> _queueNames(Object? raw) {
  if (raw is! String) return const [];
  try {
    final list = jsonDecode(raw);
    if (list is List) return [for (final e in list) '$e'];
  } catch (_) {}
  return const [];
}

Set<String> collectSongNames(Map records) {
  final names = <String>{};
  _nameField.forEach((array, field) {
    final list = records[array];
    if (list is! List) return;
    for (final r in list) {
      if (r is Map && r[field] is String && (r[field] as String).isNotEmpty) {
        names.add(r[field] as String);
      }
    }
  });
  final snaps = records['queue_snapshots'];
  if (snaps is List) {
    for (final r in snaps) {
      if (r is Map) names.addAll(_queueNames(r['songs_json']));
    }
  }
  final tombs = records['tombstones'];
  if (tombs is List) {
    for (final t in tombs) {
      if (t is! Map) continue;
      final part = _tombstoneNamePart['${t['entity']}'];
      if (part == null) continue;
      final parts = '${t['key']}'.split(_sep);
      if (part < parts.length && parts[part].isNotEmpty) names.add(parts[part]);
    }
  }
  return names;
}

Map<String, dynamic> remapSongNames(Map records, NameMapper map) {
  final out = <String, dynamic>{};
  records.forEach((rawKey, value) {
    final array = '$rawKey';
    if (value is! List) {
      out[array] = value;
      return;
    }
    final field = _nameField[array];
    if (field != null) {
      final kept = <Object?>[];
      for (final r in value) {
        if (r is! Map || r[field] is! String) {
          kept.add(r);
          continue;
        }
        final mapped = map(r[field] as String);
        if (mapped == null) {
          // A priority name with no local match stays as-is; the group itself
          // is still valid.
          if (array == 'merged_groups') kept.add(r);
          continue;
        }
        kept.add({...r, field: mapped});
      }
      out[array] = kept;
    } else if (array == 'queue_snapshots') {
      out[array] = [
        for (final r in value)
          if (r is Map && r['songs_json'] is String)
            {
              ...r,
              'songs_json': jsonEncode([
                for (final n in _queueNames(r['songs_json']))
                  if (map(n) case final m?) m
              ]),
            }
          else
            r
      ];
    } else if (array == 'tombstones') {
      final kept = <Object?>[];
      for (final t in value) {
        final part = t is Map ? _tombstoneNamePart['${t['entity']}'] : null;
        if (part == null) {
          kept.add(t);
          continue;
        }
        final parts = '${(t as Map)['key']}'.split(_sep);
        if (part >= parts.length) {
          kept.add(t);
          continue;
        }
        final mapped = map(parts[part]);
        if (mapped == null) continue;
        parts[part] = mapped;
        kept.add({...t, 'key': parts.join(_sep)});
      }
      out[array] = kept;
    } else {
      out[array] = value;
    }
  });
  return out;
}
