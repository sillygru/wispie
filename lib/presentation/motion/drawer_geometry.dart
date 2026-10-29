import '../utils/wide_layout.dart';
import 'progress_geometry.dart';

/// Everything visual about the slide-in drawer, derived from one progress
/// value and recomputed once per tick.
///
/// The drawer used to do this arithmetic inline in two places: the shell sized
/// the scrim from the panel's width while the panel did its own width and
/// content math. Two copies of one formula drift, and they did — the scrim
/// dimmed part of the panel during the swell. Both leaves read this instead.
///
/// Free of widgets and providers on purpose: shadows, colours and the reduce
/// motion decision stay with the leaves.
class DrawerGeometry extends ProgressGeometry {
  DrawerGeometry(
    super.controller, {
    required double restWidth,
    this.allowOvershoot = true,
  }) : _restWidth = restWidth;

  /// The drawer's width at rest, fully open. The shell and the panel share it
  /// so they can never disagree about where the drawer's edge is.
  double get restWidth => _restWidth;
  double _restWidth;

  /// False drops the past-open swell, for a drawer that covers the shell and
  /// has nothing to swell over.
  final bool allowOvershoot;

  /// How far the panel's trailing edge has travelled from the window edge.
  double panelWidth = 0;

  /// How far the content is pushed. It follows the elastic swell, damped, so the
  /// crest shoves the page instead of the drawer becoming an overlay.
  double contentOffset = 0;

  static const double _contentFollow = 0.6;

  /// Swell past the resting width, as a fraction of it. Chrome deepens with it.
  double swellFraction = 0;

  /// The scrim's opacity input: the raw value, so the dim rides the drawer in
  /// and out under the finger the whole way, past open included.
  double scrimProgress = 0;

  /// Offset applied to the panel's content. Not a size change: the buttons lean
  /// into the swell and their layout never reflows.
  double contentDrift = 0;

  /// Set by the shell when the window changes; recomputes without waiting for
  /// the next frame.
  void updateWidth(double restWidth) {
    if (restWidth == _restWidth) return;
    _restWidth = restWidth;
    refresh();
  }

  @override
  void layout(double raw) {
    final double width = _restWidth;
    // Unbound and unwidthed is the startup state, not an error: the leaves read
    // zero and the drawer is closed until the first real width arrives.
    if (width <= 0) {
      panelWidth = 0;
      contentOffset = 0;
      contentDrift = 0;
      swellFraction = 0;
      scrimProgress = raw;
      return;
    }
    // Past open the panel does the growing, not the content: the trailing edge
    // walks out over the background and the content only leans.
    final double swell = allowOvershoot && raw > 1
        ? WideLayout.drawerStretch(width, raw - 1)
        : 0.0;
    final double drift = allowOvershoot && raw > 1
        ? WideLayout.drawerStretchAtRest(width, raw - 1) *
            WideLayout.drawerContentDrift
        : 0.0;
    final double reveal = width * raw.clamp(0.0, 1.0);
    panelWidth = reveal + swell;
    contentOffset = reveal + swell * _contentFollow;
    contentDrift = drift;
    swellFraction = swell / width;
    scrimProgress = raw;
  }
}
