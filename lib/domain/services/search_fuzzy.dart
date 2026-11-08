// SPDX-License-Identifier: GPL-3.0-only

import '../../models/song.dart';
import '../models/search_filter.dart';
import '../models/search_result.dart';
import 'native_accel.dart';
import 'search_taste.dart';

/// Typo-tolerant fallback matching, kept free of the index and of Flutter.
///
/// Fields are tried in rank order, so a title hit is credited over an artist
/// hit, and each row is costed by how many edits its text needs per token. The
/// scan itself runs in the native core.
List<SearchResult> fuzzyMatches(
  List<String> tokens,
  List<Song> songs,
  Set<String> exclude, {
  required SearchTaste taste,
  required bool titles,
  required bool artists,
  required bool albums,
}) {
  final hits = NativeAccel.fuzzySearch(
    tokens: tokens,
    songs: songs,
    taste: taste,
    exclude: exclude,
    titles: titles,
    artists: artists,
    albums: albums,
  );

  return [
    for (final hit in hits)
      SearchResult(
        song: songs[hit.index],
        matchedFilters: {SearchFilterType.values.byName(hit.field)},
      ),
  ];
}
