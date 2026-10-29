// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/foundation.dart';

import '../domain/services/youtube_library.dart';
import '../models/song.dart';
import 'youtube_account_service.dart';
import 'youtube_service.dart';

/// A YouTube search hit, shaped so screens do not depend on the wire model.
class OnlineTrack {
  final String id;
  final String title;
  final String artist;
  final String? coverUrl;
  final Duration? duration;

  /// `36M plays` as the catalogue prints it, or null when the row has none.
  final String? viewCountText;

  const OnlineTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.coverUrl,
    this.duration,
    this.viewCountText,
  });

  Song toSong() => Song.youtube(
        videoId: id,
        title: title,
        artist: artist,
        coverUrl: coverUrl,
        duration: duration,
      );
}

/// What a catalogue row opens instead of playing.
enum OnlineCollectionKind { album, playlist, artist }

/// An album, playlist or artist row from a search or from another page.
class OnlineCollection {
  final String id;
  final String title;

  /// The catalogue's own byline, e.g. `Album • 2021`.
  final String subtitle;
  final String? coverUrl;
  final OnlineCollectionKind kind;

  const OnlineCollection({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.coverUrl,
    required this.kind,
  });
}

/// One sort chip as YouTube labels it, plus the token that asks for it.
class OnlineSort {
  final String label;
  final String params;

  const OnlineSort({required this.label, this.params = ''});
}

/// A whole search page: tracks first, then the places the query named.
class OnlineSearchResults {
  final List<OnlineTrack> tracks;
  final List<OnlineCollection> albums;
  final List<OnlineCollection> playlists;
  final List<OnlineCollection> artists;

  const OnlineSearchResults({
    this.tracks = const [],
    this.albums = const [],
    this.playlists = const [],
    this.artists = const [],
  });

  static const OnlineSearchResults empty = OnlineSearchResults();

  bool get isEmpty =>
      tracks.isEmpty && albums.isEmpty && playlists.isEmpty && artists.isEmpty;
}

/// An artist page: their songs in YouTube's ranking, plus albums and sorts.
class OnlineArtist {
  final String id;
  final String name;
  final String? coverUrl;
  final List<OnlineTrack> tracks;
  final List<OnlineCollection> albums;
  final List<OnlineSort> sorts;

  const OnlineArtist({
    required this.id,
    required this.name,
    this.coverUrl,
    this.tracks = const [],
    this.albums = const [],
    this.sorts = const [],
  });
}

/// A set of tracks that belongs to one place: an album or a playlist.
class OnlineCollectionTracks {
  final String title;
  final String artist;
  final String? coverUrl;
  final List<OnlineTrack> tracks;

  const OnlineCollectionTracks({
    required this.title,
    this.artist = '',
    this.coverUrl,
    this.tracks = const [],
  });
}

/// The app's only online catalogue.
///
/// Search asks YouTube Music first: its answers are songs and music videos,
/// while a www.youtube.com search happily returns trailers, interviews and
/// reaction videos for the same words. The www search stays as a fallback so a
/// query the music catalogue has nothing for still returns something.
///
/// The music catalogue also answers with albums, playlists and artists, which is
/// what makes it possible to search for an album name and land on the album
/// rather than on one of its songs.
class OnlineMusicService {
  OnlineMusicService._();

  static final OnlineMusicService instance = OnlineMusicService._();

  Future<List<OnlineTrack>> search(String query, {int limit = 25}) async {
    final page = await searchAll(query, limit: limit);
    return page.tracks;
  }

  /// Tracks plus the albums, playlists and artists the same query named.
  Future<OnlineSearchResults> searchAll(
    String query, {
    int limit = 25,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return OnlineSearchResults.empty;

    final page = await _musicSearch(normalized, limit);
    if (!page.isEmpty) return page;

    final videos =
        await YouTubeService.instance.search(normalized, limit: limit);
    return OnlineSearchResults(
      tracks: List<OnlineTrack>.unmodifiable(videos.map(_fromVideo)),
    );
  }

  Future<OnlineSearchResults> _musicSearch(String query, int limit) async {
    try {
      final page = await YouTubeAccountService.instance
          .libraryApi()
          .musicSearchAll(query, maxPages: limit > 15 ? 2 : 1);
      return OnlineSearchResults(
        tracks: List<OnlineTrack>.unmodifiable(
          page.tracks.take(limit).map(_fromItem),
        ),
        albums: _collections(page.albums),
        playlists: _collections(page.playlists),
        artists: _collections(page.artists),
      );
    } on Object catch (error) {
      debugPrint('YouTube: music search failed, falling back to www: $error');
      return OnlineSearchResults.empty;
    }
  }

  /// The tracks of an album, in album order.
  Future<OnlineCollectionTracks> album(String browseId) async {
    final page =
        await YouTubeAccountService.instance.libraryApi().album(browseId);
    return OnlineCollectionTracks(
      title: page.title,
      artist: page.artist,
      coverUrl: page.thumbnailUrl,
      tracks: List<OnlineTrack>.unmodifiable(page.tracks.map(_fromItem)),
    );
  }

  /// The tracks of a playlist, in playlist order.
  Future<OnlineCollectionTracks> playlist(String playlistId) async {
    final items = await YouTubeAccountService.instance
        .libraryApi()
        .playlistItems(playlistId);
    return OnlineCollectionTracks(
      title: '',
      tracks: List<OnlineTrack>.unmodifiable(items.map(_fromItem)),
    );
  }

  /// An artist page, ranked by YouTube itself.
  ///
  /// [params] is one of the page's own sort chips: sending it back is how the
  /// app offers the same orders the website does instead of inventing one from
  /// byline years.
  Future<OnlineArtist> artist(String browseId, {String? params}) async {
    final page = await YouTubeAccountService.instance
        .libraryApi()
        .artist(browseId, params: params);
    return OnlineArtist(
      id: page.id,
      name: page.name,
      coverUrl: page.thumbnailUrl,
      tracks: List<OnlineTrack>.unmodifiable(page.songs.map(_fromItem)),
      albums: _collections(page.albums),
      sorts: List<OnlineSort>.unmodifiable(
        page.sorts
            .map((sort) => OnlineSort(label: sort.label, params: sort.params)),
      ),
    );
  }

  static OnlineTrack _fromItem(YouTubePlaylistItem item) => OnlineTrack(
        id: item.videoId,
        title: item.title,
        artist: item.artist,
        coverUrl: item.thumbnailUrl,
        duration: item.duration,
        viewCountText: item.viewCountText,
      );

  static OnlineTrack _fromVideo(YouTubeVideo video) => OnlineTrack(
        id: video.id,
        title: video.title,
        artist: video.artist,
        coverUrl: video.thumbnailUrl,
        duration: video.duration,
      );

  static List<OnlineCollection> _collections(List<YouTubeContainer> items) =>
      List<OnlineCollection>.unmodifiable(
        items.map(
          (item) => OnlineCollection(
            id: item.id,
            title: item.title,
            subtitle: item.subtitle,
            coverUrl: item.thumbnailUrl,
            kind: switch (item.kind) {
              YouTubeContainerKind.album => OnlineCollectionKind.album,
              YouTubeContainerKind.playlist => OnlineCollectionKind.playlist,
              YouTubeContainerKind.artist => OnlineCollectionKind.artist,
            },
          ),
        ),
      );
}
