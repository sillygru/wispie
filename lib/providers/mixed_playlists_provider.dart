import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/recommendation_config.dart';
import 'providers.dart';
import 'settings_provider.dart';

final mixedPlaylistsProvider = Provider<List<Playlist>>((ref) {
  final userData = ref.watch(userDataProvider);
  final songsAsync = ref.watch(songsProvider);
  final recConfig = ref.watch(settingsProvider).recommendationConfig;

  if (songsAsync is! AsyncData ||
      songsAsync.value == null ||
      songsAsync.value!.isEmpty) {
    return [];
  }

  final allSongs = songsAsync.value!;

  final recommendationPlaylists = userData.playlists
      .where((p) => p.isRecommendation && p.id != 'quick_picks')
      .toList();

  final result = <Playlist>[];

  for (final pl in recommendationPlaylists) {
    if (userData.removedRecommendations.contains(pl.id)) continue;

    final recType = RecommendationConfig.idToType(pl.id);
    if (recType != null && !recConfig.isEnabled(recType)) continue;

    final playlistSongs = <Song>[];
    for (final ps in pl.songs) {
      final song =
          allSongs.where((s) => s.filename == ps.songFilename).firstOrNull;
      if (song != null) playlistSongs.add(song);
    }

    if (playlistSongs.isNotEmpty) {
      result.add(pl);
    }
  }

  result.sort((a, b) {
    final aPinned = userData.recommendationPreferences[a.id]?.isPinned ?? false;
    final bPinned = userData.recommendationPreferences[b.id]?.isPinned ?? false;
    if (aPinned && !bPinned) return -1;
    if (!aPinned && bPinned) return 1;

    final aType = RecommendationConfig.idToType(a.id);
    final bType = RecommendationConfig.idToType(b.id);
    final aPriority = aType != null ? recConfig.priority(aType) : 1;
    final bPriority = bType != null ? recConfig.priority(bType) : 1;
    return bPriority.compareTo(aPriority);
  });

  return result;
});
