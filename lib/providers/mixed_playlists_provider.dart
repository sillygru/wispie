import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/playlist.dart';
import 'providers.dart';

/// The recommendation mixes shown on Home, with pinned ones first.
///
/// Membership is decided against the merged library map, so a mix built from
/// streamed tracks survives the trip to the UI: a listener whose music is
/// mostly imported YouTube playlists used to lose every mix here.
final mixedPlaylistsProvider = Provider<List<Playlist>>((ref) {
  final userData = ref.watch(userDataProvider);
  final byFilename = ref.watch(songsByFilenameProvider);

  final result = <Playlist>[];
  for (final playlist in userData.playlists) {
    if (!playlist.isRecommendation || playlist.id == 'quick_picks') continue;
    if (userData.removedRecommendations.contains(playlist.id)) continue;
    final resolves =
        playlist.songs.any((song) => byFilename.containsKey(song.songFilename));
    if (!resolves) continue;
    result.add(playlist);
  }

  // Pinned mixes lead.
  result.sort((a, b) {
    final aPinned = userData.recommendationPreferences[a.id]?.isPinned ?? false;
    final bPinned = userData.recommendationPreferences[b.id]?.isPinned ?? false;
    if (aPinned == bPinned) return 0;
    return aPinned ? -1 : 1;
  });

  return result;
});
