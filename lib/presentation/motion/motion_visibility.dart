import 'dart:async';

import 'package:flutter/widgets.dart';

/// Fades a child and drops hit-testing at zero. [killWhenHidden] also removes it
/// from the tree, for heavy children whose space need not be preserved.
class FadeIgnoreTransition extends StatelessWidget {
  const FadeIgnoreTransition({
    super.key,
    required this.opacity,
    required this.child,
    this.killWhenHidden = false,
  });

  final Animation<double> opacity;
  final Widget child;
  final bool killWhenHidden;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: opacity,
      child: child,
      builder: (context, child) {
        final double value = opacity.value.clamp(0.0, 1.0);
        if (value <= 0.001) {
          return killWhenHidden
              ? const SizedBox.shrink()
              : IgnorePointer(child: Opacity(opacity: 0, child: child));
        }
        return IgnorePointer(
          ignoring: value < 0.02,
          child: Opacity(opacity: value, child: child),
        );
      },
    );
  }
}

/// Defers heavy work until the enclosing route stops animating, so a decode or
/// analysis does not compete with the transition. Waiters complete on dispose.
mixin RouteSettledMixin<T extends StatefulWidget> on State<T> {
  final Set<Completer<void>> _pendingSettle = <Completer<void>>{};

  /// Resolves when the route is no longer animating (immediately if it already
  /// settled).
  Future<void> whenRouteSettled() {
    final Animation<double>? animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      return Future<void>.value();
    }

    final completer = Completer<void>();
    _pendingSettle.add(completer);

    void listener(AnimationStatus status) {
      if (status != AnimationStatus.completed &&
          status != AnimationStatus.dismissed) {
        return;
      }
      animation.removeStatusListener(listener);
      if (_pendingSettle.remove(completer) && !completer.isCompleted) {
        completer.complete();
      }
    }

    animation.addStatusListener(listener);
    return completer.future;
  }

  @override
  void dispose() {
    for (final completer in _pendingSettle) {
      if (!completer.isCompleted) completer.complete();
    }
    _pendingSettle.clear();
    super.dispose();
  }
}
