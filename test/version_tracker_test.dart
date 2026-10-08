import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wispie/domain/services/version_tracker.dart';

void main() {
  test('compare handles numeric order and suffixes', () {
    expect(VersionTracker.compare('1.4.4', '1.4.4+9'), 0);
    expect(VersionTracker.compare('1.4.10', '1.4.9'), 1);
    expect(VersionTracker.compare('1.4', '1.4.1'), -1);
  });

  test('classify', () {
    expect(VersionTracker.classify(null, '1.0.0').kind,
        VersionChangeKind.firstRun);
    expect(
        VersionTracker.classify('1.0.0', '1.0.0').kind, VersionChangeKind.same);
    expect(VersionTracker.classify('1.0.0', '1.1.0').kind,
        VersionChangeKind.upgraded);
    expect(VersionTracker.classify('1.1.0', '1.0.0').kind,
        VersionChangeKind.downgraded);
  });

  test('evaluate records on upgrade but not on downgrade', () async {
    SharedPreferences.setMockInitialValues({'last_opened_version': '1.0.0'});
    final prefs = await SharedPreferences.getInstance();
    final up = await VersionTracker.evaluate(prefs, '1.1.0');
    expect(up.isUpgrade, isTrue);
    expect(up.previous, '1.0.0');
    expect(prefs.getString(VersionTracker.lastOpenedVersionKey), '1.1.0');

    final down = await VersionTracker.evaluate(prefs, '1.0.0');
    expect(down.kind, VersionChangeKind.downgraded);
    expect(prefs.getString(VersionTracker.lastOpenedVersionKey), '1.1.0');

    await VersionTracker.acceptCurrent(prefs, '1.0.0');
    expect(prefs.getString(VersionTracker.lastOpenedVersionKey), '1.0.0');
  });
}
