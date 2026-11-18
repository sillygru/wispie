import 'package:shared_preferences/shared_preferences.dart';

import '../../data/rust/wispie_core.dart';

enum VersionChangeKind { firstRun, same, upgraded, downgraded }

/// What happened between the previous launch and this one. [previous] is null
/// on the first run (or when upgrading from a build that never recorded one).
class VersionChange {
  final VersionChangeKind kind;
  final String? previous;
  final String current;

  const VersionChange(this.kind, this.previous, this.current);

  /// Hook for a "what's new" screen: true when the app was just updated.
  bool get isUpgrade => kind == VersionChangeKind.upgraded;
}

/// Compares launches and records the version.
///
/// The comparison and classification live in the native core; the preferences
/// store stays here because it is the platform key-value store.
class VersionTracker {
  static const String lastOpenedVersionKey = 'last_opened_version';

  /// Compares dotted versions numerically; ignores `+build` and `-pre` suffixes.
  static int compare(String a, String b) => (WispieCore.helper({
        'action': 'version_compare',
        'a': a,
        'b': b,
      })['value'] as num)
          .toInt();

  static VersionChange classify(String? previous, String current) {
    final stored = (previous == null || previous.isEmpty) ? null : previous;
    final reply = WispieCore.helper({
      'action': 'version_classify',
      'previous': stored,
      'current': current,
    });
    final kind = switch (reply['kind']) {
      'same' => VersionChangeKind.same,
      'upgraded' => VersionChangeKind.upgraded,
      'downgraded' => VersionChangeKind.downgraded,
      _ => VersionChangeKind.firstRun,
    };
    return VersionChange(kind, stored, current);
  }

  /// Classifies this launch and records the version, except on a downgrade:
  /// that waits for the user to accept the risk via [acceptCurrent].
  static Future<VersionChange> evaluate(
    SharedPreferences prefs,
    String current,
  ) async {
    final change = classify(prefs.getString(lastOpenedVersionKey), current);
    if (change.kind != VersionChangeKind.downgraded &&
        change.kind != VersionChangeKind.same) {
      await prefs.setString(lastOpenedVersionKey, current);
    }
    return change;
  }

  static Future<void> acceptCurrent(
    SharedPreferences prefs,
    String current,
  ) =>
      prefs.setString(lastOpenedVersionKey, current);
}
