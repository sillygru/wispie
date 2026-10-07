import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Closes an open dropdown / popup menu when the user starts dragging outside
/// of it, the way a tap outside already does. Without this, trying to scroll
/// the page under an open menu just did nothing.
///
/// Install [observer] on the app navigator and wrap the app in
/// [PopupScrollDismiss].
class PopupScrollDismiss extends StatefulWidget {
  final Widget child;

  const PopupScrollDismiss({super.key, required this.child});

  static final PopupRouteObserver observer = PopupRouteObserver();

  @override
  State<PopupScrollDismiss> createState() => _PopupScrollDismissState();
}

class PopupRouteObserver extends NavigatorObserver {
  Route<dynamic>? top;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      top = route;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      top = previousRoute;

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(route, top)) top = previousRoute;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (identical(oldRoute, top)) top = newRoute;
  }
}

class _PopupScrollDismissState extends State<PopupScrollDismiss> {
  PopupRoute<dynamic>? _armedRoute;
  Offset? _downAt;

  static bool _isMenu(Route<dynamic>? route) =>
      route is PopupRoute &&
      route is! RawDialogRoute &&
      route is! ModalBottomSheetRoute &&
      route.barrierDismissible &&
      route.isCurrent;

  void _onDown(PointerDownEvent event) {
    _armedRoute = null;
    final Route<dynamic>? route = PopupScrollDismiss.observer.top;
    if (!_isMenu(route)) return;
    final PopupRoute<dynamic> menu = route as PopupRoute<dynamic>;
    // The menu's own subtree only hits where the menu is drawn; anywhere else
    // the barrier takes the pointer. Drags that start on the menu are left
    // alone so long menus can still scroll.
    final RenderObject? menuBox = menu.subtreeContext?.findRenderObject();
    final HitTestResult result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
    final bool onMenu = result.path.any((e) => identical(e.target, menuBox));
    if (onMenu) return;
    _armedRoute = menu;
    _downAt = event.position;
  }

  void _onMove(PointerMoveEvent event) {
    final PopupRoute<dynamic>? route = _armedRoute;
    final Offset? start = _downAt;
    if (route == null || start == null) return;
    if ((event.position - start).distance < kTouchSlop) return;
    _armedRoute = null;
    if (route.isCurrent) route.navigator?.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: (_) => _armedRoute = null,
      onPointerCancel: (_) => _armedRoute = null,
      child: widget.child,
    );
  }
}
