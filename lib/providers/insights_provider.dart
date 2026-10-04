import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/insights_repository.dart';
import '../domain/models/listening_insights.dart';
import '../domain/services/insights_builder.dart';
import 'providers.dart';

/// Which window the stats screen is showing.
///
/// UI state, not persisted state — it lives for as long as the screen does and
/// defaults to a month, which is the window that answers "how have I been
/// listening lately" without drowning in a decade of history.
class StatsRangeNotifier extends Notifier<StatsRange> {
  @override
  StatsRange build() => StatsRange.month;

  void select(StatsRange range) {
    if (range == state) return;
    state = range;
  }
}

final statsRangeProvider =
    NotifierProvider<StatsRangeNotifier, StatsRange>(StatsRangeNotifier.new);

final insightsRepositoryProvider = Provider<InsightsRepository>(
  (_) => InsightsRepository(),
);

/// The whole stats screen's data, folded for the selected range.
///
/// Watching [statsRangeProvider] here rather than in the screen is what makes
/// switching ranges recompute instead of showing the previous window's
/// numbers under the new chip.
final listeningInsightsProvider =
    FutureProvider<ListeningInsights>((ref) async {
  final range = ref.watch(statsRangeProvider);
  final library = await ref.watch(songsProvider.future);
  final favorites = ref.watch(userDataProvider.select((s) => s.favorites));
  final repository = ref.watch(insightsRepositoryProvider);

  final events = await repository.loadPlayEvents();
  return buildInsights(
    events: events,
    library: {for (final song in library) song.filename: song},
    favorites: favorites.toSet(),
    range: range,
    now: DateTime.now(),
  );
});
