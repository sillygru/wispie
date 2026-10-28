import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/search_filter.dart';
import '../domain/models/search_result.dart';
import '../domain/services/search_service.dart';
import '../domain/services/search_taste.dart';
import '../domain/services/song_affinity.dart';
import '../domain/services/taste_model.dart';
import 'providers.dart';

/// Provider for the search service
final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService();
});

/// Provider for the search filter state using Notifier
final searchFilterProvider =
    NotifierProvider<SearchFilterNotifier, SearchFilterState>(() {
  return SearchFilterNotifier();
});

/// Notifier for managing search filter state
class SearchFilterNotifier extends Notifier<SearchFilterState> {
  @override
  SearchFilterState build() {
    return const SearchFilterState(all: true);
  }

  /// Toggles a filter type
  void toggleFilter(SearchFilterType type) {
    state = state.toggleFilter(type);
  }

  /// Selects a specific filter
  void selectFilter(SearchFilterType type) {
    state = state.selectFilter(type);
  }

  /// Deselects a specific filter
  void deselectFilter(SearchFilterType type) {
    state = state.deselectFilter(type);
  }

  /// Resets to default (All)
  void reset() {
    state = const SearchFilterState(all: true);
  }
}

/// Listening history in the shape the search ranker consumes.
///
/// Both channels already exist for shuffle and the library's Recommended sort,
/// so search adds two map lookups per comparison rather than a second model.
/// This provider is rebuilt per history change, never per keystroke: the artist
/// channel carries the smart model's recency weighting, so an artist this device
/// still plays leads, and one it played heavily months ago does not.
final searchTasteProvider = FutureProvider<SearchTaste>((ref) async {
  Map<String, SongAffinity> affinities = const {};
  try {
    affinities = await ref.watch(songAffinitiesProvider.future);
  } on Object catch (_) {
    // A missing affinity map means unranked by taste, not a broken search.
  }

  TasteSnapshot? snapshot;
  try {
    snapshot = await ref.watch(tasteSnapshotProvider.future);
  } on Object catch (_) {
    snapshot = null;
  }

  final songs = <String, double>{
    for (final entry in affinities.entries) entry.key: entry.value.affinity,
  };

  final rawArtists = <String, double>{};
  if (snapshot != null) {
    for (final entry in snapshot.artists.entries) {
      // Trend leads; the long run is a mild tailwind, so months-old listening
      // cannot outrank this month's.
      final mass = entry.value.trendMass + entry.value.longMass * 0.3;
      if (mass > 0) rawArtists[entry.key] = mass;
    }
  }
  if (rawArtists.isEmpty) return SearchTaste(songs: songs);

  final strongest = rawArtists.values.reduce(math.max);
  return SearchTaste(
    songs: songs,
    artists: {
      for (final entry in rawArtists.entries)
        entry.key: entry.value / strongest,
    },
  );
});

/// Provider for search results
final searchResultsProvider =
    FutureProvider.family<List<SearchResult>, String>((ref, query) async {
  final filterState = ref.watch(searchFilterProvider);

  if (query.isEmpty) {
    return const [];
  }

  final local = await ref.watch(songsProvider.future);
  final userData = ref.watch(userDataProvider);

  // A streamed track counts as a library row once it is saved, so its title,
  // artist and the lyrics the player cached for it are searchable too.
  final remote = [
    for (final song in userData.remoteSongs.values)
      if (userData.isInRemoteLibrary(song.filename)) song,
  ];

  final searchService = ref.read(searchServiceProvider);
  await searchService.syncRemoteLibrary(remote);
  final taste = await ref.watch(searchTasteProvider.future);

  return searchService.search(
    query: query,
    filterState: filterState,
    allSongs: [...local, ...remote],
    taste: taste,
  );
});
