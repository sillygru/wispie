import 'package:flutter/material.dart';

import '../tokens/player_tokens.dart';
import '../widgets/album_art_image.dart';
import 'cover_gradient_palette.dart';

/// Heavily blurred, darkened cover-art background for cover-gradient screens.
///
/// The cover is decoded tiny (48px) and upscaled with low filter quality, so
/// the upscale itself is the blur — no ImageFiltered kernel runs at all. The
/// previous sigma-70 ImageFiltered ran a ~140px kernel over the full screen on
/// every frame it composited, the most expensive single blur in the app. Under
/// the dark wash below, the upscale is visually identical. Track changes
/// crossfade over ~500ms.
class CoverBlurBackground extends StatelessWidget {
  final String coverUrl;
  final String filename;
  final Color accent;
  final bool isNeutral;

  const CoverBlurBackground({
    super.key,
    required this.coverUrl,
    required this.filename,
    required this.accent,
    this.isNeutral = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color dark = CoverGradientPalette.clampedBackground(
      accent,
      isNeutral: isNeutral,
    );
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _BlurLayer(
          key: ValueKey<String>('cover_blur_$filename'),
          coverUrl: coverUrl,
          filename: filename,
          dark: dark,
          accent: accent,
          isNeutral: isNeutral,
        ),
      ),
    );
  }
}

class _BlurLayer extends StatelessWidget {
  final String coverUrl;
  final String filename;
  final Color dark;
  final Color accent;
  final bool isNeutral;

  const _BlurLayer({
    super.key,
    required this.coverUrl,
    required this.filename,
    required this.dark,
    required this.accent,
    required this.isNeutral,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Cover decoded tiny and upscaled: the upscale is the blur, at the
        // cost of one small decode rather than a full-screen 140px kernel.
        Positioned.fill(
          child: AlbumArtImage(
            url: coverUrl,
            filename: filename,
            fit: BoxFit.cover,
            memCacheWidth: 48,
            memCacheHeight: 48,
            filterQuality: FilterQuality.low,
          ),
        ),
        // Darken + saturate with the dominant color. Two stops keep it
        // luminous near the cover fade and near-black at the bottom.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color.alphaBlend(
                    dark.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.55),
                  ),
                  Color.alphaBlend(
                    dark.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.88),
                  ),
                  Colors.black.withValues(alpha: 0.94),
                ],
                stops: const <double>[0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        // Subtle accent glow near the top so the page still feels tinted
        // by the artwork without ever getting bright.
        if (!isNeutral)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.6),
                  radius: 0.9,
                  colors: <Color>[
                    accent.withValues(alpha: 0.18),
                    accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Translucent floating bar background for headers over scrolling content.
///
/// A solid fill rather than a live blur, on the same reasoning as the player
/// glass: the backdrop is already blurred, so a BackdropFilter only added a
/// saveLayer.
///
/// Kept separate from the player tokens glass recipe on purpose: the legacy
/// screens must not change, so this variant carries its own small helper.
class TranslucentBar extends StatelessWidget {
  final Widget child;

  const TranslucentBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      child: child,
    );
  }
}

/// Horizontal padding shared by the info block and controls.
class ContentGutter extends StatelessWidget {
  final Widget child;

  const ContentGutter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final double side = WideLayoutGutter.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: side),
      child: child,
    );
  }
}

class WideLayoutGutter {
  static double of(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    // Narrow phones get tighter gutters; desktop keeps breathing room.
    if (width < 380) return PlayerTokens.s3;
    if (width < 600) return PlayerTokens.s5;
    return PlayerTokens.s6;
  }
}
