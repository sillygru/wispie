import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/queue_item.dart';
import '../../models/song.dart';
import '../../services/audio_player_manager.dart';
import '../tokens/player_tokens.dart';
import 'pressable.dart';
import 'track_swipe_switcher.dart';

/// Play glyph that morphs into pause (and back) instead of swapping, with a
/// small squash at the midpoint so the change reads as a press response.
class PlayPauseMorphIcon extends StatefulWidget {
  final bool playing;
  final double size;
  final Color color;

  const PlayPauseMorphIcon({
    super.key,
    required this.playing,
    required this.size,
    required this.color,
  });

  @override
  State<PlayPauseMorphIcon> createState() => _PlayPauseMorphIconState();
}

class _PlayPauseMorphIconState extends State<PlayPauseMorphIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PlayerTokens.dBase,
    value: widget.playing ? 1 : 0,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );

  @override
  void didUpdateWidget(covariant PlayPauseMorphIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) {
      widget.playing ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double squash =
            1 - 0.14 * math.sin(math.pi * _controller.value.clamp(0.0, 1.0));
        return Transform.scale(scale: squash, child: child);
      },
      child: AnimatedIcon(
        icon: AnimatedIcons.play_pause,
        progress: _progress,
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}

/// The big accent play/pause disc. Reads [AudioPlayerManager.playingNotifier]
/// rather than the player stream so the glyph flips the instant it is tapped,
/// while the volume fade keeps running underneath.
class PlayPauseDisc extends StatelessWidget {
  final AudioPlayerManager audioManager;
  final Color accent;
  final double size;
  final double iconSize;

