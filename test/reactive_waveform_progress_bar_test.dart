import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wispie/models/song.dart';
import 'package:wispie/presentation/widgets/reactive_waveform_progress_bar.dart';
import 'package:wispie/presentation/widgets/spectrum_controller.dart';
import 'package:wispie/providers/providers.dart';
import 'package:wispie/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProgressBarType Settings', () {
    test('defaults to reactive and persists selection', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(settingsProvider.notifier);
      expect(
        container.read(settingsProvider).progressBarType,
        ProgressBarType.reactive,
      );
      expect(container.read(settingsProvider).showWaveform, isTrue);

      await notifier.setProgressBarType(ProgressBarType.basic);
      expect(
        container.read(settingsProvider).progressBarType,
        ProgressBarType.basic,
      );
      expect(container.read(settingsProvider).showWaveform, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('progress_bar_type'), ProgressBarType.basic.index);
      expect(prefs.getBool('show_waveform'), isFalse);

      await notifier.setProgressBarType(ProgressBarType.waveform);
      expect(
        container.read(settingsProvider).progressBarType,
        ProgressBarType.waveform,
      );
      expect(container.read(settingsProvider).showWaveform, isTrue);
      expect(prefs.getInt('progress_bar_type'), ProgressBarType.waveform.index);
      expect(prefs.getBool('show_waveform'), isTrue);
    });

    test('backward compatibility: handles legacy show_waveform = false',
        () async {
      SharedPreferences.setMockInitialValues({
        'show_waveform': false,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(settingsProvider).progressBarType,
        ProgressBarType.basic,
      );
      expect(container.read(settingsProvider).showWaveform, isFalse);
    });

    test('backward compatibility: handles legacy show_waveform = true',
        () async {
      SharedPreferences.setMockInitialValues({
        'show_waveform': true,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(settingsProvider).progressBarType,
        ProgressBarType.reactive,
      );
      expect(container.read(settingsProvider).showWaveform, isTrue);
    });
  });

  group('ReactiveWaveformProgressBar Widget', () {
    testWidgets('mounts, renders time labels and handles seek on tap',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      Duration? seekTarget;

      final testController = SpectrumController.forTesting();
      addTearDown(testController.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spectrumControllerProvider.overrideWithValue(testController),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: ReactiveWaveformProgressBar(
                    filename: 'song_test.mp3',
                    path: '/path/to/song_test.mp3',
                    progress: const Duration(seconds: 30),
                    total: const Duration(seconds: 120),
                    onSeek: (pos) => seekTarget = pos,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReactiveWaveformProgressBar), findsOneWidget);
      expect(find.text('2:00'), findsOneWidget);

      final barFinder = find.byType(ReactiveWaveformProgressBar);
      final center = tester.getCenter(barFinder);

      await tester.tapAt(center);
      await tester.pump();

      expect(seekTarget, isNotNull);
      expect(seekTarget!.inSeconds, greaterThan(0));
    });

    test('ReactiveWaveformPainter paints with spectrum levels without error',
        () {
      final testController = SpectrumController.forTesting();
      addTearDown(testController.dispose);

      testController.levels[0] = 0.9;
      testController.levels[1] = 0.5;
      testController.levels[2] = 0.3;
      testController.levels[3] = 0.1;

      final painter = ReactiveWaveformPainter(
        controller: testController,
        peaks: [0.2, 0.4, 0.8, 0.6, 0.3, 0.9, 0.5, 0.1],
        revealProgress: 1.0,
        positionNotifier: ValueNotifier(const Duration(seconds: 45)),
        dragPositionNotifier: ValueNotifier(null),
        total: const Duration(seconds: 180),
        primaryColor: Colors.blue,
        accentColor: Colors.amber,
        inactiveColor: Colors.grey,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(300, 60);

      expect(() => painter.paint(canvas, size), returnsNormally);
      recorder.endRecording();
    });
  });
}
