// SPDX-License-Identifier: GPL-3.0-only
import '../models/song.dart';
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
class OnlineMusicService {
  OnlineMusicService._();

  static final OnlineMusicService instance = OnlineMusicService._();

  Future<List<OnlineTrack>> search(String query, {int limit = 25}) async {
    final videos = await YouTubeService.instance.search(query, limit: limit);
    return List<OnlineTrack>.unmodifiable(videos.map(_fromVideo));
  }

  static OnlineTrack _fromVideo(YouTubeVideo video) => OnlineTrack(
        id: video.id,
        title: video.title,
        artist: video.artist,
        coverUrl: video.thumbnailUrl,
        duration: video.duration,
      );
}
