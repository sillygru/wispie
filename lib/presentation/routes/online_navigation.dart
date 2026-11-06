// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/online_music_service.dart';
import 'app_page_route.dart';
import '../screens/youtube_artist_screen.dart';
import '../screens/youtube_collection_screen.dart';

/// Opens catalogue pages from a name, for the surfaces that only hold a track's
/// tags. Successful resolutions are cached; a miss is retried next time.
final Map<String, OnlineCollection> _artistCache = {};
final Map<String, OnlineCollection> _albumCache = {};

const Duration _searchBudget = Duration(seconds: 8);

String _loose(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

OnlineCollection? _pick(List<OnlineCollection> rows, String name) {
  final target = _loose(name);
  if (target.isEmpty) return null;
  for (final row in rows) {
    if (_loose(row.title) == target) return row;
  }
  for (final row in rows) {
    final title = _loose(row.title);
    if (title.isEmpty) continue;
    if (title.startsWith(target) || target.startsWith(title)) return row;
  }
  return rows.length == 1 ? rows.first : null;
}

Future<List<OnlineCollection>> _search(
  String query,
  OnlineCollectionKind kind,
) async {
  try {
    final results = await OnlineMusicService.instance
        .searchAll(query, limit: 10)
        .timeout(_searchBudget);
    return switch (kind) {
      OnlineCollectionKind.artist => results.artists,
      OnlineCollectionKind.album => results.albums,
      OnlineCollectionKind.playlist => results.playlists,
    };
  } on Object {
    return const [];
  }
}

/// Opens the artist's YouTube page; false when the catalogue has no match.
Future<bool> openOnlineArtistByName(
  BuildContext context,
  String artistName,
) async {
  final name = artistName.trim();
  if (name.isEmpty) return false;

  final key = name.toLowerCase();
  var artist = _artistCache[key];
  if (artist == null) {
    artist = _pick(
      await _search(name, OnlineCollectionKind.artist),
      name,
    );
    if (artist == null) return false;
    _artistCache[key] = artist;
  }

  if (!context.mounted) return false;
  final target = artist;
  context.pushApp(
    YouTubeArtistScreen(
      id: target.id,
      name: target.title.isEmpty ? name : target.title,
      coverUrl: target.coverUrl,
    ),
  );
  return true;
}

/// Opens the album's YouTube page; false when the catalogue has no match.
Future<bool> openOnlineAlbumByName(
  BuildContext context,
  String albumName, {
  String? artistName,
}) async {
  final name = albumName.trim();
  if (name.isEmpty) return false;

  final key = name.toLowerCase();
  var album = _albumCache[key];
  if (album == null) {
    final artist = artistName?.trim() ?? '';
    final query = artist.isEmpty ? name : '$artist $name';
    album = _pick(
      await _search(query, OnlineCollectionKind.album),
      name,
    );
    if (album == null) return false;
    _albumCache[key] = album;
  }

  if (!context.mounted) return false;
  final target = album;
  context.pushApp(
    YouTubeCollectionScreen(
      kind: OnlineCollectionKind.album,
      id: target.id,
      title: target.title.isEmpty ? name : target.title,
      subtitle: target.subtitle,
      coverUrl: target.coverUrl,
    ),
  );
  return true;
}
