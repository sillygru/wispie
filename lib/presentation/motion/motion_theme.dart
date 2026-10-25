import 'package:flutter/widgets.dart';

import 'motion_policy.dart';
import 'motion_tokens.dart';

/// Blends one colour between targets. Linear on purpose: an eased colour spends
/// most of its time in the muddy middle of the blend. Reduced motion jumps.
class MotionColorLerp extends StatefulWidget {
  const MotionColorLerp({
    super.key,
    required this.color,
    required this.builder,
    this.duration = MotionTokens.theme,
    this.curve = MotionTokens.linearCurve,
  });

  final Color color;
  final Widget Function(BuildContext context, Color color) builder;
  final Duration duration;
  final Curve curve;

  @override
  State<MotionColorLerp> createState() => _MotionColorLerpState();
}

class _MotionColorLerpState extends State<MotionColorLerp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );

  late Color _from = widget.color;
  late Color _to = widget.color;
  late Color _shown = widget.color;

  @override
  void didUpdateWidget(MotionColorLerp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color == widget.color) return;
    final bool reduce = MotionPolicy.read(context).reduceMotion;
    _from = _shown;
    _to = widget.color;
    if (reduce) {
      _controller.stop();
      _controller.value = 1;
      _shown = widget.color;
      return;
    }
    _controller
      ..duration = widget.duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.value >= 1) {
          _shown = _to;
        } else {
          _shown = Color.lerp(
                  _from, _to, widget.curve.transform(_controller.value)) ??
              _to;
        }
        return widget.builder(context, _shown);
      },
    );
  }
}
