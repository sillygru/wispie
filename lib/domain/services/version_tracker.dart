import 'package:shared_preferences/shared_preferences.dart';

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

class VersionTracker {
  static const String lastOpenedVersionKey = 'last_opened_version';

  /// Compares dotted versions numerically; ignores `+build` and `-pre` suffixes.
  static int compare(String a, String b) {
    List<int> parse(String v) => v
        .split(RegExp(r'[+-]'))
        .first
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList();
    final pa = parse(a);
    final pb = parse(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x < y ? -1 : 1;
    }
    return 0;
  }

  static VersionChange classify(String? previous, String current) {
    if (previous == null || previous.isEmpty) {
      return VersionChange(VersionChangeKind.firstRun, null, current);
    }
    final c = compare(previous, current);
    final kind = c == 0
        ? VersionChangeKind.same
        : c < 0
            ? VersionChangeKind.upgraded
            : VersionChangeKind.downgraded;
    return VersionChange(kind, previous, current);
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
