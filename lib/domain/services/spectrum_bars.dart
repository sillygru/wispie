import 'dart:math' as math;
import 'dart:typed_data';

import '../models/beat_map.dart';

/// The frame math behind the four-bar audio visualiser.
class SpectrumBars {
  SpectrumBars._();

  static const int barCount = 4;
  static const double attackTau = 0.010;
  static const double releaseTau = 0.055;
  static const double floor = 0.05;
  static const double _punchAttackMs = 18;

  static double advance(double level, double target, double dtSeconds) =>
      advanceWithTau(level, target, dtSeconds, tauFor(level, target));

  static double tauFor(double level, double target) =>
      target > level ? attackTau : releaseTau;

  static double advanceWithTau(
    double level,
    double target,
    double dtSeconds,
    double tau,
  ) {
    if (dtSeconds <= 0) return level;
    return level + (target - level) * (1 - math.exp(-dtSeconds / tau));
  }

  static double shape(double raw) =>
      floor + (1 - floor) * math.pow(clamp01(raw), 1.15);

  static double punch(double sinceBeatMs, double periodMs) {
    if (sinceBeatMs < 0) return 0;
    final decayMs = (periodMs * 0.30).clamp(70.0, 180.0);
    if (sinceBeatMs > decayMs * 5) return 0;
    final peakTime = _punchAttackMs * math.log(1 + decayMs / _punchAttackMs);
    final peak = (1 - math.exp(-peakTime / _punchAttackMs)) *
        math.exp(-peakTime / decayMs);
    final attack = 1 - math.exp(-sinceBeatMs / _punchAttackMs);
    final decay = math.exp(-sinceBeatMs / decayMs);
    return attack * decay * (peak <= 0 ? 1 : 1 / peak);
  }

  static double breath(int bar, double elapsedSeconds) =>
      1 + 0.03 * math.sin(2 * math.pi * (0.21 * elapsedSeconds + bar * 0.37));

  /// Returns false when the map has no usable band data.
  static bool targetsAt(BeatMap map, double positionMs, List<double> out) {
    if (map.bandFrameCount == 0) return false;
    for (final band in BeatBand.values) {
      out[band.index] =
          shape(positionMs.isFinite ? map.bandAt(band, positionMs) : 0);
    }

    if (!positionMs.isFinite ||
        !map.hasBeats ||
        map.beatStrength.length < map.beatsMs.length) {
      return true;
    }
    final index = map.beatIndexAt(positionMs.round());
    if (index < 0) return true;

    final hit =
        punch(positionMs - map.beatsMs[index], map.beatPeriodMsAt(index)) *
            map.beatStrength[index];
    if (hit <= 0) return true;

    // Use the available headroom so the beat stays visible near full height.
    out[0] += (1 - out[0]) * hit * 0.18;
    out[1] += (1 - out[1]) * hit * 0.09;
    return true;
  }

  static void stepFrame({
    required Float64List levels,
    required List<double> synced,
    required List<double> idle,
    required double elapsedSeconds,
    required double dtSeconds,
    required double gridBlend,
    required double pauseBlend,
    required double idleTau,
  }) {
    for (var bar = 0; bar < barCount; bar++) {
      var target = idle[bar];
      if (gridBlend > 0) {
        final band = synced[bar] * breath(bar, elapsedSeconds);
        target += (band - target) * gridBlend;
      }
      target += (floor - target) * pauseBlend;

      final tau = gridBlend <= 0
          ? idleTau
          : idleTau + (tauFor(levels[bar], target) - idleTau) * gridBlend;
      levels[bar] =
          advanceWithTau(levels[bar], target, dtSeconds, tau).clamp(0.0, 1.0);
    }
  }
}
