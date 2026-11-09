import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../domain/services/panel_release.dart';
import '../../models/song.dart';
import '../tokens/player_tokens.dart';
import '../widgets/album_art_image.dart';

/// The pieces of the player that travel between the dock's bar and the full
/// player. Each one is drawn by both surfaces and flown by the panel.
///
/// The artwork is not here: its ends differ too much (an image cropped to a
/// small rounded square versus the pane's cover), so the panel draws the flight
/// itself. These are the transport controls, where both ends are the same
/// widget at two sizes.
enum PlayerMorphSlot {
  play,
  skipNext,
}

/// Which end of the transition an anchor sits on.
enum PlayerMorphSurface {
  /// The dock's mini player (or the wide bottom bar).
  bar,

  /// The player panel's own chrome.
  panel,
}

typedef PlayerCoverGeometry = ({Rect rect, PlayerCoverAnchor style, Size size});

/// The artwork's actual paint bounds and treatment at either end of a flight.
class PlayerCoverAnchor extends StatelessWidget {
  const PlayerCoverAnchor({
    super.key,
    required this.child,
    this.radius = 0,
    this.fit = BoxFit.cover,
    this.shadow = false,
    this.effect,
  });

  static final GlobalKey barKey = GlobalKey(debugLabel: 'mini player cover');
  static final GlobalKey panelKey = GlobalKey(debugLabel: 'full player cover');

  final Widget child;
  final double radius;
  final BoxFit fit;
  final bool shadow;
  final Widget Function(Widget child, double strength)? effect;

  static PlayerCoverGeometry? measure(GlobalKey key, RenderBox? ancestor) {
    final widget = key.currentWidget;
    final box = key.currentContext?.findRenderObject();
    if (widget is! PlayerCoverAnchor ||
        box is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        box.size.isEmpty ||
        ancestor == null ||
        !ancestor.attached) {
      return null;
    }
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(ancestor),
      Offset.zero & box.size,
    );
    if (!rect.isFinite || rect.isEmpty) return null;
    return (rect: rect, style: widget, size: box.size);
  }

  Widget decorate(
    Widget child, {
    required BorderRadius corners,
    double strength = 1,
  }) {
    final Widget clipped = corners == BorderRadius.zero
        ? child
        : ClipRRect(borderRadius: corners, child: child);
    final Widget artwork = effect?.call(clipped, strength) ?? clipped;
    if (!shadow) return artwork;
    const token = PlayerTokens.playerCoverShadow;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: corners,
        boxShadow: [
          token.copyWith(
              color: token.color.withValues(alpha: token.color.a * strength)),
        ],
      ),
      child: artwork,
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: PlayerMorph.coverStrength,
        child: RepaintBoundary(
          child: decorate(child, corners: BorderRadius.circular(radius)),
        ),
        builder: (context, strength, child) => RepaintBoundary(
          child: Opacity(opacity: 1 - strength, child: child),
        ),
      );
}

/// Reshapes the artwork's crop without stretching the image pixels.
class PlayerCoverFlight extends StatelessWidget {
  const PlayerCoverFlight({
    super.key,
    required this.song,
    required this.from,
    required this.to,
    required this.progress,
    required this.speed,
    required this.travel,
    required this.opacity,
  });

