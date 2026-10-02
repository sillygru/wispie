import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/services/lyrics_timing_offset.dart';
import '../../components/pressable.dart';
import '../../tokens/player_tokens.dart';

/// Shared state for the two timing surfaces: the inline pill in the action strip
/// and the full sheet behind it.
///
/// Both are live at once while the sheet is open, so the offset, the active rung
/// and the anchored window live here rather than in either widget — two copies
/// of the same value would drift the moment the user moved one and not the other.
///
/// Persistence is deliberately *not* handled here. The pane owns the debounced
/// write and the playhead preview; this only decides what the number is and when
/// it changed, via [onChanged].
class LyricsTimingController extends ChangeNotifier {
  LyricsTimingController({double initialSeconds = 0})
      : _seconds = quantizeLyricsTimingOffset(initialSeconds),
        _window = anchorLyricsTimingWindow(
          currentSeconds: initialSeconds,
          precision: LyricsTimingPrecision.coarse,
        );

  /// Fired on every committed change so the pane can preview the offset against
  /// the playhead and schedule a write.
  void Function(double seconds) onChanged = (_) {};

  double _seconds;
  LyricsTimingWindow _window;
  LyricsTimingPrecision _precision = LyricsTimingPrecision.coarse;

  double get seconds => _seconds;
  LyricsTimingWindow get window => _window;
  LyricsTimingPrecision get precision => _precision;

  /// Loads the stored offset for a song, returning the rung to coarse.
  ///
  /// The rung is not persisted, and carrying the previous song's magnification
  /// into a new one would be misleading — a ±5s window is only meaningful
  /// relative to the offset it was anchored on.
  void load(double seconds) {
    _seconds = quantizeLyricsTimingOffset(seconds);
    _precision = LyricsTimingPrecision.coarse;
    _window = anchorLyricsTimingWindow(
      currentSeconds: _seconds,
      precision: _precision,
    );
    notifyListeners();
  }

  /// Moves the offset while a slider is being dragged.
  ///
  /// The window is left alone: it is the slider's own `min`/`max`, so re-anchoring
  /// mid-drag would move the track out from under the finger. [commitSlider]
  /// re-centres once the finger lifts.
  void drag(double seconds) {
    final next = quantizeLyricsTimingOffset(seconds, step: _precision.step);
    if (next == _seconds) return;
    _seconds = next;
    onChanged(next);
    notifyListeners();
  }

  /// Re-centres the window on the offset after a drag, so the rung the user is
  /// on still has room to travel in both directions.
  void commitSlider() {
    _window = anchorLyricsTimingWindow(
      currentSeconds: _seconds,
      precision: _precision,
    );
    notifyListeners();
  }

  /// Moves by [steps] grid steps, re-anchoring if the move left the window.
  ///
  /// Without that re-anchor a nudge that walked off the end of the fine window
  /// would sit against the ceiling until the user changed rung, which reads as
  /// the control having stopped responding.
  void nudge(double steps) {
    final next = nudgeLyricsTimingOffset(_seconds, steps);
    if (next == _seconds) return;
    _seconds = next;
    onChanged(next);
    if (!_window.contains(next)) _reanchor();
    notifyListeners();
  }

  /// Switches rung, keeping the offset.
  ///
  /// The value is re-quantized onto the new rung's grid so the slider can always
  /// represent it exactly — otherwise a +2.35s offset picked up in the fine rung
  /// would visibly jump to +2.30 or +2.40 the moment coarse was selected.
  void setPrecision(LyricsTimingPrecision precision) {
    if (precision == _precision) return;
    _precision = precision;
    final next = quantizeLyricsTimingOffset(_seconds, step: precision.step);
    _seconds = next;
    _window = anchorLyricsTimingWindow(
      currentSeconds: next,
      precision: precision,
    );
    onChanged(_seconds);
    notifyListeners();
  }

  /// Snaps the offset so [activeLineTime] lands exactly on [position].
  ///
  /// Returns false when there is no timed line to snap to, which is the case for
  /// lyrics with no usable LRC stamps — the caller disables the button rather
  /// than having it silently do nothing.
  bool syncTo(Duration position, Duration? activeLineTime) {
    final next = syncOffsetFromPlayhead(
      position: position,
      activeLineTime: activeLineTime,
    );
    if (next == null) return false;
    _seconds = next;
    onChanged(next);
    _reanchor();
    notifyListeners();
    return true;
  }