  const PlayPauseDisc({
    super.key,
    required this.audioManager,
    required this.accent,
    required this.size,
    this.iconSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    final Color onAccent = PlayerTokens.onAccent(accent);
    return Pressable(
      onTap: audioManager.togglePlayPause,
      pressedScale: 0.88,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: StreamBuilder<PlayerState>(
          stream: audioManager.player.playerStateStream,
          initialData: audioManager.player.playerState,
          builder: (context, snapshot) {
            final bool buffering =
                snapshot.data?.processingState == ProcessingState.buffering;
            return ValueListenableBuilder<bool>(
              valueListenable: audioManager.playingNotifier,
              builder: (context, playing, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    PlayPauseMorphIcon(
                      playing: playing,
                      size: iconSize,
                      color: onAccent,
                    ),
                    // Ring orbits the glyph instead of replacing it, so a
                    // brief buffer doesn't make the button flicker.
                    AnimatedOpacity(
                      opacity: buffering ? 1 : 0,
                      duration: PlayerTokens.dFast,
                      child: SizedBox(
                        width: size - PlayerTokens.s3,
                        height: size - PlayerTokens.s3,
                        child: buffering
                            ? CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: onAccent,
                              )
                            : null,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Skip glyph that slides out in the skip direction while a copy slides in
/// behind it, like a track changing hands.
class SkipButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;

  /// 1 slides right (next), -1 slides left (previous).
  final int direction;
  final VoidCallback? onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;
  final VoidCallback? onLongPressCancel;

  const SkipButton({
    super.key,
    required this.icon,
    required this.size,
    required this.color,
    required this.direction,
    this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onLongPressCancel,
  });

  @override
  State<SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<SkipButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PlayerTokens.dBase,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    TrackSwipeSwitcher.hint(widget.direction);
    _controller.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size;
    return Pressable(
      onTap: widget.onTap == null ? null : _handleTap,
      onLongPressStart: widget.onLongPressStart,
      onLongPressEnd: widget.onLongPressEnd,
      onLongPressCancel: widget.onLongPressCancel,
      pressedScale: 0.86,
      child: Padding(
        padding: const EdgeInsets.all(PlayerTokens.s3),
        child: SizedBox(
          width: s,
          height: s,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final double t =
                    Curves.easeInOutCubic.transform(_controller.value);
                final Widget glyph =
                    Icon(widget.icon, size: s, color: widget.color);
                if (t == 0 || t == 1) {
                  return AnimatedSwitcher(
                    duration: PlayerTokens.dBase,
                    switchInCurve: PlayerTokens.cSpring,
                    switchOutCurve: PlayerTokens.cStandard,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey<IconData>(widget.icon),
                      child: glyph,
                    ),
                  );
                }
                final double dx = widget.direction * s * 0.9;
                return Stack(
                  children: [
                    Transform.translate(
                      offset: Offset(dx * t, 0),
                      child: Opacity(opacity: 1 - t, child: glyph),
                    ),
                    Transform.translate(
                      offset: Offset(dx * (t - 1), 0),
                      child: Opacity(opacity: t, child: glyph),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Next button that becomes a fast-forward while held, with a sprung "2x"
/// badge and a gentle pulse for as long as the hold lasts.
class NextFastForwardButton extends StatefulWidget {
  final AudioPlayerManager audioManager;
  final bool canSkipNext;
  final double size;
  final Color color;
  final Color disabledColor;
  final Color accent;

  const NextFastForwardButton({
    super.key,
    required this.audioManager,
    required this.canSkipNext,
    required this.size,
    required this.color,
    required this.disabledColor,
    required this.accent,
  });

  @override
  State<NextFastForwardButton> createState() => _NextFastForwardButtonState();
}

class _NextFastForwardButtonState extends State<NextFastForwardButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _start() {
    widget.audioManager.startFastForward();
    _pulse.repeat(reverse: true);
  }

  void _stop() {
    widget.audioManager.stopFastForward();
    _pulse.animateTo(0, duration: PlayerTokens.dFast);
  }

  @override
  Widget build(BuildContext context) {
    final AudioPlayerManager m = widget.audioManager;
    return ValueListenableBuilder<bool>(
      valueListenable: m.fastForwardNotifier,
      builder: (context, ff, _) {
        final Color glyphColor = ff
            ? widget.accent
            : (widget.canSkipNext ? widget.color : widget.disabledColor);
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Transform.scale(
                scale: 1 + 0.08 * Curves.easeInOut.transform(_pulse.value),
                child: child,
              ),
              // One SkipButton throughout: swapping widgets mid-hold would
              // drop the long-press recognizer and strand fast-forward on.
              child: SkipButton(
                icon: ff ? Icons.fast_forward_rounded : Icons.skip_next_rounded,
                size: widget.size,
                color: glyphColor,
                direction: 1,
                onTap: widget.canSkipNext ? m.player.seekToNext : null,
                onLongPressStart: (_) => _start(),
                onLongPressEnd: (_) => _stop(),
                onLongPressCancel: _stop,
              ),
            ),
            Positioned(
              top: -6,
              child: IgnorePointer(
                child: AnimatedScale(
                  scale: ff ? 1 : 0.3,
                  duration: PlayerTokens.dBase,
                  curve: ff ? PlayerTokens.cSpring : PlayerTokens.cStandard,
                  child: AnimatedOpacity(
                    opacity: ff ? 1 : 0,
                    duration: PlayerTokens.dFast,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accent,
                        borderRadius: PlayerTokens.brPill,
                      ),
                      child: Text(
                        '2x',
                        style: TextStyle(
                          color: PlayerTokens.onAccent(widget.accent),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Repeat toggle: the arrows take a sprung turn on every change, the glyph
/// swaps with a pop, and a dot under it grows in while repeat is on.
class RepeatToggleButton extends StatefulWidget {
  final LoopMode loopMode;
  final Color accent;
  final Color idleColor;
  final ValueChanged<LoopMode> onChanged;

  const RepeatToggleButton({
    super.key,
    required this.loopMode,
    required this.accent,
    required this.idleColor,
    required this.onChanged,
  });

  @override
  State<RepeatToggleButton> createState() => _RepeatToggleButtonState();
}

class _RepeatToggleButtonState extends State<RepeatToggleButton> {
  double _turns = 0;

  @override
  void didUpdateWidget(covariant RepeatToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loopMode != widget.loopMode) _turns += 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final LoopMode mode = widget.loopMode;
    final bool on = mode != LoopMode.off;
    return Tooltip(
      message: switch (mode) {
        LoopMode.off => 'Repeat off',
        LoopMode.all => 'Repeat all',
        LoopMode.one => 'Repeat one',
      },
      child: Pressable(
        haptic: PressHaptic.selection,
        pressedScale: 0.85,
        onTap: () => widget.onChanged(switch (mode) {
          LoopMode.off => LoopMode.all,
          LoopMode.all => LoopMode.one,
          LoopMode.one => LoopMode.off,
        }),
        child: Padding(
          padding: const EdgeInsets.all(PlayerTokens.s2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedRotation(
                turns: _turns,
                duration: PlayerTokens.dSlow,
                curve: PlayerTokens.cSpring,
                child: AnimatedSwitcher(
                  duration: PlayerTokens.dBase,
                  switchInCurve: PlayerTokens.cSpring,
                  switchOutCurve: PlayerTokens.cStandard,
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: TweenAnimationBuilder<Color?>(
                    key: ValueKey<bool>(mode == LoopMode.one),
                    tween:
                        ColorTween(end: on ? widget.accent : widget.idleColor),
                    duration: PlayerTokens.dBase,
                    builder: (context, color, _) => Icon(
                      mode == LoopMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedScale(
                scale: on ? 1 : 0,
                duration: PlayerTokens.dBase,
                curve: on ? PlayerTokens.cSpring : PlayerTokens.cStandard,
                child: Container(
                  width: PlayerTokens.s1,
                  height: PlayerTokens.s1,
                  decoration: BoxDecoration(
                    color: widget.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rebuilds with whether the live queue is this collection (same set of
/// filenames, current song among them) and whether it is playing, so a
/// detail screen's Play button can turn into Pause for its own queue.
class CollectionPlaybackBuilder extends StatelessWidget {
  final AudioPlayerManager audioManager;
  final List<Song> songs;
  final Widget Function(BuildContext context, bool isCurrent, bool playing)
      builder;

  const CollectionPlaybackBuilder({
    super.key,
    required this.audioManager,
    required this.songs,
    required this.builder,
  });

  static bool matches(List<QueueItem> queue, Song? current, List<Song> songs) {
    if (current == null || songs.isEmpty || queue.length != songs.length) {
      return false;
    }
    final Set<String> wanted = {for (final s in songs) s.filename};
    if (!wanted.contains(current.filename)) return false;
    for (final item in queue) {
      if (!wanted.contains(item.song.filename)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        audioManager.queueNotifier,
        audioManager.currentSongNotifier,
        audioManager.playingNotifier,
      ]),
      builder: (context, _) => builder(
        context,
        matches(
          audioManager.queueNotifier.value,
          audioManager.currentSongNotifier.value,
          songs,
        ),
        audioManager.playingNotifier.value,
      ),
    );
  }
}

/// Plain icon action with a quick upward hop on tap.
class HopIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const HopIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<HopIconButton> createState() => _HopIconButtonState();
}

class _HopIconButtonState extends State<HopIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PlayerTokens.dSlow,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Pressable(
        haptic: PressHaptic.selection,
        pressedScale: 0.85,
        onTap: () {
          _controller.forward(from: 0);
          widget.onPressed();
        },
        child: Padding(
          padding: const EdgeInsets.all(PlayerTokens.s3),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(
                0,
                -PlayerTokens.s2 * math.sin(math.pi * _controller.value),
              ),
              child: child,
            ),
            child: Icon(widget.icon, color: widget.color),
          ),
        ),
      ),
    );
  }
}
