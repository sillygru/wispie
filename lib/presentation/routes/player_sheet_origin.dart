import 'package:flutter/widgets.dart';

/// Marks the mini player surface the player sheet grows out of and lands back
/// into, so the sheet can start from the bar's exact rect and corners instead
/// of the screen edge.
class PlayerSheetOrigin extends StatefulWidget {
  final double radius;
  final Widget child;

  const PlayerSheetOrigin({
    super.key,
    required this.radius,
    required this.child,
  });

  static final List<_PlayerSheetOriginState> _mounted = [];

  /// The origin living on [below] (the route the player was pushed over), in
  /// [ancestor]'s coordinates. Null when that route has no mini player.
  static ({Rect rect, double radius})? resolve(
    Route<dynamic>? below,
    RenderBox? ancestor,
  ) {
    if (below == null || ancestor == null || !ancestor.attached) return null;
    for (final state in _mounted.reversed) {
      if (state._route != below) continue;
      final RenderObject? ro = state.context.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      final Offset topLeft =
          ancestor.globalToLocal(ro.localToGlobal(Offset.zero));
      return (rect: topLeft & ro.size, radius: state.widget.radius);
    }
    return null;
  }

  @override
  State<PlayerSheetOrigin> createState() => _PlayerSheetOriginState();
}

class _PlayerSheetOriginState extends State<PlayerSheetOrigin> {
  Route<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    PlayerSheetOrigin._mounted.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    PlayerSheetOrigin._mounted.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
