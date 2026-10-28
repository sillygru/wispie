import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../l10n/l10n.dart';
import '../motion/motion.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import 'app_icon.dart';

/// Severity of a transient message or status bubble. Replaces the
/// `Colors.blue.shade700` / `orange.shade800` / `green.shade700` /
/// `red.shade700` literals that the status indicators were using.
enum AppTone { neutral, info, success, warning, danger }

extension AppToneColor on AppTone {
  Color color(BuildContext context) => switch (this) {
        AppTone.neutral => Theme.of(context).colorScheme.primary,
        AppTone.info => AppTokens.info,
        AppTone.success => AppTokens.success,
        AppTone.warning => AppTokens.warning,
        AppTone.danger => AppTokens.danger,
      };
}

/// The glyph that carries [tone] when a caller does not pass its own.
AppIconData appToneIcon(AppTone tone) => switch (tone) {
      AppTone.success => AppIcons.checkCircle,
      AppTone.warning => AppIcons.warning,
      AppTone.danger => AppIcons.error,
      _ => AppIcons.info,
    };

/// One message for the top of the window.
@immutable
class AppToast {
  AppToast({
    required this.message,
    this.tone = AppTone.neutral,
    this.icon,
    this.busy = false,
    this.progress,
    this.actionLabel,
    this.onAction,
    this.duration = const Duration(seconds: 3),
  }) : id = _nextId++;

  static int _nextId = 0;

  final int id;
  final String message;
  final AppTone tone;
  final AppIconData? icon;

  /// Shows a spinner instead of the glyph, for in-flight work.
  final bool busy;

  /// Determinate progress, 0..1, drawn as a hairline under the pill.
  final double? progress;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// How long it holds before leaving on its own. [Duration.zero] keeps it
  /// until it is dismissed.
  final Duration duration;
}

/// The one place transient feedback goes through.
///
/// There is deliberately only ever one toast: a message that replaces the
/// current one is what the listener wants, and a stack of stale pills is how
/// feedback turns into noise. Every surface — snackbars, sync status, backup
/// results — renders here, so tone, shape and motion cannot drift apart.
class AppToasts {
  AppToasts._();

  static final AppToasts instance = AppToasts._();

  final ValueNotifier<AppToast?> current = ValueNotifier<AppToast?>(null);

  void show(AppToast toast) => current.value = toast;

  /// Identity, not id: a toast that was already replaced must not clear its
  /// successor when its own exit finishes.
  void dismiss(AppToast toast) {
    if (identical(current.value, toast)) current.value = null;
  }

  void clear() => current.value = null;
}

/// The status pill used for every floating message: metadata saves, auto
/// backup, external opens and the transient toasts.
class AppStatusBanner extends StatelessWidget {
  final String message;
  final AppTone tone;

  /// Shows a spinner in place of the icon, for in-flight work.
  final bool busy;

  final AppIconData? icon;

  /// Determinate progress, 0..1. Drawn as a hairline under the pill.
  final double? progress;

  /// Trailing text button, for the one follow-up a message can offer.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// When set, the pill carries a close button.
  final VoidCallback? onDismiss;

  final int maxLines;

  const AppStatusBanner({
    super.key,
    required this.message,
    this.tone = AppTone.neutral,
    this.busy = false,
    this.icon,
    this.progress,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final accent = tone.color(context);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppTokens.s4),
        padding: EdgeInsets.only(
          left: AppTokens.s4,
          right: onDismiss == null ? AppTokens.s4 : AppTokens.s1,
          top: AppTokens.s2,
          bottom: AppTokens.s2,
        ),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            accent.withValues(alpha: 0.16),
            Colors.black.withValues(alpha: 0.72),
          ),
          borderRadius: AppTokens.brPill,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                else
                  AppIcon(icon ?? appToneIcon(tone), size: 15, color: accent),
                const SizedBox(width: AppTokens.s2),
                Flexible(
                  child: Text(
                    message,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: AppTokens.meta(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(width: AppTokens.s2),
                  TextButton(
                    onPressed: onAction ?? () {},
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.s3,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(actionLabel!),
                  ),
                ],
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    tooltip: context.l10n.actionClose,
                    visualDensity: VisualDensity.compact,
                    icon: AppIcon(AppIcons.close, size: 15, color: accent),
                    padding: const EdgeInsets.all(AppTokens.s2),
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: AppTokens.s1 + 2),
              ClipRRect(
                borderRadius: AppTokens.brPill,
                child: SizedBox(
                  width: 140,
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 2,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The transient slot: one pill, entering from above, leaving upward.
///
/// Sits in the app's single feedback column, so it can never overlap a status
/// bubble it does not know about.
class AppToastSlot extends StatelessWidget {
  const AppToastSlot({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MotionPolicy.read(context).reduceMotion;

    return ValueListenableBuilder<AppToast?>(
      valueListenable: AppToasts.instance.current,
      builder: (context, toast, _) {
        return AnimatedSwitcher(
          duration: reduceMotion ? Duration.zero : MotionTokens.base,
          switchInCurve: MotionTokens.enterCurve,
          switchOutCurve: MotionTokens.exitCurve,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          transitionBuilder: (child, animation) {
            final move = CurvedAnimation(
              parent: animation,
              curve: reduceMotion
                  ? MotionTokens.linearCurve
                  : MotionTokens.softOvershootCurve,
              reverseCurve: MotionTokens.exitCurve,
            );
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: reduceMotion
                    ? MotionTokens.linearCurve
                    : MotionTokens.standardCurve,
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.7),
                  end: Offset.zero,
                ).animate(move),
                child: child,
              ),
            );
          },
          child: toast == null
              ? const SizedBox.shrink()
              : AppBannerDismiss(
                  key: ValueKey<int>(toast.id),
                  hold: toast.duration,
                  tapToDismiss: true,
                  onDismiss: () => AppToasts.instance.dismiss(toast),
                  child: AppStatusBanner(
                    message: toast.message,
                    tone: toast.tone,
                    icon: toast.icon,
                    busy: toast.busy,
                    progress: toast.progress,
                    maxLines: 2,
                    actionLabel: toast.actionLabel,
                    onAction: toast.onAction == null
                        ? null
                        : () {
                            AppToasts.instance.dismiss(toast);
                            toast.onAction!();
                          },
                  ),
                ),
        );
      },
    );
  }
}

/// Wraps a banner in the app's one dismissal behaviour: it follows the finger
/// upward, resists a downward pull, springs back if released short, and leaves
/// the screen the same way whatever dismissed it.
class AppBannerDismiss extends StatefulWidget {
  final Widget child;

