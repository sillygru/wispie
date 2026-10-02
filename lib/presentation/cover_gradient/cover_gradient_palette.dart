import 'package:flutter/material.dart';

/// Clamped dominant color helpers for the cover-gradient screens.
///
/// The accent arrives already legibility-corrected from `selectAccent`
/// (lightness 0.62-0.78), which is right for buttons but far too bright for
/// a full-page background behind white text. These helpers derive a dark,
/// saturated variant for backgrounds while leaving the accent itself alone.
class CoverGradientPalette {
  const CoverGradientPalette._();

  /// Dark variant of [accent] that stays readable under white text.
  ///
  /// Keeps hue/saturation, clamps lightness to a dark band so light covers
  /// cannot wash the UI out. Neutral (grey) covers fall back to charcoal.
  static Color clampedBackground(Color accent, {bool isNeutral = false}) {
    if (isNeutral) return const Color(0xFF141414);
    final hsl = HSLColor.fromColor(accent);
    // Preserve vividness but force dark: light covers get pulled down,
    // already-dark covers stay where they are.
    final double lightness = hsl.lightness.clamp(0.0, 1.0);
    final double clamped = lightness <= 0.30 ? lightness : 0.22;
    // Floor saturation slightly so the wash still reads as the cover's hue.
    final double saturation = hsl.saturation.clamp(0.35, 0.85);
    return hsl
        .withLightness(clamped.clamp(0.12, 0.28))
        .withSaturation(saturation)
        .toColor();
  }

  /// Top-to-bottom wash for detail pages: tinted at the top, near-black
  /// at the bottom, with no hard break. Callers paint song rows directly
  /// on it.
  static List<Color> detailGradient(Color accent, {bool isNeutral = false}) {
    final dark = clampedBackground(accent, isNeutral: isNeutral);
    final top = Color.alphaBlend(dark.withValues(alpha: 0.92), Colors.black);
    final mid = Color.alphaBlend(dark.withValues(alpha: 0.55), Colors.black);
    return <Color>[top, mid, Colors.black];
  }

  /// Scrim behind floating header/tabs over artwork.
  static List<Color> topScrim() {
    return <Color>[
      Colors.black.withValues(alpha: 0.55),
      Colors.black.withValues(alpha: 0.0),
    ];
  }

  /// Fade from opaque cover into the blurred background. Must end in exactly
  /// the background color so there is no visible edge.
  static List<Color> coverFade(Color backgroundBottom) {
    return <Color>[
      backgroundBottom.withValues(alpha: 0.0),
      backgroundBottom,
    ];
  }
}
