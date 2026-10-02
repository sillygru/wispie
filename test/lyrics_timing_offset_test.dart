import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/domain/services/lyrics_timing_offset.dart';

void main() {
  group('lyrics timing rungs', () {
    test('the three windows together cover the whole 120s range', () {
      for (final rung in LyricsTimingPrecision.values) {
        final window = anchorLyricsTimingWindow(
          currentSeconds: 0,
          precision: rung,
        );
        expect(
          window.lower,
          greaterThanOrEqualTo(-kLyricsTimingMaxSeconds),
          reason: '${rung.name} must not reach past the ceiling',
        );
        expect(
          window.upper,
          lessThanOrEqualTo(kLyricsTimingMaxSeconds),
          reason: '${rung.name} must not reach past the ceiling',
        );
      }

      // Coarse is the range itself, so nothing is unreachable.
      final coarse = anchorLyricsTimingWindow(
        currentSeconds: 0,
        precision: LyricsTimingPrecision.coarse,
      );
      expect(coarse.lower, -kLyricsTimingMaxSeconds);
      expect(coarse.upper, kLyricsTimingMaxSeconds);
    });

    test('coarse is pinned to the full range wherever the offset sits', () {
      for (final seconds in [-41.3, -12.0, 0.0, 0.07, 12.0, 55.9]) {
        final window = anchorLyricsTimingWindow(
          currentSeconds: seconds,
          precision: LyricsTimingPrecision.coarse,
        );
        expect(window.lower, -kLyricsTimingMaxSeconds);
        expect(window.upper, kLyricsTimingMaxSeconds);
      }
    });

    test('every rung divides its span into exact whole steps', () {
      for (final rung in LyricsTimingPrecision.values) {
        final window = anchorLyricsTimingWindow(
          currentSeconds: 2.35,
          precision: rung,
        );
        // A Slider whose span is not a whole multiple of its step makes one
        // division worth something other than `step`.
        expect(window.span / window.step, closeTo(rung.divisions, 0.0001));
        expect(window.divisions, greaterThan(0));
      }
    });

    test('fine is where a 1-3s correction becomes reachable', () {
      final fine = anchorLyricsTimingWindow(
        currentSeconds: 2.35,
        precision: LyricsTimingPrecision.fine,
      );
      // Anchored on the offset, so selecting fine does not move the value.
      expect(fine.contains(2.35), isTrue);
      // A hundredth of a second of movement per division.
      expect(fine.snap(2.34), closeTo(2.34, 1e-9));
      expect(fine.snap(2.36), closeTo(2.36, 1e-9));
      // And the drift that motivates quantization never accumulates.
      var drifted = 0.0;
      for (var i = 0; i < 100; i++) {
        drifted += 0.01;
      }
      expect(quantizeLyricsTimingOffset(drifted), closeTo(1.0, 1e-9));
    });

    test('an offset is always inside the window it is shown in', () {
      for (final rung in LyricsTimingPrecision.values) {
        for (final seconds in [
          -60.0,
          -33.7,
          -5.0,
          0.0,
          0.01,
          2.35,
          59.99,
          60.0
        ]) {
          final window = anchorLyricsTimingWindow(
            currentSeconds: seconds,
            precision: rung,
          );
          expect(
            window.contains(quantizeLyricsTimingOffset(seconds)),
            isTrue,
            reason: '${rung.name} dropped $seconds outside its window',
          );
        }
      }
    });

    test('the window clamps rather than overflowing the ceiling', () {
      final window = anchorLyricsTimingWindow(
        currentSeconds: 58,
        precision: LyricsTimingPrecision.medium,
      );
      expect(window.upper, kLyricsTimingMaxSeconds);
      expect(window.span, 20.0);
      expect(window.contains(58), isTrue);
    });

    test('snap never leaves the window', () {
      final window = anchorLyricsTimingWindow(
        currentSeconds: 2.35,
        precision: LyricsTimingPrecision.fine,
      );
      expect(window.snap(-999), window.lower);
      expect(window.snap(999), window.upper);
    });
  });

  group('clamp and quantize', () {
    test('clamps to both ends of the range', () {
      expect(clampLyricsTimingOffset(90), kLyricsTimingMaxSeconds);
      expect(clampLyricsTimingOffset(-90), -kLyricsTimingMaxSeconds);
      expect(clampLyricsTimingOffset(12.5), 12.5);
    });

    test('the hundredths ceiling and the seconds ceiling agree', () {
      expect(
        quantizeLyricsTimingOffset(kLyricsTimingMaxSeconds),
        kLyricsTimingMaxSeconds,
      );
      expect(
        quantizeLyricsTimingOffset(-kLyricsTimingMaxSeconds),
        -kLyricsTimingMaxSeconds,
      );
      expect(
        quantizeLyricsTimingOffset(kLyricsTimingMaxSeconds + 0.4),
        kLyricsTimingMaxSeconds,
      );
    });

    test('quantize lands on the grid and is idempotent', () {
      expect(quantizeLyricsTimingOffset(2.347), 2.35);
      expect(quantizeLyricsTimingOffset(2.352), 2.35);
      expect(quantizeLyricsTimingOffset(-0.004), 0.0);
      final once = quantizeLyricsTimingOffset(7.123);
      expect(quantizeLyricsTimingOffset(once), once);
    });

    test('the printed decimals are the stored value', () {
      // Regression guard for the reason quantize divides rather than multiplies.
      expect(2.35.toStringAsFixed(2),
          quantizeLyricsTimingOffset(2.35).toStringAsFixed(2));
      for (var hundredths = 1; hundredths < 6000; hundredths += 7) {
        final value = quantizeLyricsTimingOffset(hundredths / 100);
        expect(value * 100, closeTo(hundredths.toDouble(), 1e-9));
      }
    });

    test('quantizing on a coarser step moves to that grid', () {
      expect(quantizeLyricsTimingOffset(2.37, step: 0.1), closeTo(2.4, 1e-9));
      expect(quantizeLyricsTimingOffset(2.37, step: 0.05), closeTo(2.35, 1e-9));
      expect(quantizeLyricsTimingOffset(2.37, step: 0.01), closeTo(2.37, 1e-9));
    });
  });

  group('nudge', () {
    test('moves by whole grid steps and returns exactly', () {
      expect(nudgeLyricsTimingOffset(0, 0.1), closeTo(0.1, 1e-9));
      expect(nudgeLyricsTimingOffset(2.35, -0.01), closeTo(2.34, 1e-9));
      expect(nudgeLyricsTimingOffset(2.35, 1), closeTo(3.35, 1e-9));
    });

    test('cannot escape the ceiling', () {
      expect(
        nudgeLyricsTimingOffset(kLyricsTimingMaxSeconds, 1),
        kLyricsTimingMaxSeconds,
      );
      expect(
        nudgeLyricsTimingOffset(-kLyricsTimingMaxSeconds, -1),
        -kLyricsTimingMaxSeconds,
      );
    });

    test('walking to the ceiling lands on it exactly', () {
      var offset = 0.0;
      for (var i = 0; i < 200; i++) {
        offset = nudgeLyricsTimingOffset(offset, 1);
      }
      expect(offset, kLyricsTimingMaxSeconds);
    });
  });

  group('playhead shifting', () {
    test('a positive offset delays the words', () {
      // The pane reads the lyric clock as position - offset, so a line stamped
      // at 10s only becomes active at 12.35s of playback once the offset is set.
      final active = applyLyricsTimingOffset(
        const Duration(seconds: 12, milliseconds: 350),
        2.35,
      );
      expect(active, const Duration(seconds: 10));
    });

    test('seeking a line undoes the shift', () {
      expect(
        undoLyricsTimingOffset(const Duration(seconds: 10), 2.35),
        const Duration(seconds: 12, milliseconds: 350),
      );
    });

    test('a zero offset is a no-op in both directions', () {
      expect(
        applyLyricsTimingOffset(const Duration(seconds: 42), 0),
        const Duration(seconds: 42),
      );
      expect(
        undoLyricsTimingOffset(const Duration(seconds: 42), 0),
        const Duration(seconds: 42),
      );
    });

    test('apply and undo round-trip within a millisecond', () {
      for (final offset in [-37.5, -2.35, 0.0, 0.01, 2.35, 47.2]) {
        final shifted = applyLyricsTimingOffset(
          const Duration(minutes: 3, seconds: 17, milliseconds: 250),
          offset,
        );
        final restored = undoLyricsTimingOffset(shifted, offset);
        expect(
          (restored -
                  const Duration(minutes: 3, seconds: 17, milliseconds: 250))
              .inMicroseconds
              .abs(),
          lessThan(1000),
        );
      }
    });
  });

  group('syncing to the playhead', () {
    test('derives the offset that puts a line exactly on the playhead', () {
      expect(
        syncOffsetFromPlayhead(
          position: const Duration(seconds: 12, milliseconds: 350),
          activeLineTime: const Duration(seconds: 10),
        ),
        2.35,
      );
    });

    test('the derived offset actually activates that line', () {
      final lineTime = const Duration(seconds: 74);
      final playhead = const Duration(seconds: 70, milliseconds: 400);
      final offset = syncOffsetFromPlayhead(
        position: playhead,
        activeLineTime: lineTime,
      );
      expect(offset, -3.6);

      // Feeding it back through the pane's own shift puts the playhead on the
      // line, which is the whole point of the button.
      expect(applyLyricsTimingOffset(playhead, offset!), lineTime);
    });

    test('works for lyrics that run late as well as early', () {
      expect(
        syncOffsetFromPlayhead(
          position: const Duration(seconds: 8),
          activeLineTime: const Duration(seconds: 10, milliseconds: 200),
        ),
        -2.2,
      );
    });

    test('returns null when there is no timed line to snap to', () {
      expect(
        syncOffsetFromPlayhead(
          position: const Duration(seconds: 30),
          activeLineTime: null,
        ),
        isNull,
      );
    });

    test('stays inside the range', () {
      expect(
        syncOffsetFromPlayhead(
          position: const Duration(seconds: 600),
          activeLineTime: const Duration(seconds: 5),
        ),
        kLyricsTimingMaxSeconds,
      );
    });
  });

  group('readout', () {
    test('zero reads as in sync', () {
      expect(formatLyricsTimingOffset(0), 'In sync');
      expect(formatLyricsTimingOffset(0.004), 'In sync');
      expect(formatLyricsTimingOffset(-0.004), 'In sync');
    });

    test('shows two decimals so the fine rung is legible', () {
      expect(formatLyricsTimingOffset(2.35), '+2.35');
      expect(formatLyricsTimingOffset(-2.35), '-2.35');
      expect(formatLyricsTimingOffset(0.5), '+0.50');
      expect(formatLyricsTimingOffset(-0.01), '-0.01');
      expect(formatLyricsTimingOffset(kLyricsTimingMaxSeconds), '+60.00');
    });

    test('the unit is optional', () {
      expect(formatLyricsTimingOffset(2.35, showUnit: true), '+2.35 s');
      expect(formatLyricsTimingOffset(0, showUnit: true), 'In sync');
    });
  });

  group('rung labels', () {
    test('name the step size', () {
      expect(LyricsTimingPrecision.coarse.label, '0.10s');
      expect(LyricsTimingPrecision.medium.label, '0.05s');
      expect(LyricsTimingPrecision.fine.label, '0.01s');
    });
  });
}
