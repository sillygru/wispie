import 'youtube_library.dart';

/// A catalogue row as the core reads and writes it.
Map<String, Object?> youtubeItemToWire(YouTubePlaylistItem item) => {
      'video_id': item.videoId,
      'title': item.title,
      'artist': item.artist,
      'duration_ms': item.duration?.inMilliseconds,
      'thumbnail_url': item.thumbnailUrl,
      'position': item.position,
      'view_count_text': item.viewCountText,
    };

YouTubePlaylistItem youtubeItemFromWire(Map<String, dynamic> row) {
  final millis = (row['duration_ms'] as num?)?.toInt();
  return YouTubePlaylistItem(
    videoId: row['video_id'] as String? ?? '',
    title: row['title'] as String? ?? '',
    artist: row['artist'] as String? ?? '',
    duration: millis == null ? null : Duration(milliseconds: millis),
    thumbnailUrl: row['thumbnail_url'] as String?,
    position: (row['position'] as num?)?.toInt() ?? 0,
    viewCountText: row['view_count_text'] as String?,
  );
}
