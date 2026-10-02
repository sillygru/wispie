import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/presentation/screens/player/lyrics_timing_control.dart';

void main() {
  late LyricsTimingController controller;

  Widget harness() => MaterialApp(
        home: Scaffold(
          body: Center(
            child: LyricsTimingReadout(
              controller: controller,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      );

  setUp(() => controller = LyricsTimingController());

  tearDown(() => controller.dispose());

  testWidgets('shows the offset to two decimals', (tester) async {
    controller.load(2.35);
    await tester.pumpWidget(harness());

    expect(find.text('+2.35'), findsOneWidget);
  });

  testWidgets('double tap resets the offset to zero', (tester) async {
    controller.load(2.35);
    var reported = -1.0;
    controller.onChanged = (seconds) => reported = seconds;

    await tester.pumpWidget(harness());
    await tester.tap(find.text('+2.35'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('+2.35'));
    await tester.pumpAndSettle();

    expect(controller.seconds, 0);
    expect(find.text('In sync'), findsOneWidget);
    // The pane persists whatever the controller reports, so the reset has to
    // travel through onChanged rather than only moving the displayed number.
    expect(reported, 0);
  });

  testWidgets('a single tap does not reset', (tester) async {
    controller.load(2.35);
    await tester.pumpWidget(harness());

    await tester.tap(find.text('+2.35'));
    await tester.pumpAndSettle();

    expect(controller.seconds, 2.35);
    expect(find.text('+2.35'), findsOneWidget);
  });

  testWidgets('resetting a zero offset does not animate', (tester) async {
    await tester.pumpWidget(harness());
    expect(find.text('In sync'), findsOneWidget);

    await tester.tap(find.text('In sync'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('In sync'));
    await tester.pumpAndSettle();

    expect(controller.seconds, 0);
  });

  testWidgets('the readout follows edits from other controls', (tester) async {
    controller.load(0);
    await tester.pumpWidget(harness());

    controller.nudge(-0.01);
    await tester.pump();

    expect(find.text('-0.01'), findsOneWidget);
  });

  testWidgets('the optional unit is rendered', (tester) async {
    controller.load(1.5);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LyricsTimingReadout(
              controller: controller,
              showUnit: true,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    );

    expect(find.text('+1.50 s'), findsOneWidget);
  });
}