  void reset() {
    if (_seconds == 0) return;
    _seconds = 0;
    onChanged(0);
    _reanchor();
    notifyListeners();
  }

  void _reanchor() {
    _window = anchorLyricsTimingWindow(
      currentSeconds: _seconds,
      precision: _precision,
    );
  }
}

/// The inline timing pill in the action strip: rung chip, slider, readout.
///
/// Coarse-first by default — it keeps the current behaviour of one full-range
/// slider — with the rung chip as the way into real precision. Opening the sheet
/// is on a long press rather than a dedicated button, because the strip already
/// has to collapse its other actions on narrow windows and there is no room in
/// the budget for one more icon.
class LyricsTimingControl extends StatelessWidget {
  const LyricsTimingControl({
    super.key,
    required this.controller,
    required this.accent,
    required this.onOpenSheet,
  });

  static const double width = 240;

  final LyricsTimingController controller;
  final Color accent;
  final VoidCallback onOpenSheet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: PlayerTokens.lyricsTimingControlHeight,
      padding: const EdgeInsets.symmetric(horizontal: PlayerTokens.s2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: PlayerTokens.accentWash),
        borderRadius: PlayerTokens.brPill,
      ),
      // The slider and the readout are two separate readouts of one value, so
      // they rebuild together off the controller rather than through the pane's
      // setState — the pane rebuilds the whole strip on unrelated changes.
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final window = controller.window;
          return Row(
            children: [
              _RungChip(
                precision: controller.precision,
                accent: accent,
                onTap: () =>
                    controller.setPrecision(_next(controller.precision)),
                onLongPress: onOpenSheet,
              ),
              const SizedBox(width: PlayerTokens.s1),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: accent,
                    thumbColor: accent,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: window.snap(controller.seconds),
                    min: window.lower,
                    max: window.upper,
                    divisions: window.divisions,
                    label: formatLyricsTimingOffset(
                      controller.seconds,
                      showUnit: true,
                    ),
                    onChanged: controller.drag,
                    onChangeEnd: (_) => controller.commitSlider(),
                  ),
                ),
              ),
              const SizedBox(width: PlayerTokens.s1),
              LyricsTimingReadout(
                controller: controller,
                style: PlayerTokens.meta(context).copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static LyricsTimingPrecision _next(LyricsTimingPrecision current) =>
      LyricsTimingPrecision
          .values[(current.index + 1) % LyricsTimingPrecision.values.length];
}

/// The numeric offset, which doubles as the reset target.
///
/// Double-tap returns the offset to zero. Every tuning session ends on a reset —
/// either because zero is right, or because the offset has been chased somewhere
/// useless and starting over beats nudging back through it — and a double tap is
/// the only gesture that can carry that meaning without stealing a control the
/// user needs for the tuning itself.
///
/// It sits on the number rather than the slider track on purpose: the track is
/// draggable, so a double-tap recogniser there would lose the gesture arena to
/// the drag.
class LyricsTimingReadout extends StatefulWidget {
  const LyricsTimingReadout({
    super.key,
    required this.controller,
    required this.style,
    this.showUnit = false,
  });

  final LyricsTimingController controller;
  final TextStyle style;
  final bool showUnit;

  @override
  State<LyricsTimingReadout> createState() => _LyricsTimingReadoutState();
}

