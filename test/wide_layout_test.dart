import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/presentation/utils/wide_layout.dart';

void main() {
  group('WideLayout', () {
    test('isPortrait detects portrait aspect ratio', () {
      expect(WideLayout.isPortrait(const Size(400, 800)), isTrue);
      expect(WideLayout.isPortrait(const Size(600, 900)), isTrue);
      expect(WideLayout.isPortrait(const Size(500, 500)), isTrue);
      expect(WideLayout.isPortrait(const Size(800, 600)), isFalse);
    });

    test('isWideSize returns true only for wide landscape layouts', () {
      expect(WideLayout.isWideSize(const Size(1200, 800)), isTrue);
      expect(WideLayout.isWideSize(const Size(800, 600)), isTrue);
      expect(WideLayout.isWideSize(const Size(800, 1000)), isFalse);
      expect(WideLayout.isWideSize(const Size(700, 500)), isFalse);
      expect(WideLayout.isWideSize(const Size(400, 800)), isFalse);
    });

    test('isCompactSize returns true for portrait windows or narrow landscape',
        () {
      expect(WideLayout.isCompactSize(const Size(400, 800)), isTrue);
      expect(WideLayout.isCompactSize(const Size(600, 900)), isTrue);
      expect(WideLayout.isCompactSize(const Size(360, 540)), isTrue);
      expect(WideLayout.isCompactSize(const Size(450, 400)), isTrue);
      expect(WideLayout.isCompactSize(const Size(700, 500)), isFalse);
      expect(WideLayout.isCompactSize(const Size(1200, 800)), isFalse);
    });

    testWidgets('gridColumns stays at base count for portrait windows',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(600, 900)),
            child: Builder(
              builder: (context) {
                final cols = WideLayout.gridColumns(context, base: 2);
                return Text('columns: $cols');
              },
            ),
          ),
        ),
      );

      expect(find.text('columns: 2'), findsOneWidget);
    });

    testWidgets('gridColumns scales up for wide landscape windows',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 700)),
            child: Builder(
              builder: (context) {
                final cols = WideLayout.gridColumns(context, base: 2);
                return Text('columns: $cols');
              },
            ),
          ),
        ),
      );

      expect(find.text('columns: 3'), findsOneWidget);
    });
  });
}
