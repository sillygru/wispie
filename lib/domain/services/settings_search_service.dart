import '../models/settings_entry.dart';
import 'native_accel.dart';

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
    final order = NativeAccel.settingsSearchOrder(
      entries: [
        for (final entry in entries)
          {
            'title': entry.title,
            'subtitle': entry.subtitle,
            'breadcrumb': entry.breadcrumb,
            'keywords': entry.keywords,
          },
      ],
      query: query,
      limit: maxResults,
    );
    return [for (final index in order) entries[index]];
  }
}
