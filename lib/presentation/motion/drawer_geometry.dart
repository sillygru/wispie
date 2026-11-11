import 'progress_geometry.dart';

/// Positions the drawer and the page from the same drag progress.
class DrawerGeometry extends ProgressGeometry {
  DrawerGeometry(super.controller, {required double restWidth})
      : _restWidth = restWidth;

  double get restWidth => _restWidth;
  double _restWidth;

  double contentOffset = 0;
  double drawerOffset = 0;
  double contentScrim = 0;
  double drawerScrim = 0;

  void updateWidth(double restWidth) {
    if (restWidth == _restWidth) return;
    _restWidth = restWidth;
    refresh();
  }

  @override
  void layout(double progress) {
    contentOffset = restWidth * progress;
    drawerOffset = (contentOffset - restWidth) * 0.5;
    contentScrim = (progress * 0.57).clamp(0.0, 1.0);
    drawerScrim = ((1 - progress) * 0.85).clamp(0.0, 1.0);
  }
}
