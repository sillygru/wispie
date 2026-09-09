import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/services/passive_art_fetcher_service.dart';

import 'test_helpers.dart';

/// Regression tests for the false "went offline" report on manual fetches.
///
/// The breaker used to declare the device offline after 10 consecutive
/// transient failures (5xx/429/bad JSON/dead CDN all counted) and a 5-minute
/// backoff then made every retry report offline without touching the
/// network. Now only a socket probe to the API host may declare offline.
void main() {
  late TestEnvironment testEnv;
  final fetcher = PassiveArtFetcherService.instance;

  setUpAll(() {
    testEnv = TestEnvironment();
    testEnv.setUp();
  });

  tearDownAll(() {
    testEnv.tearDown();
  });

  setUp(() async {
    fetcher.probeOverrideForTest = null;
    await fetcher.clearAttempted();
  });

  tearDown(() {
    fetcher.probeOverrideForTest = null;
  });

  test('clearAttempted lifts an active offline backoff', () async {
    fetcher.setOfflineBackoffForTest(
      DateTime.now().add(const Duration(minutes: 5)),
    );
    expect(fetcher.isBackingOffForTest, isTrue);

    await fetcher.clearAttempted();

    expect(fetcher.isBackingOffForTest, isFalse);
  });

  test('probe override reporting reachable means online', () async {
    fetcher.probeOverrideForTest = () async => true;

    expect(await fetcher.isApiReachableForTest(), isTrue);
    expect(await fetcher.confirmApiReachableForTest(), isTrue);
  });

  test('probe override reporting unreachable means offline', () async {
    fetcher.probeOverrideForTest = () async => false;

    expect(await fetcher.isApiReachableForTest(), isFalse);
    expect(await fetcher.confirmApiReachableForTest(), isFalse);
  });

  test('concurrent breaker trips share a single probe', () async {
    var probeCalls = 0;
    fetcher.probeOverrideForTest = () async {
      probeCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return true;
    };

    final results = await Future.wait([
      fetcher.confirmApiReachableForTest(),
      fetcher.confirmApiReachableForTest(),
      fetcher.confirmApiReachableForTest(),
    ]);

    expect(results, everyElement(isTrue));
    expect(probeCalls, 1);
  });

  test('a fresh probe runs after the previous one completes', () async {
    var probeCalls = 0;
    fetcher.probeOverrideForTest = () async {
      probeCalls++;
      return true;
    };

    expect(await fetcher.confirmApiReachableForTest(), isTrue);
    expect(await fetcher.confirmApiReachableForTest(), isTrue);
    expect(probeCalls, 2);
  });
}
