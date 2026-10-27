// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/foundation.dart';

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

  const OnlineTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.coverUrl,
    this.duration,
  });

  Song toSong() => Song.youtube(
        videoId: id,
        title: title,
        artist: artist,
        coverUrl: coverUrl,
        duration: duration,
      );
}

/// The app's only online catalogue.
///
/// Search asks YouTube Music first: its answers are songs and music videos,
/// while a www.youtube.com search happily returns trailers, interviews and
/// reaction videos for the same words. The www search stays as a fallback so a
/// query the music catalogue has nothing for still returns something.
class OnlineMusicService {
  OnlineMusicService._();

  static final OnlineMusicService instance = OnlineMusicService._();

  Future<List<OnlineTrack>> search(String query, {int limit = 25}) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    final music = await _musicSearch(normalized, limit);
    if (music.isNotEmpty) return music;

    final videos =
        await YouTubeService.instance.search(normalized, limit: limit);
    return List<OnlineTrack>.unmodifiable(videos.map(_fromVideo));
  }

  Future<List<OnlineTrack>> _musicSearch(String query, int limit) async {
    try {
      final items = await YouTubeAccountService.instance
          .libraryApi()
          .musicSearch(query, maxPages: limit > 15 ? 2 : 1);
      return List<OnlineTrack>.unmodifiable(
        items.take(limit).map(
              (item) => OnlineTrack(
                id: item.videoId,
                title: item.title,
                artist: item.artist,
                coverUrl: item.thumbnailUrl,
                duration: item.duration,
              ),
            ),
      );
    } on Object catch (error) {
      debugPrint('YouTube: music search failed, falling back to www: $error');
      return const [];
    }
  }

  static OnlineTrack _fromVideo(YouTubeVideo video) => OnlineTrack(
        id: video.id,
        title: video.title,
        artist: video.artist,
        coverUrl: video.thumbnailUrl,
        duration: video.duration,
      );
}
