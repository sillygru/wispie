import 'package:flutter/material.dart';

import '../components/app_toast.dart';
import '../motion/motion.dart';
import '../tokens/app_tokens.dart';
import 'auto_backup_indicator.dart';
import 'external_open_banner.dart';
import 'metadata_save_indicator.dart';

/// The app's one feedback surface: every status bubble and every transient
/// message renders here, in a single column from the top of the window.
///
/// Mounted above the navigator (see `MaterialApp.builder`), so a message posted
/// by a screen that is already closing still lands. It also ends the
/// hand-tuned stacking the shell used to do with three fixed offsets, where two
/// bubbles up at once were drawn on top of each other.
class AppFeedbackHost extends StatelessWidget {
  const AppFeedbackHost({super.key});

  /// One rhythm for every bubble, so none of them carries its own outer padding.
  static const EdgeInsets _slotPadding = EdgeInsets.only(top: AppTokens.s2);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MotionPolicy.read(context).reduceMotion;

    Widget slot(Widget child) => Padding(padding: _slotPadding, child: child);

    // Align sizes to the window but only its children are hit-testable, so the
    // rest of the screen keeps its taps.
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        bottom: false,
        child: AnimatedSize(
          duration: reduceMotion ? Duration.zero : MotionTokens.fast,
          curve: MotionTokens.inOutCurve,
          alignment: Alignment.topCenter,
          // The toast slides in from above its own slot; clipping it here would
          // turn that entrance into a reveal.
          clipBehavior: Clip.none,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              slot(const MetadataSaveIndicator()),
              slot(const AutoBackupIndicator()),
              slot(const ExternalOpenBanner()),
              slot(const AppToastSlot()),
            ],
          ),
        ),
      ),
    );
  }
}
