import 'package:flutter/material.dart';

/// The app-wide backdrop.
///
/// A single solid fill in the scaffold colour. Radial cover-tinted blooms and a
/// vertical darkening wash were removed: they read as generic gradient haze
/// rather than as a surface, and the flat fill lets the colour blocks on top
/// carry the hierarchy the same way the setup flow does.
///
/// [colorOverride] and [intensity] are kept so existing call sites compile.
class AmbientLayer extends StatelessWidget {
  /// Ignored. Kept so callers that used to tint the bloom still compile.
  final Color? colorOverride;

  /// Ignored. Kept so callers that used to scale the bloom still compile.
  final double intensity;

  const AmbientLayer({
    super.key,
    this.colorOverride,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
  }
}

/// Wraps [child] over the [AmbientLayer]. Kept as the drop-in the root shell
/// uses; sub-screens reach for `AmbientScaffold` instead.
class AmbientBackground extends StatelessWidget {
  final Widget child;
  final Color? colorOverride;

  const AmbientBackground({
    super.key,
    required this.child,
    this.colorOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: AmbientLayer(colorOverride: colorOverride)),
        child,
      ],
    );
  }
}
