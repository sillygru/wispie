import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../motion/motion.dart';
import '../widgets/heart_context_menu.dart';
import 'song_actions.dart';

/// Heart toggle with a pop and an accent ring on favouriting. Tap toggles,
/// long-press opens the heart menu.
class FavoriteHeartButton extends ConsumerStatefulWidget {
  final String filename;
  final String title;
  final Color accent;
  final Color inactiveColor;
  final double iconSize;
  final double boxSize;

  const FavoriteHeartButton({
    super.key,
    required this.filename,
    required this.title,
    required this.accent,
    required this.inactiveColor,
    this.iconSize = 28,
    this.boxSize = 48,
  });

  @override
  ConsumerState<FavoriteHeartButton> createState() =>
      _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends ConsumerState<FavoriteHeartButton>
    with SingleTickerProviderStateMixin {
  /// The glyph's scale. A spring, not a keyframe timeline: tapping twice
  /// quickly retargets from where the heart is instead of restarting the pop
  /// from 1.0.
  late final SpringMorph<double> _pop = SpringMorph<double>(
    vsync: this,
    lerp: (a, b, t) => a + (b - a) * t,
    initial: 1,
    spring: MotionSprings.bouncy,
  );

  late final AnimationController _ringController = AnimationController(
    vsync: this,
    duration: MotionTokens.long,
  );
  late final Animation<double> _ringScale = Tween<double>(
    begin: 0.35,
    end: 1.9,
  ).animate(
    CurvedAnimation(
      parent: _ringController,
      curve: MotionTokens.emphasized,
    ),
  );
  late final Animation<double> _ringFade = Tween<double>(
    begin: 0.45,
    end: 0.0,
  ).animate(
    CurvedAnimation(
      parent: _ringController,
      curve: const Interval(0.0, 0.65),
    ),
  );

  bool _showRing = false;

  @override
  void dispose() {
    _pop.dispose();
    _ringController.dispose();
    super.dispose();
  }

  void _toggle() {
    final bool wasFavorite =
        ref.read(userDataProvider).isFavorite(widget.filename);
    MotionHaptics.medium();
    songActionToggleFavorite(
      context,
      ref,
      widget.filename,
      widget.title,
      showFeedback: false,
    );
    if (MotionPolicy.read(context).reduceMotion) return;

    _pop.jumpTo(0.82);
    _pop.retarget(
      1.0,
      spring: wasFavorite ? MotionSprings.snappy : MotionSprings.bouncy,
    );
    if (!wasFavorite) {
      _showRing = true;
      _ringController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isFavorite = ref.watch(
      userDataProvider.select((data) => data.isFavorite(widget.filename)),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      onLongPress: () {
        MotionHaptics.medium();
        showHeartContextMenu(
          context: context,
          ref: ref,
          songFilename: widget.filename,
          songTitle: widget.title,
        );
      },
      child: SizedBox(
        width: widget.boxSize,
        height: widget.boxSize,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _pop.progressListenable,
            _ringController,
          ]),
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                if (_showRing &&
                    _ringController.isAnimating &&
                    _ringFade.value > 0)
                  Transform.scale(
                    scale: _ringScale.value,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              widget.accent.withValues(alpha: _ringFade.value),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                Transform.scale(scale: _pop.value, child: child),
              ],
            );
          },
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: widget.iconSize,
            color: isFavorite ? widget.accent : widget.inactiveColor,
          ),
        ),
      ),
    );
  }
}
