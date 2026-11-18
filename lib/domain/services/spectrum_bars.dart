import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../data/rust/wispie_core.dart';
import '../models/beat_map.dart';

/// The frame math behind the four-bar audio visualiser.
///
/// The ballistics, the band interpolation and the beat punch live in the native
/// core; this is the adapter that hands it the beat map and keeps the buffers
/// alive across frames.
class SpectrumBars {
  SpectrumBars._();

  /// One bar per [BeatBand]. Mirrored from the core, which is the authority.
  static const int barCount = 4;

  /// Rise and fall time constants, in seconds (mirrored from the core).
  static const double attackTau = 0.010;
  static const double releaseTau = 0.055;

  /// Height a bar never falls below, as a fraction of the full height.
  static const double floor = 0.05;

  /// Moves [level] toward [target] over [dtSeconds], rising fast and falling
  /// slowly. Frame-rate independent.
  static double advance(double level, double target, double dtSeconds) =>
      WispieCore.spectrumScalar(0, level, target, dtSeconds);

  /// Rise or fall constant for a bar moving from [level] to [target].
  static double tauFor(double level, double target) =>
      WispieCore.spectrumScalar(1, level, target);

  /// [advance] with the time constant supplied explicitly.
  static double advanceWithTau(
    double level,
    double target,
    double dtSeconds,
    double tau,
  ) =>
      WispieCore.spectrumScalar(5, level, target, dtSeconds, tau);

  /// Maps raw band energy in 0..1 to a bar height in [floor]..1.
  static double shape(double raw) => WispieCore.spectrumScalar(2, raw);

  /// Beat punch [sinceBeatMs] after a beat of [periodMs], peaking at 1.
  static double punch(double sinceBeatMs, double periodMs) =>
      WispieCore.spectrumScalar(3, sinceBeatMs, periodMs);

  /// A small per-bar swell, so four bands moving together stay distinguishable.
  static double breath(int bar, double elapsedSeconds) =>
      WispieCore.spectrumScalar(4, bar.toDouble(), elapsedSeconds);

  static _SpectrumMap? _map;
  static final NativeScratch _targets = NativeScratch(barCount * 8);
  static final NativeScratch _levels = NativeScratch(barCount * 8);
  static final NativeScratch _syncedBars = NativeScratch(barCount * 8);
  static final NativeScratch _idleBars = NativeScratch(barCount * 8);

  static _SpectrumMap _buffersFor(BeatMap map) {
    final cached = _map;
    if (cached != null && identical(cached.map, map)) return cached;
    cached?.dispose();
    final fresh = _SpectrumMap(map);
    _map = fresh;
    return fresh;
  }

  /// Bar targets for [positionMs] of [map], written into [out].
  ///
  /// Returns false when the map has no usable band data.
  static bool targetsAt(BeatMap map, double positionMs, List<double> out) {
    final buffers = _buffersFor(map);
    final usable = WispieCore.spectrumTargets(
      bands: buffers.bands.pointer,
      bandLength: buffers.bands.length,
      beats: buffers.beats.intsPointer,
      beatCount: map.beatsMs.length,
      strengths: buffers.strengths.floatsPointer,
      bpm: map.bpm,
      positionMs: positionMs,
      out: _targets.doublesPointer,
    );
    if (usable == 0) return false;
    final values = _targets.doubles;
    for (var index = 0; index < barCount; index++) {
      out[index] = values[index];
    }
    return true;
  }

  /// Advances all bars by one frame: idle walk, synced bands, pause fade and
  /// the response cross-fade, in one core call.
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
    final levelView = _levels.doubles;
    final syncedView = _syncedBars.doubles;
    final idleView = _idleBars.doubles;
    for (var index = 0; index < barCount; index++) {
      levelView[index] = levels[index];
      syncedView[index] = synced[index];
      idleView[index] = idle[index];
    }
    WispieCore.spectrumFrame(
      levels: _levels.doublesPointer,
      synced: _syncedBars.doublesPointer,
      idle: _idleBars.doublesPointer,
      elapsedSeconds: elapsedSeconds,
      dtSeconds: dtSeconds,
      gridBlend: gridBlend,
      pauseBlend: pauseBlend,
      idleTau: idleTau,
    );
    for (var index = 0; index < barCount; index++) {
      levels[index] = levelView[index];
    }
  }
}

/// Native copy of one beat map, rebuilt only when the map itself changes.
class _SpectrumMap {
  _SpectrumMap(this.map)
      : bands = NativeScratch(math.max(1, map.bands.length)),
        beats = NativeScratch(math.max(4, map.beatsMs.length * 4)),
        strengths = NativeScratch(math.max(4, map.beatStrength.length * 4)) {
    if (map.bands.isNotEmpty) {
      bands.bytes.setAll(0, map.bands);
    }
    if (map.beatsMs.isNotEmpty) {
      beats.ints.setAll(0, map.beatsMs);
    }
    if (map.beatStrength.isNotEmpty) {
      strengths.floatsPointer
          .asTypedList(map.beatStrength.length)
          .setAll(0, map.beatStrength);
    }
  }

  final BeatMap map;
  final NativeScratch bands;
  final NativeScratch beats;
  final NativeScratch strengths;

  void dispose() {
    bands.dispose();
    beats.dispose();
    strengths.dispose();
  }
}
