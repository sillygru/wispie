// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/foundation.dart';

import '../models/song.dart';
import 'audius_service.dart';
import 'youtube_service.dart';

enum OnlineProvider { youtube, audius }

/// A catalogue result from either provider, shaped so the YouTube screen does
/// not need to know which one answered.
class OnlineTrack {
  final OnlineProvider provider;
  final String id;
  final String title;
  final String artist;
  final String? coverUrl;
  final Duration? duration;

  const OnlineTrack({
    required this.provider,
    required this.id,
    required this.title,
    required this.artist,
    this.coverUrl,
    this.duration,
  });

  Song toSong() {
    switch (provider) {
      case OnlineProvider.youtube:
        return Song.youtube(
          videoId: id,
          title: title,
          artist: artist,
          coverUrl: coverUrl,
          duration: duration,
        );
      case OnlineProvider.audius:
        return Song.audius(
          trackId: id,
          title: title,
          artist: artist,
          coverUrl: coverUrl,
          duration: duration,
        );
    }
  }
}

class OnlineSearchOutcome {
  final List<OnlineTrack> tracks;

  /// True when YouTube could not answer and the list came from Audius.
  final bool usedAudiusFallback;
  final Object? youtubeError;

  const OnlineSearchOutcome({
    required this.tracks,
    this.usedAudiusFallback = false,
    this.youtubeError,
  });
}

/// One entry point for online catalogue access: YouTube first, Audius as the
/// fallback for both the search list and an individual track that refuses to
/// stream.
class OnlineMusicService {
  OnlineMusicService._();

  static final OnlineMusicService instance = OnlineMusicService._();

  static const int _maxFallbackEntries = 200;

  final Map<String, Uri?> _fallbackAudio = {};
  final Map<String, Future<Uri?>> _fallbackInFlight = {};

  Future<OnlineSearchOutcome> search(String query, {int limit = 25}) async {
    try {
      final videos = await YouTubeService.instance.search(query, limit: limit);
      return OnlineSearchOutcome(
        tracks: List<OnlineTrack>.unmodifiable(videos.map(_fromYouTube)),
      );
    } on Object catch (youtubeError) {
      debugPrint('OnlineMusicService: YouTube search failed: $youtubeError');
      final tracks = await AudiusService.instance.searchTracks(
        query,
        limit: limit,
      );
      return OnlineSearchOutcome(
        tracks: List<OnlineTrack>.unmodifiable(tracks.map(_fromAudius)),
        usedAudiusFallback: true,
        youtubeError: youtubeError,
      );
    }
  }

  /// Audius replacement for a YouTube video that will not resolve. Results are
  /// memoised, including failures, so a skipped queue cannot turn into a burst
  /// of searches for the same blocked video.
  Future<Uri?> fallbackAudioUri({
    required String videoId,
    required String title,
    required String artist,
  }) {
    if (_fallbackAudio.containsKey(videoId)) {
      return Future.value(_fallbackAudio[videoId]);
    }
    final existing = _fallbackInFlight[videoId];
    if (existing != null) return existing;

    final pending = _searchAudius(title, artist).then((uri) {
      if (_fallbackAudio.length > _maxFallbackEntries) _fallbackAudio.clear();
      _fallbackAudio[videoId] = uri;
      return uri;
    }).whenComplete(() => _fallbackInFlight.remove(videoId));
    _fallbackInFlight[videoId] = pending;
    return pending;
  }

  Future<Uri?> _searchAudius(String title, String artist) async {
    final query = '$title $artist'.trim();
    if (query.isEmpty) return null;
    final tracks = await AudiusService.instance.searchTracks(query, limit: 8);
    for (final track in tracks) {
      if (!track.isStreamable) continue;
      final uri = await AudiusService.instance.getStreamUrl(track.id);
      if (uri != null) return uri;
    }
    return null;
  }

  static OnlineTrack _fromYouTube(YouTubeVideo video) => OnlineTrack(
        provider: OnlineProvider.youtube,
        id: video.id,
        title: video.title,
        artist: video.artist,
        coverUrl: video.thumbnailUrl,
        duration: video.duration,
      );

  static OnlineTrack _fromAudius(AudiusTrack track) => OnlineTrack(
        provider: OnlineProvider.audius,
        id: track.id,
        title: track.title,
        artist: track.artist,
        coverUrl: track.artworkUrl,
        duration: track.duration,
      );
}
