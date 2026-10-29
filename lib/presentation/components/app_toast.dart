import 'dart:async';
import 'dart:math' as math;

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

/// The popup at the top of the window, shared by every floating message:
/// metadata saves, auto backup, external opens and the transient toasts.
class AppStatusBanner extends StatefulWidget {
  final String message;
  final AppTone tone;

  /// Shows a spinner in place of the icon, for in-flight work.
  final bool busy;

  final AppIconData? icon;

  /// Determinate progress, 0..1. Drawn as a bar under the message.
  final double? progress;

  /// Trailing button, for the one follow-up a message can offer.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// When set, the popup carries a close button.
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
    this.maxLines = 2,
  });

  @override
  State<AppStatusBanner> createState() => _AppStatusBannerState();
}

class _AppStatusBannerState extends State<AppStatusBanner>
    with SingleTickerProviderStateMixin {
  /// Arrival, 0..1. The spring is allowed to crest past 1.
  late final AnimationController _enter =
      AnimationController.unbounded(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MotionPolicy.read(context).reduceMotion) {
      _enter.value = 1;
    } else {
      _enter.animateWith(SpringSimulation(MotionSprings.bannerIn, 0, 1, 0));
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.tone.color(context);
    final canvas = Theme.of(context).scaffoldBackgroundColor;
    // Opaque on purpose: a translucent popup smears the list moving behind it.
    final fill = Color.alphaBlend(
      accent.withValues(alpha: AppTokens.popupTintAlpha),
      Color.alphaBlend(
        Colors.black.withValues(alpha: AppTokens.popupScrimAlpha),
        canvas,
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTokens.popupMaxWidth),
        child: AnimatedBuilder(
          animation: _enter,
          builder: (context, child) {
            final t = _enter.value;
            return Opacity(
              opacity: (t / 0.6).clamp(0.0, 1.0),
              child: FractionalTranslation(
                translation: Offset(0, -(1 - t)),
                child: Transform.scale(
                  scale: 0.94 + 0.06 * t,
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppTokens.s3),
            constraints: const BoxConstraints(
              minHeight: AppTokens.popupMinHeight,
            ),
            padding: const EdgeInsets.all(AppTokens.s3),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: AppTokens.brSm,
              boxShadow: AppTokens.shadowFloating,
            ),
            child: Row(
              children: [
                _tile(accent),
                const SizedBox(width: AppTokens.s3),
                Expanded(child: _body(context, accent)),
                if (widget.actionLabel != null || widget.onDismiss != null) ...[
                  const SizedBox(width: AppTokens.s2),
                  _trailing(context, accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(Color accent) {
    return Container(
      width: AppTokens.popupTileSize,
      height: AppTokens.popupTileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: AppTokens.popupTileAlpha),
        borderRadius: AppTokens.brSm,
      ),
      child: widget.busy
          ? SizedBox(
              width: AppTokens.iconSm,
              height: AppTokens.iconSm,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            )
          : AppIcon(
              widget.icon ?? appToneIcon(widget.tone),
              size: AppTokens.iconMd,
              color: accent,
            ),
    );
  }

  Widget _body(BuildContext context, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.message,
          maxLines: widget.maxLines,
          overflow: TextOverflow.ellipsis,
          style: AppTokens.rowTitle(context),
        ),
        if (widget.progress != null) ...[
          const SizedBox(height: AppTokens.s2),
          ClipRRect(
            borderRadius: AppTokens.brPill,
            child: LinearProgressIndicator(
              value: widget.progress!.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ],
    );
  }

  Widget _trailing(BuildContext context, Color accent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.actionLabel != null)
          FilledButton(
            onPressed: widget.onAction ?? () {},
            style: FilledButton.styleFrom(
              backgroundColor: accent.withValues(alpha: 0.18),
              foregroundColor: accent,
              textStyle:
                  AppTokens.meta(context).copyWith(fontWeight: FontWeight.w700),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.s3),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: AppTokens.brPill),
            ),
            child: Text(widget.actionLabel!),
          ),
        if (widget.onDismiss != null)
          IconButton(
            onPressed: widget.onDismiss,
            tooltip: context.l10n.actionClose,
            visualDensity: VisualDensity.compact,
            icon: AppIcon(
              AppIcons.close,
              size: AppTokens.iconSm,
              color: AppTokens.fgSecondary,
            ),
            padding: const EdgeInsets.all(AppTokens.s1),
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }
}

/// Holds a popup until its exit finishes, so a status that clears is a fade
/// rather than a cut. The banner itself owns the arrival.
class AppPopupSlot extends StatefulWidget {
  /// Null when there is nothing to show.
  final Widget? child;

  const AppPopupSlot({super.key, required this.child});

  @override
  State<AppPopupSlot> createState() => _AppPopupSlotState();
}

class _AppPopupSlotState extends State<AppPopupSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: MotionTokens.exit,
    value: 1,
  );
  Widget? _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.child;
  }

  @override
  void didUpdateWidget(AppPopupSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != null) {
      _shown = widget.child;
      _exit.value = 1;
      return;
    }
    if (_shown == null) return;
    if (MotionPolicy.read(context).reduceMotion) {
      _shown = null;
      return;
    }
    _exit.reverse().whenComplete(() {
      if (mounted && widget.child == null) setState(() => _shown = null);
    });
  }

  @override
  void dispose() {
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _shown;
    if (child == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _exit,
      builder: (context, child) {
        // 0 at rest, 1 once it is gone.
        final t = MotionTokens.emphasizedAccel.transform(1 - _exit.value);
        return Opacity(
          opacity: 1 - t,
          child: Transform.translate(offset: Offset(0, -18 * t), child: child),
        );
      },
      child: child,
    );
  }
}

/// The transient slot: one popup, arriving from above and leaving upward.
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
          // The card springs itself in, so a replacement only cross-fades.
          duration: reduceMotion ? Duration.zero : MotionTokens.micro,
          switchInCurve: MotionTokens.standardCurve,
          switchOutCurve: MotionTokens.linearCurve,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
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
/// upward, leans under a downward pull, springs back if released short, and
/// leaves on a spring whatever dismissed it.
class AppBannerDismiss extends StatefulWidget {
  final Widget child;

  /// Called once the popup has finished leaving.
  final VoidCallback onDismiss;

  /// How long it holds before leaving on its own. [Duration.zero] keeps it up
  /// until it is dismissed.
  final Duration hold;

  /// A tap anywhere clears it. Off for status messages, where a stray tap
  /// should not hide something worth reading.
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

  /// How far up it goes before it is gone.
  static const double _travel = 160;

  /// Downward pull asymptotes here: it belongs to the top edge, so it leans.
  static const double _downRoom = 26;

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
    // A timeout is not a touch: no haptic for a popup that simply expired.
    _hold = Timer(widget.hold, () => _leave(haptic: false));
  }

  void _onDragStart(DragStartDetails details) {
    _hold?.cancel();
    _rawDrag = _offset.value;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _rawDrag += details.primaryDelta ?? 0;
    _offset.value = _rawDrag < 0
        ? math.max(_rawDrag, -_travel)
        : _downRoom * (1 - math.exp(-_rawDrag / _downRoom));
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_offset.value < -_travel * 0.28 || velocity < -380) {
      _leave(haptic: true);
      return;
    }
    // Short of the threshold it springs back and keeps its hold from where it
    // was released, so brushing past a popup does not lose the message.
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
    // A spring, not a timed slide: a flick keeps its momentum, and the
    // dismissal is never a cut.
    await _offset.animateWith(
      SpringSimulation(
        MotionSprings.bannerOut,
        _offset.value,
        -_travel,
        _offset.velocity,
      ),
    );
    // A status popup can be removed by its own provider while it animates; the
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
            child: Opacity(
              opacity: 1 - MotionTokens.emphasizedAccel.transform(travel),
              child: Transform.scale(
                scale: 1 - 0.05 * travel,
                alignment: Alignment.topCenter,
                child: child,
              ),
            ),
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