  final Song song;
  final PlayerCoverGeometry from;
  final PlayerCoverGeometry to;
  final double progress;
  final double speed;
  final double travel;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final double barInset = from.rect.center.dy - travel;
    final pose = PanelCoverMotion.pose(
      progress: progress,
      speed: speed,
      travel: travel,
      insetChange: to.rect.center.dy - barInset,
    );
    final double pull = pose.tension.abs();
    final double width =
        lerpDouble(from.rect.width, to.rect.width, pose.width)! *
            (1 - PlayerTokens.coverPullWidth * pull);
    final double height =
        lerpDouble(from.rect.height, to.rect.height, pose.height)! *
            (1 + PlayerTokens.coverPullHeight * pull);
    final double centerY = (1 - progress) * travel +
        lerpDouble(barInset, to.rect.center.dy, pose.inset)! -
        height * PlayerTokens.coverPullLead * pose.tension;
    final double radius = lerpDouble(
      from.style.radius * from.rect.shortestSide / from.size.shortestSide,
      to.style.radius * to.rect.shortestSide / to.size.shortestSide,
      pose.sideways,
    )!;
    final double cornerPull = PlayerTokens.coverPullCorners * pose.tension;
    return Positioned.fromRect(
      rect: Rect.fromCenter(
        center: Offset(
          lerpDouble(from.rect.center.dx, to.rect.center.dx, pose.sideways)!,
          centerY,
        ),
        width: width,
        height: height,
      ),
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: RepaintBoundary(
            child: to.style.decorate(
              AlbumArtImage(
                url: song.coverUrl ?? '',
                filename: song.filename,
                cacheVersion: song.mtime,
                width: to.size.width,
                height: to.size.height,
                memCacheWidth:
                    (to.size.width * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                fit: to.style.fit,
                fadeDuration: Duration.zero,
              ),
              corners: BorderRadius.vertical(
                top: Radius.circular(radius * (1 - cornerPull)),
                bottom: Radius.circular(radius * (1 + cornerPull)),
              ),
              strength: pose.sideways,
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks a widget as one end of a morph and hides it while it is in flight.
///
/// This replaces `Hero` for the player: the player is not a route, so there is
/// no flight overlay to hand a widget to. Both surfaces register their box, the
/// panel lerps between them, and the originals disappear for exactly as long as
/// the copy is travelling.
class PlayerMorphAnchor extends StatefulWidget {
  const PlayerMorphAnchor({
    super.key,
    required this.slot,
    required this.surface,
    required this.child,
  });

  final PlayerMorphSlot slot;
  final PlayerMorphSurface surface;
  final Widget child;

  @override
  State<PlayerMorphAnchor> createState() => PlayerMorphAnchorState();
}

class PlayerMorphAnchorState extends State<PlayerMorphAnchor> {
  @override
  void initState() {
    super.initState();
    PlayerMorph._register(this);
  }

  @override
  void dispose() {
    PlayerMorph._unregister(this);
    super.dispose();
  }

  Widget get child => widget.child;

  PlayerMorphSlot get slot => widget.slot;

  PlayerMorphSurface get surface => widget.surface;

  /// This anchor's box in [ancestor]'s coordinates, or null when it is not laid
  /// out yet.
  Rect? rectIn(RenderBox? ancestor) {
    final RenderObject? ro = context.findRenderObject();
    if (ancestor == null || ro is! RenderBox || !ro.attached || !ro.hasSize) {
      return null;
    }
    return ancestor.globalToLocal(ro.localToGlobal(Offset.zero)) & ro.size;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PlayerMorph.visibility,
      child: widget.child,
      builder: (context, child) {
        final double faded = PlayerMorph.flying.value.contains(widget.slot)
            ? PlayerMorph.strength.value.clamp(0.0, 1.0)
            : 0.0;
        // The fade changes every frame of a flight; its own boundary keeps
        // that repaint on this glyph instead of the whole player page.
        return RepaintBoundary(
          child: IgnorePointer(
            ignoring: faded > 0.5,
            child: Opacity(opacity: 1 - faded, child: child),
          ),
        );
      },
    );
  }
}

/// The registry both ends of the transition talk to.
abstract final class PlayerMorph {
  static final Map<String, PlayerMorphAnchorState> _anchors = {};

  /// Slots in flight. Both ends fade out while their slot is here.
  static final ValueNotifier<Set<PlayerMorphSlot>> flying =
      ValueNotifier<Set<PlayerMorphSlot>>(const <PlayerMorphSlot>{});

  /// How much of the flight the shuttles own, 0..1. The ends are only faded by
  /// this much, so the hand-off on the first and last frame is a crossfade on
  /// aligned boxes rather than a swap.
  static final ValueNotifier<double> strength = ValueNotifier<double>(0);
  static final ValueNotifier<double> coverStrength = ValueNotifier<double>(0);

  /// One listenable for "is this slot faded, and how far" so an anchor can
  /// rebuild for either signal without nesting builders.
  static final Listenable visibility = Listenable.merge([flying, strength]);

  static String _key(PlayerMorphSlot slot, PlayerMorphSurface surface) =>
      '${surface.name}.${slot.name}';

  static void _register(PlayerMorphAnchorState state) {
    _anchors[_key(state.slot, state.surface)] = state;
  }

  static void _unregister(PlayerMorphAnchorState state) {
    final String key = _key(state.slot, state.surface);
    if (_anchors[key] == state) _anchors.remove(key);
  }

  static PlayerMorphAnchorState? anchorOf(
    PlayerMorphSlot slot,
    PlayerMorphSurface surface,
  ) =>
      _anchors[_key(slot, surface)];

  static void setFlying(Iterable<PlayerMorphSlot> slots) {
    final Set<PlayerMorphSlot> next = slots.toSet();
    if (setEquals(next, flying.value)) return;
    flying.value = next;
  }

  static void clear() => setFlying(const <PlayerMorphSlot>{});
}
