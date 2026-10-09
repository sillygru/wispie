import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// The bottom bar's progress hairline. Passive by default; with [interactive]
/// set it seeks — press to jump there, drag to scrub.
class BarSeekTrack extends StatefulWidget {
  final AudioPlayer player;
  final Color accent;
  final Color trackColor;

  /// Resting line thickness.
  final double thickness;

  /// Whether a pointer can seek on it.
  final bool interactive;

  /// Off when the bar is off-screen or the window is in the background.
  final bool live;

  const BarSeekTrack({
    super.key,
    required this.player,
    required this.accent,
    required this.trackColor,
    this.thickness = 2,
    this.interactive = false,
    this.live = true,
  });

  @override
  State<BarSeekTrack> createState() => _BarSeekTrackState();
}

class _BarSeekTrackState extends State<BarSeekTrack> {
  double _played = 0;
  double? _drag;
  double _width = 1;
  StreamSubscription<Duration>? _sub;

  @override
  void initState() {
    super.initState();
    _played = _fractionOf(widget.player.position);
    _listen();
  }

  @override
  void didUpdateWidget(BarSeekTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live != widget.live) _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _listen() {
    _sub?.cancel();
    _sub = widget.live
        ? widget.player.positionStream.listen((p) {
            final double next = _fractionOf(p);
            if (next != _played) setState(() => _played = next);
          })
        : null;
  }

  double _fractionOf(Duration position) {
    final Duration? total = widget.player.duration;
    if (total == null || total.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  void _seekTo(double fraction) {
    final Duration? total = widget.player.duration;
    if (total == null || total.inMilliseconds <= 0) return;
    widget.player.seek(
      Duration(
        milliseconds: (fraction.clamp(0.0, 1.0) * total.inMilliseconds).round(),
      ),
    );
  }

  /// Fraction under [dx], or null before the band is measured.
  double? _at(double dx) => _width > 0 ? (dx / _width).clamp(0.0, 1.0) : null;

  /// Moves the head under the pointer without seeking.
  void _preview(double dx) {
    final double? fraction = _at(dx);
    if (fraction != null) setState(() => _drag = fraction);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        final double? drag = _drag;
        final double played = drag ?? _played;
        // Thicker under the finger, so the drag reads as a grab.
        final double thickness = widget.thickness + (drag != null ? 1.5 : 0);
        final double head = thickness * 1.6;

        // Bottom-aligned: the band above the line is hit area.
        final Widget line = RepaintBoundary(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: thickness,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.trackColor,
                        borderRadius: BorderRadius.circular(thickness),
                      ),
                    ),
                  ),
                  // Positioned rather than a FractionallySizedBox: the box
                  // hands its child the incoming height, and a childless
                  // DecoratedBox sizes to zero, so the fill never painted.
                  if (played > 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: constraints.maxWidth * played,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: widget.accent,
                          borderRadius: BorderRadius.circular(thickness),
                        ),
                      ),
                    ),
                  // At rest the fill already shows position.
                  if (drag != null)
                    Positioned(
                      left: (constraints.maxWidth * played - head / 2)
                          .clamp(0.0, constraints.maxWidth - head),
                      width: head,
                      height: head,
                      child: DecoratedBox(
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

        if (!widget.interactive) return line;

        return Semantics(
          slider: true,
          label: 'Seek',
          child: MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // A press seeks at once; a drag only previews until release.
              onTapDown: (d) {
                final double? f = _at(d.localPosition.dx);
                if (f == null) return;
                setState(() => _drag = f);
                _seekTo(f);
              },
              onTapUp: (_) => setState(() => _drag = null),
              onTapCancel: () => setState(() => _drag = null),
              onHorizontalDragStart: (d) => _preview(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => _preview(d.localPosition.dx),
              onHorizontalDragEnd: (_) {
                final double? f = _drag;
                setState(() => _drag = null);
                if (f != null) _seekTo(f);
              },
              child: line,
            ),
          ),
        );
      },
    );
  }
}
