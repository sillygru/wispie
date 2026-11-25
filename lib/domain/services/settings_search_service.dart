import '../models/settings_entry.dart';

/// Prefix search over the settings registry.
///
/// Pure and generic over [SettingsEntry] subclasses so the presentation layer
/// can carry icons and screen builders on its own entry type without this
/// having to know about widgets.
class SettingsSearchService {
  const SettingsSearchService();

  static const int maxResults = 30;

  /// Every whitespace-separated token in [query] must match somewhere, so
  /// typing more words narrows rather than widens. A token matches when it is
  /// a prefix of any word in the title, subtitle, breadcrumb or keywords.
  ///
  /// Ranking, best first: a token starting the title, a token starting any
  /// later word of the title, a subtitle hit, then a keyword or breadcrumb
  /// hit. Ties keep registry order, which is the order of the settings pages
  /// themselves.
  List<T> search<T extends SettingsEntry>(List<T> entries, String query) {
    final tokens = query
        .toLowerCase()
        .split(_whitespace)
        .where(
          (token) => token.isNotEmpty,
        )
        .toList();
    if (tokens.isEmpty) return [];

    final matches = <({int index, int score})>[];
    for (final (index, entry) in entries.indexed) {
      final title = entry.title.toLowerCase();
      final titleWords = title.split(_wordBreak);
      final subtitleWords =
          (entry.subtitle ?? '').toLowerCase().split(_wordBreak);
      final breadcrumbWords = entry.breadcrumb.toLowerCase().split(_wordBreak);
      final keywords =
          entry.keywords.map((word) => word.toLowerCase()).toList();
      var score = 0;
      for (final token in tokens) {
        bool matches(Iterable<String> words) =>
            words.any((word) => word.startsWith(token));
        if (title.startsWith(token)) {
          score += 8;
        } else if (matches(titleWords)) {
          score += 6;
        } else if (matches(subtitleWords)) {
          score += 3;
        } else if (matches(keywords)) {
          score += 2;
        } else if (matches(breadcrumbWords)) {
          score++;
        } else {
          score = 0;
          break;
        }
      }
      if (score > 0) matches.add((index: index, score: score));
    }

    matches.sort((a, b) {
      final order = b.score.compareTo(a.score);
      return order == 0 ? a.index.compareTo(b.index) : order;
    });
    return [for (final match in matches.take(maxResults)) entries[match.index]];
  }

  static final _whitespace = RegExp(r'[\s\uFEFF]+');
  static final _wordBreak = RegExp(r'[^a-z0-9]+');
}
