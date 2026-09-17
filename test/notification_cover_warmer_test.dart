import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/models/song.dart';
import 'package:wispie/services/notification_cover_warmer.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationCoverWarmer background behavior', () {
    late TestEnvironment testEnv;
    final warmer = NotificationCoverWarmer.instance;

    setUpAll(() {
      testEnv = TestEnvironment();
      testEnv.setUp();
    });

    tearDownAll(() {
      testEnv.tearDown();
    });

    setUp(() {
      warmer.resetForTest();
    });

    tearDown(() {
      warmer.resetForTest();
    });

    Song makeSong(String name) {
      return Song(
        title: name,
        artist: 'Artist',
        album: 'Album',
        filename: '$name.mp3',
        url: '/dummy/$name.mp3',
        coverUrl: '/dummy/$name.jpg',
      );
    }

    test(
        'terminates drain when background budget is reached instead of looping',
        () async {
      warmer.setForeground(false);

      final songs = List.generate(5, (i) => makeSong('track_$i'));
      warmer.setQueue(songs, 0, PlayerCoverSizingMode.autoFit);

      // In background, after budget (2 items) is processed or when budget reached,
      // drain terminates cleanly and isRunning becomes false.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(warmer.isRunning, isFalse);
    });

    test('resuming foreground resets budget and schedules drain', () async {
      warmer.setForeground(false);
      final songs = List.generate(4, (i) => makeSong('track_$i'));
      warmer.setQueue(songs, 0, PlayerCoverSizingMode.autoFit);

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(warmer.isRunning, isFalse);

      warmer.setForeground(true);
      expect(warmer.backgroundProcessedCount, 0);
    });

    test('pausing warming stops background drain cleanly', () async {
      warmer.pushPause();
      final songs = List.generate(3, (i) => makeSong('paused_$i'));
      warmer.setQueue(songs, 0, PlayerCoverSizingMode.autoFit);

      // Should not be running while pause is held
      expect(warmer.isRunning, isFalse);

      warmer.popPause();
      // After popPause, schedule is triggered and queue exists
      expect(warmer.pendingCount, greaterThan(0));
    });
  });
}
