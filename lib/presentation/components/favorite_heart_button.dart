import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
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
  late final AnimationController _controller;
  late final Animation<double> _pop;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringFade;
  bool _showRing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _pop = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.78)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.78, end: 1.32)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.32, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 56,
      ),
    ]).animate(_controller);
    _ringScale = Tween<double>(begin: 0.35, end: 1.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );
    _ringFade = Tween<double>(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.65)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    final bool wasFavorite =
        ref.read(userDataProvider).isFavorite(widget.filename);
    HapticFeedback.mediumImpact();
    songActionToggleFavorite(
      context,
      ref,
      widget.filename,
      widget.title,
      showFeedback: false,
    );
    _showRing = !wasFavorite;
    _controller.forward(from: 0);
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
        HapticFeedback.mediumImpact();
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
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                if (_showRing && _controller.isAnimating && _ringFade.value > 0)
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
