import 'package:flutter/material.dart';

import '../../../domain/services/lyrics_timing_offset.dart';
import '../../../l10n/l10n.dart';
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
    title: context.l10n.lyricsTimingTitle,
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
              Text(
                context.l10n.lyricsTimingRangeLabel,
                style: PlayerTokens.meta(context),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accent,
                  thumbColor: accent,
                  overlayColor:
                      accent.withValues(alpha: PlayerTokens.aTertiary),
                ),
                child: Slider(
                  value: LyricsTimingController.rangeWindow
                      .snap(controller.seconds),
                  min: LyricsTimingController.rangeWindow.lower,
                  max: LyricsTimingController.rangeWindow.upper,
                  divisions: LyricsTimingController.rangeWindow.divisions,
                  label: formatLyricsTimingOffset(
                    controller.seconds,
                    showUnit: true,
                  ),
                  onChanged: controller.dragRange,
                ),
              ),
              Text(
                context.l10n.lyricsTimingFineLabel,
                style: PlayerTokens.meta(context),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accent,
                  thumbColor: accent,
                  overlayColor:
                      accent.withValues(alpha: PlayerTokens.aTertiary),
                ),
                child: Slider(
                  value: controller.fineWindow.snap(controller.seconds),
                  min: controller.fineWindow.lower,
                  max: controller.fineWindow.upper,
                  divisions: controller.fineWindow.divisions,
                  label: formatLyricsTimingOffset(
                    controller.seconds,
                    showUnit: true,
                  ),
                  onChanged: controller.dragFine,
                  onChangeEnd: (_) => controller.commitFine(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.historyDayEarlier,
                    style: PlayerTokens.meta(context),
                  ),
                  Text(
                    context.l10n.lyricsTimingLater,
                    style: PlayerTokens.meta(context),
                  ),
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
                label: Text(context.l10n.lyricsTimingSyncToLine),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: PlayerTokens.onAccent(accent),
                ),
              ),
              const SizedBox(height: PlayerTokens.s2),
              TextButton(
                onPressed: controller.seconds == 0 ? null : controller.reset,
                child: Text(context.l10n.lyricsTimingReset),
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
      context.l10n.lyricsTimingSnapped(
        formatLyricsTimingOffset(controller.seconds, showUnit: true),
      ),
      tone: AppTone.success,
    );
  }
}
