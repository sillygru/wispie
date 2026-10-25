import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
        return IgnorePointer(
          ignoring: faded > 0.5,
          child: Opacity(opacity: 1 - faded, child: child),
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
