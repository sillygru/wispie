import 'package:flutter/widgets.dart';

/// Marks the mini player surface the player panel grows out of and lands back
/// into, so the panel can start from the bar's exact rect and corners.
class PlayerSheetOrigin extends StatefulWidget {
  /// Corner radius of the surface at rest.
  final double radius;

  final Widget child;

  const PlayerSheetOrigin({
    super.key,
    required this.radius,
    required this.child,
  });

  static final List<_PlayerSheetOriginState> _mounted = [];

  /// The origin in [ancestor]'s coordinates, or null when no mini player is on
  /// screen. The most recently mounted origin wins, which is the one drawn on
  /// top.
  static ({Rect rect, double radius})? resolveIn(RenderBox? ancestor) {
    if (ancestor == null || !ancestor.attached) return null;
    for (final state in _mounted.reversed) {
      final RenderObject? ro = state.context.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      final Rect rect = MatrixUtils.transformRect(
        ro.getTransformTo(ancestor),
        Offset.zero & ro.size,
      );
      if (!rect.isFinite || rect.isEmpty) continue;
      return (rect: rect, radius: state.widget.radius);
    }
    return null;
  }

  @override
  State<PlayerSheetOrigin> createState() => _PlayerSheetOriginState();
}

class _PlayerSheetOriginState extends State<PlayerSheetOrigin> {
  @override
  void initState() {
    super.initState();
    PlayerSheetOrigin._mounted.add(this);
  }

  @override
  void dispose() {
    PlayerSheetOrigin._mounted.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
