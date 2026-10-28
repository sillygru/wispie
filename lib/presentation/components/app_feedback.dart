import 'package:flutter/material.dart';

import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import 'app_icon.dart';
import 'app_toast.dart';

// The feedback vocabulary lives in [app_toast.dart] so the banner, the transient
// toast and the status indicators share one shape and one tone table; callers
// keep importing this file.
export 'app_toast.dart';

/// Shows a message in the app's single feedback surface, at the top of the
/// window.
///
/// The app had 118 raw `showSnackBar` calls, each free to style itself, plus a
/// separate top banner for statuses; this is the only entry point now, so tone,
/// shape, placement and motion live in one place.
void appSnack(
  BuildContext context,
  String message, {
  AppTone tone = AppTone.neutral,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  // A message from a screen that is already gone has nothing to show for.
  if (!context.mounted) return;
  AppToasts.instance.show(
    AppToast(
      message: message,
      tone: tone,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    ),
  );
}

/// Empty, error and "nothing here yet" states.
///
/// Home alone had three variations of icon + headline + body + button; this is
/// all of them.
class AppEmptyState extends StatelessWidget {
  final AppIconData icon;
  final String title;
  final String? message;

  final String? actionLabel;
  final AppIconData? actionIcon;
  final VoidCallback? onAction;

  final AppTone tone;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.tone = AppTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              icon,
              size: 56,
              color: tone == AppTone.neutral
                  ? AppTokens.fgTertiary
                  : tone.color(context),
            ),
            const SizedBox(height: AppTokens.s4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTokens.paneTitle(context),
            ),
            if (message != null) ...[
              const SizedBox(height: AppTokens.s2),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTokens.rowSubtitle(context),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: AppTokens.s5),
              if (actionIcon != null)
                FilledButton.icon(
                  onPressed: onAction,
                  icon: AppIcon(actionIcon!, size: 18),
                  label: Text(actionLabel!),
                )
              else
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The app's loading state. One spinner, one size, centred.
class AppLoading extends StatelessWidget {
  final String? message;

  const AppLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppTokens.s4),
            Text(message!, style: AppTokens.meta(context)),
          ],
        ],
      ),
    );
  }
}

/// A single number-and-label statistic, as used on Profile.
class AppStatTile extends StatelessWidget {
  final String label;
  final String value;
  final AppIconData? icon;

  const AppStatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          AppIcon(icon!,
              size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: AppTokens.s1),
        ],
        Text(value, style: AppTokens.stat(context)),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppTokens.sectionLabel(context),
        ),
      ],
    );
  }
}
