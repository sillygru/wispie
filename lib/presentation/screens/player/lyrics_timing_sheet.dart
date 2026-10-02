import 'package:flutter/material.dart';

import '../../../domain/services/lyrics_timing_offset.dart';
import '../../components/app_feedback.dart';
import '../../components/app_sheet.dart';
import '../../tokens/player_tokens.dart';
import 'lyrics_timing_control.dart';

/// Opens the full timing surface.
///
/// The inline pill is a one-glance correction; this is where the offset actually
/// gets dialled in — a rung selector, a wide slider, exact nudges and the
/// playhead snap. Edits apply live against the music rather than on "Save",
/// because timing something by ear and then confirming is two passes over the
/// same judgement.
Future<void> showLyricsTimingSheet(
  BuildContext context, {
  required LyricsTimingController controller,
  required Color accent,
  required bool canSync,
  required Duration Function() playheadPosition,
  required Duration? Function() activeLineTime,
}) {
  return showAppSheet<void>(
    context,
    title: 'Lyric timing',
    builder: (context) => _LyricsTimingSheet(
      controller: controller,
      accent: accent,
      canSync: canSync,
      playheadPosition: playheadPosition,
      activeLineTime: activeLineTime,
    ),
  );
}

/// The sheet body.
///
/// Stateless on purpose: the offset lives in [LyricsTimingController], which
/// outlives this route. Holding a copy here would be a second source of truth
/// that the pill behind the barrier would never hear about.
class _LyricsTimingSheet extends StatelessWidget {
  const _LyricsTimingSheet({
    required this.controller,
    required this.accent,
    required this.canSync,
    required this.playheadPosition,
    required this.activeLineTime,
  });

  /// Grid steps the nudge rows offer, largest first.
  static const List<double> earlierSteps = [-1, -0.1, -0.01];
  static const List<double> laterSteps = [0.01, 0.1, 1];

  final LyricsTimingController controller;
  final Color accent;

  /// False for lyrics with no usable LRC stamps, which leaves nothing to snap.
  final bool canSync;
  final Duration Function() playheadPosition;
  final Duration? Function() activeLineTime;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final window = controller.window;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            PlayerTokens.s5,
            PlayerTokens.s2,
            PlayerTokens.s5,
            PlayerTokens.s5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: LyricsTimingReadout(
                  controller: controller,
                  showUnit: true,
                  style: Theme.of(context).textTheme.displaySmall!.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: PlayerTokens.s2),
              _RungSelector(
                precision: controller.precision,
                accent: accent,
                onChanged: controller.setPrecision,
              ),
              const SizedBox(height: PlayerTokens.s3),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accent,
                  thumbColor: accent,
                  overlayColor:
                      accent.withValues(alpha: PlayerTokens.aTertiary),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Earlier', style: PlayerTokens.meta(context)),
                  Text('Later', style: PlayerTokens.meta(context)),
                ],
              ),
              const SizedBox(height: PlayerTokens.s3),
              LyricsTimingNudgeRow(
                steps: earlierSteps,
                accent: accent,
                onStep: controller.nudge,
              ),
              const SizedBox(height: PlayerTokens.s2),
              LyricsTimingNudgeRow(
                steps: laterSteps,
                accent: accent,
                onStep: controller.nudge,
              ),
              const SizedBox(height: PlayerTokens.s4),
              FilledButton.icon(
                onPressed: canSync ? () => _syncHere(context) : null,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Sync to this line'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: PlayerTokens.onAccent(accent),
                ),
              ),
              const SizedBox(height: PlayerTokens.s2),
              TextButton(
                onPressed: controller.seconds == 0 ? null : controller.reset,
                child: const Text('Reset timing'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _syncHere(BuildContext context) {
    final synced = controller.syncTo(playheadPosition(), activeLineTime());
    if (!synced) return;
    appSnack(
      context,
      'Snapped to ${formatLyricsTimingOffset(controller.seconds, showUnit: true)}',
      tone: AppTone.success,
    );
  }
}

/// Rung picker.
///
/// Named by the range it shows rather than by an abstract level, because the
/// question a user is actually answering is "how far can this reach" and "how
/// fine can this move" at the same time.
class _RungSelector extends StatelessWidget {
  const _RungSelector({
    required this.precision,
    required this.accent,
    required this.onChanged,
  });

  final LyricsTimingPrecision precision;
  final Color accent;
  final void Function(LyricsTimingPrecision) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final rung in LyricsTimingPrecision.values) ...[
          Expanded(
            child: _RungOption(
              rung: rung,
              selected: rung == precision,
              accent: accent,
              onTap: () => onChanged(rung),
            ),
          ),
          if (rung != LyricsTimingPrecision.values.last)
            const SizedBox(width: PlayerTokens.s2),
        ],
      ],
    );
  }
}

class _RungOption extends StatelessWidget {
  const _RungOption({
    required this.rung,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final LyricsTimingPrecision rung;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? accent : Colors.white;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: PlayerTokens.dFast,
        curve: PlayerTokens.cStandard,
        padding: const EdgeInsets.symmetric(
          vertical: PlayerTokens.s2,
          horizontal: PlayerTokens.s1,
        ),
        decoration: BoxDecoration(
          // Selection is an accent fill, never an outline.
          color: selected
              ? accent.withValues(alpha: PlayerTokens.accentWash)
              : Colors.white.withValues(alpha: PlayerTokens.aTertiary),
          borderRadius: PlayerTokens.brSm,
        ),
        child: Column(
          children: [
            Text(
              rung.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: foreground,
              ),
            ),
            Text(
              '${rung.spanSeconds.round()}s',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: foreground.withValues(alpha: PlayerTokens.aSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