class _LyricsTimingReadoutState extends State<LyricsTimingReadout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reset = AnimationController(
    vsync: this,
    duration: PlayerTokens.dBase,
  );

  @override
  void dispose() {
    _reset.dispose();
    super.dispose();
  }

  void _resetOffset() {
    // Nothing to pop if there was nothing to undo; a scale pulse on a value that
    // did not move just reads as a glitch.
    if (widget.controller.seconds == 0) return;
    widget.controller.reset();
    _reset.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _resetOffset,
      // Only the double tap, no single-tap handler: a bare tap on the number
      // should not look interactive unless it does something.
      child: Tooltip(
        message: 'Double-tap to reset to 0.00',
        // Subscribes to the controller itself rather than relying on whichever
        // surface happens to wrap it. Both current callers are inside an
        // AnimatedBuilder over the same controller, but a readout that only
        // updates when something above it rebuilds is one refactor away from
        // silently showing a stale offset.
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => AnimatedBuilder(
            animation: _reset,
            builder: (context, _) => Transform.scale(
              // Overshoots past 1 on the way down, so it settles rather than
              // landing flat — the same spring language as Pressable.
              scale:
                  1 + 0.18 * (1 - Curves.easeOutBack.transform(_reset.value)),
              child: Text(
                formatLyricsTimingOffset(
                  widget.controller.seconds,
                  showUnit: widget.showUnit,
                ),
                style: widget.style,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The step-size chip. Shows the rung's resolution rather than naming it, since
/// the resolution is the thing the user is actually choosing.
class _RungChip extends StatelessWidget {
  const _RungChip({
    required this.precision,
    required this.accent,
    required this.onTap,
    required this.onLongPress,
  });

  final LyricsTimingPrecision precision;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      haptic: PressHaptic.selection,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PlayerTokens.s1),
        child: Text(
          precision.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
            color: accent,
          ),
        ),
      ),
    );
  }
}

/// One step of the nudge row.
///
/// A tap moves by [step] seconds; holding repeats. The repeat is a deliberate
/// state machine rather than a debounce, because crossing the full 120s range
/// from the ±5s fine window is the whole reason to hold a nudge button.
class LyricsTimingNudgeButton extends StatefulWidget {
  const LyricsTimingNudgeButton({
    super.key,
    required this.step,
    required this.onStep,
    required this.accent,
  });

  /// Seconds added per step. Negative moves the lyrics earlier.
  final double step;
  final VoidCallback onStep;
  final Color accent;

  /// Slower than a key-repeat on purpose: at 1s per step this crosses the whole
  /// 120s range in a few seconds of holding, and faster would overshoot past
  /// anything the user could then correct with the fine rung.
  static const Duration holdDelay = Duration(milliseconds: 320);
  static const Duration holdInterval = Duration(milliseconds: 70);

  @override
  State<LyricsTimingNudgeButton> createState() =>
      _LyricsTimingNudgeButtonState();
}

class _LyricsTimingNudgeButtonState extends State<LyricsTimingNudgeButton> {
  Timer? _initialDelay;
  Timer? _repeat;

  @override
  void dispose() {
    _stopRepeating();
    super.dispose();
  }

  void _stopRepeating() {
    _initialDelay?.cancel();
    _initialDelay = null;
    _repeat?.cancel();
    _repeat = null;
  }

  void _hold() {
    widget.onStep();
    _initialDelay = Timer(LyricsTimingNudgeButton.holdDelay, () {
      _repeat = Timer.periodic(LyricsTimingNudgeButton.holdInterval, (_) {
        if (mounted) widget.onStep();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.step.abs().toStringAsFixed(2);
    return Pressable(
      onTap: widget.onStep,
      onLongPressStart: (_) => _hold(),
      onLongPressEnd: (_) => _stopRepeating(),
      onLongPressCancel: _stopRepeating,
      haptic: PressHaptic.selection,
      pressedScale: 0.94,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: PlayerTokens.s2,
          vertical: PlayerTokens.s2,
        ),
        decoration: BoxDecoration(
          color: widget.accent.withValues(alpha: PlayerTokens.accentWash),
          borderRadius: PlayerTokens.brPill,
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            '${widget.step < 0 ? '-' : '+'}$label',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: widget.accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of nudge buttons for one direction.
class LyricsTimingNudgeRow extends StatelessWidget {
  const LyricsTimingNudgeRow({
    super.key,
    required this.steps,
    required this.onStep,
    required this.accent,
  });

  /// Seconds per button, in the order they should appear. All the same sign.
  final List<double> steps;
  final void Function(double step) onStep;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(width: PlayerTokens.s2),
          Expanded(
            child: LyricsTimingNudgeButton(
              step: steps[i],
              accent: accent,
              onStep: () => onStep(steps[i]),
            ),
          ),
        ],
      ],
    );
  }
}
