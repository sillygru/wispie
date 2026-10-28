import 'package:flutter/material.dart';

import '../tokens/app_tokens.dart';
import 'app_surface.dart';

/// Full-screen progress for a job that rewrites the library file by file.
///
/// Shared between the sweeps that work this way — bulk rename and batch
/// replace — because both need the same three things at once: how far along it
/// is, what it is doing right now, and a way to stop it. A job over removable
/// storage runs long enough that a silent wait reads as a frozen app, and a bar
/// that cannot be stopped is just a slower freeze.
///
/// The wording arrives from the caller: the two jobs describe their phases in
/// their own words, and a shared widget that invented sentences would be fixing
/// wording it does not own.
class BatchProgressOverlay extends StatelessWidget {
  const BatchProgressOverlay({
    super.key,
    required this.phase,
    required this.done,
    required this.total,
    required this.cancelRequested,
    required this.onCancel,
    required this.stoppingLabel,
    required this.waitingLabel,
    required this.cancelLabel,
    required this.counterLabel,
  });

  final String phase;
  final int done;
  final int total;
  final bool cancelRequested;
  final VoidCallback onCancel;

  /// Shown in place of [phase] once the user has asked to stop.
  final String stoppingLabel;

  /// Replaces the counter for single-step phases, where "1 of 1" says nothing.
  final String waitingLabel;

  final String cancelLabel;

  /// Progress as a phrase, e.g. "12 of 300".
  final String Function(int done, int total) counterLabel;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;

    return Positioned.fill(
      child: ColoredBox(
        color:
            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.92),
        child: Center(
          child: AppSurface(
            level: 2,
            depth: AppDepth.floating,
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            padding: const EdgeInsets.all(AppTokens.s5),
            child: SizedBox(
              width: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cancelRequested ? stoppingLabel : phase,
                    style: AppTokens.rowTitle(context),
                  ),
                  const SizedBox(height: AppTokens.s3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.rPill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppTokens.wellFill,
                    ),
                  ),
                  const SizedBox(height: AppTokens.s2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          total <= 1 ? waitingLabel : counterLabel(done, total),
                          style: AppTokens.rowSubtitle(context),
                        ),
                      ),
                      if (!cancelRequested)
                        TextButton(
                          onPressed: onCancel,
                          style: TextButton.styleFrom(
                            foregroundColor: AppTokens.fgSecondary,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(cancelLabel),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