  /// Called once the pill has finished leaving.
  final VoidCallback onDismiss;

  /// How long it holds before leaving on its own. [Duration.zero] keeps it up
  /// until it is dismissed.
  final Duration hold;

  /// A tap anywhere clears it. Off for status pills, where the message is worth
  /// reading and a stray tap should not hide it.
  final bool tapToDismiss;

  const AppBannerDismiss({
    super.key,
    required this.child,
    required this.onDismiss,
    this.hold = Duration.zero,
    this.tapToDismiss = false,
  });

  @override
  State<AppBannerDismiss> createState() => _AppBannerDismissState();
}

class _AppBannerDismissState extends State<AppBannerDismiss>
    with SingleTickerProviderStateMixin {
  /// Vertical offset, in logical pixels. Negative is off the top of the screen.
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );
  Timer? _hold;
  double _rawDrag = 0;

  /// How far the pill may travel up before it is gone.
  static const double _travel = 140;

  /// Downward pull is resisted: the pill belongs to the top edge and has nowhere
  /// to go down, so it leans rather than follows.
  static const double _downResistance = 0.22;

  @override
  void initState() {
    super.initState();
    _armHold();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _offset.dispose();
    super.dispose();
  }

  void _armHold() {
    _hold?.cancel();
    if (widget.hold <= Duration.zero) return;
    // A timeout is not a touch: no haptic for a pill that simply expired.
    _hold = Timer(widget.hold, () => _leave(haptic: false));
  }

  void _onDragStart(DragStartDetails details) {
    _hold?.cancel();
    _rawDrag = _offset.value;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _rawDrag += details.primaryDelta ?? 0;
    _offset.value = _rawDrag < 0
        ? _rawDrag.clamp(-_travel, 0.0)
        : (_rawDrag * _downResistance).clamp(0.0, 28.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_offset.value < -_travel * 0.35 || velocity < -420) {
      _leave(haptic: true);
      return;
    }
    // Short of the threshold it springs back and keeps its hold from where it
    // was released, so brushing past a pill does not lose the message.
    _offset.animateWith(
      SpringSimulation(MotionSprings.gentle, _offset.value, 0, velocity),
    );
    _rawDrag = 0;
    _armHold();
  }

  /// Leaves upward from wherever it is drawn, then reports the dismissal.
  Future<void> _leave({bool haptic = true}) async {
    _hold?.cancel();
    if (!mounted) return;
    final onDismiss = widget.onDismiss;
    if (haptic) MotionHaptics.selection();
    if (MotionPolicy.read(context).reduceMotion) {
      onDismiss();
      return;
    }
    await _offset.animateTo(
      -_travel,
      duration: MotionTokens.fast,
      curve: MotionTokens.exitCurve,
    );
    // A status pill can be removed by its own provider while it animates; the
    // dismissal callback closes over a state that is gone by then.
    if (!mounted) return;
    onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.tapToDismiss ? () => _leave() : null,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: _offset,
        builder: (context, child) {
          final travel = (-_offset.value / _travel).clamp(0.0, 1.0);
          return Transform.translate(
            offset: Offset(0, _offset.value),
            child: Opacity(opacity: 1 - travel, child: child),
          );
        },
        child: Semantics(
          liveRegion: true,
          container: true,
          child: widget.child,
        ),
      ),
    );
  }
}
