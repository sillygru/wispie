// SPDX-License-Identifier: GPL-3.0-only
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'debug_sandbox.dart';
import 'online_music_service.dart';

/// The ranked feed as it was last shown, with enough context to decide whether
/// it is still the right feed.
class YouTubeFeedSnapshot {
  final List<OnlineTrack> tracks;

  /// Coarse description of what produced this feed: signed-in state, library
  /// size and the artists that were seeded. A different listener or a rescanned
  /// library produces a different signature, so the cache never serves it.
  final String signature;

  final DateTime fetchedAt;

  const YouTubeFeedSnapshot({
    required this.tracks,
    required this.signature,
    required this.fetchedAt,
  });

  Duration get age => DateTime.now().difference(fetchedAt);
}

/// Disk snapshot of the last ranked feed.
///
/// Opening the tab used to mean waiting for a music home page plus one search
/// per top artist before anything appeared, every cold start. The ranked result
/// is small and changes slowly, so it is written here and painted first; the
/// refreshing happens behind it. Nothing about the taste model is folded in at
/// this layer — [YouTubeFeedSnapshot.signature] is what invalidates it.
class YouTubeFeedCache {
  YouTubeFeedCache._();

  static final YouTubeFeedCache instance = YouTubeFeedCache._();

  static const String _fileName = 'youtube_feed.json';
  static const int _version = 1;

  File? _file;
  YouTubeFeedSnapshot? _memory;

  Future<File> _target() async {
    final cached = _file;
    if (cached != null) return cached;
    final support = await getSupportDirectory();
    return _file = File(p.join(support.path, _fileName));
  }

  /// The last snapshot, or null when nothing usable was ever stored.
  Future<YouTubeFeedSnapshot?> read() async {
    final memory = _memory;
    if (memory != null) return memory;
    try {
      final file = await _target();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map || decoded['version'] != _version) return null;
      final at = (decoded['at'] as num?)?.toDouble();
      final signature = decoded['signature'];
      final rows = decoded['tracks'];
      if (at == null || signature is! String || rows is! List) return null;
      final tracks = <OnlineTrack>[];
      for (final row in rows) {
        if (row is! Map) continue;
        final id = row['id'];
        final title = row['title'];
        if (id is! String || id.isEmpty || title is! String) continue;
        final durationMs = (row['duration'] as num?)?.toInt();
        tracks.add(
          OnlineTrack(
            id: id,
            title: title,
            artist: row['artist']?.toString() ?? '',
            coverUrl: row['cover']?.toString(),
            duration:
                durationMs == null ? null : Duration(milliseconds: durationMs),
          ),
        );
      }
      if (tracks.isEmpty) return null;
      return _memory = YouTubeFeedSnapshot(
        tracks: List.unmodifiable(tracks),
        signature: signature,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch((at * 1000).round()),
      );
    } on Object catch (error) {
      debugPrint('YouTube feed cache: could not read: $error');
      return null;
    }
  }

  Future<void> write(YouTubeFeedSnapshot snapshot) async {
    _memory = snapshot;
    try {
      final file = await _target();
      await file.writeAsString(
        jsonEncode({
          'version': _version,
          'at': snapshot.fetchedAt.millisecondsSinceEpoch / 1000.0,
          'signature': snapshot.signature,
          'tracks': [
            for (final track in snapshot.tracks)
              {
                'id': track.id,
                'title': track.title,
                'artist': track.artist,
                if (track.coverUrl != null) 'cover': track.coverUrl,
                if (track.duration != null)
                  'duration': track.duration!.inMilliseconds,
              },
          ],
        }),
        flush: false,
      );
    } on Object catch (error) {
      debugPrint('YouTube feed cache: could not write: $error');
    }
  }

  /// Drops the snapshot. Used on sign-in and sign-out, where the next session
  /// must never be served the previous account's feed.
  Future<void> clear() async {
    _memory = null;
    try {
      final file = await _target();
      if (await file.exists()) await file.delete();
    } on Object catch (error) {
      debugPrint('YouTube feed cache: could not clear: $error');
    }
  }
}
