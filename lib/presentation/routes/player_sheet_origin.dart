import 'package:flutter/widgets.dart';

/// Marks the mini player surface the player panel grows out of and lands back
/// into, so the panel can start from the bar's exact rect, corners and artwork
/// slot instead of the screen edge.
class PlayerSheetOrigin extends StatefulWidget {
  /// Corner radius of the surface at rest.
  final double radius;

  /// Where the artwork sits inside the surface, measured from its left edge and
  /// centred vertically. Defaults match the floating dock's bar.
  final double artInset;
  final double artSize;

  final Widget child;

  const PlayerSheetOrigin({
    super.key,
    required this.radius,
    this.artInset = 10,
    this.artSize = 44,
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
      final Offset topLeft =
          ancestor.globalToLocal(ro.localToGlobal(Offset.zero));
      return (rect: topLeft & ro.size, radius: state.widget.radius);
    }
    return null;
  }

  /// The artwork slot inside the origin surface, in the same coordinates.
  static Rect? artRectIn(RenderBox? ancestor) {
    if (ancestor == null || !ancestor.attached) return null;
    for (final state in _mounted.reversed) {
      final RenderObject? ro = state.context.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      final Offset topLeft =
          ancestor.globalToLocal(ro.localToGlobal(Offset.zero));
      final double size = state.widget.artSize.clamp(0.0, ro.size.shortestSide);
      return Rect.fromLTWH(
        topLeft.dx + state.widget.artInset,
        topLeft.dy + (ro.size.height - size) / 2,
        size,
        size,
      );
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
