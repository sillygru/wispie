import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/spectrum_bars.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../../services/waveform_service.dart';
import '../tokens/player_tokens.dart';
import 'spectrum_controller.dart';
import 'waveform_progress_bar.dart';

/// A sound-reactive progress bar driven by the offline beat analysis pipeline
/// and real-time [SpectrumController].
///
/// Combines the full track waveform peaks with live frequency response across
/// 4 bands (bass, lowMid, mid, air) and beat dynamics.
class ReactiveWaveformProgressBar extends ConsumerStatefulWidget {
  final String filename;
  final String path;
  final Duration progress;
  final Duration total;
  final Function(Duration) onSeek;
  final Stream<Duration>? positionStream;

  const ReactiveWaveformProgressBar({
    super.key,
    required this.filename,
    required this.path,
    required this.progress,
    required this.total,
    required this.onSeek,
    this.positionStream,
  });

  @override
  ConsumerState<ReactiveWaveformProgressBar> createState() =>
      _ReactiveWaveformProgressBarState();
}

class _ReactiveWaveformProgressBarState
    extends ConsumerState<ReactiveWaveformProgressBar>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  SpectrumController? _spectrumController;
  bool _subscribedToSpectrum = false;

  List<double>? _peaks;
  late AnimationController _revealController;
  late AnimationController _scrubController;
  late Animation<double> _scrubAnimation;
  Duration _dragOriginDuration = Duration.zero;
  final ValueNotifier<int?> _scrubDeltaNotifier = ValueNotifier<int?>(null);

  double? _dragPosition;
  int? _lastHapticBarIndex;
  StreamSubscription<Duration>? _positionSubscription;
  DateTime? _lastPositionUpdate;
  final ValueNotifier<Duration> _positionNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<double?> _dragPositionNotifier = ValueNotifier(null);
  String _formattedTotalTime = '';
  int _loadToken = 0;
  StreamSubscription<List<double>>? _waveformSubscription;
  TextStyle? _labelStyle;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appActive = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _formattedTotalTime = _formatDuration(widget.total);
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 0.0,
    );
    _scrubController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 0.0,
    );
    _scrubAnimation = CurvedAnimation(
      parent: _scrubController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleWaveformLoad();
    });
    _subscribeToPositionStream();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _spectrumController ??= ref.read(spectrumControllerProvider);
    _syncSpectrumSubscription();
  }

  void _syncSpectrumSubscription() {
    final active =
        TickerMode.valuesOf(context).enabled && _appActive && mounted;
    if (_subscribedToSpectrum == active) return;
    _subscribedToSpectrum = active;
    final controller = _spectrumController;
    if (controller == null) return;
    if (active) {
      controller.addListener(_onSpectrumFrame);
    } else {
      controller.removeListener(_onSpectrumFrame);
    }
  }

  void _onSpectrumFrame() {
    // CustomPainter handles repainting via Listenable; subscription ensures
    // SpectrumController ticker keeps ticking while visible.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_subscribedToSpectrum) {
      _spectrumController?.removeListener(_onSpectrumFrame);
      _subscribedToSpectrum = false;
    }
    _waveformSubscription?.cancel();
    _loadToken++;
    _revealController.dispose();
    _scrubController.dispose();
    _scrubDeltaNotifier.dispose();
    _positionSubscription?.cancel();
    _positionNotifier.dispose();
    _dragPositionNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appActive == active) return;
    _appActive = active;
    _syncSpectrumSubscription();
    if (active) {
      _positionSubscription?.resume();
      final player = ref.read(audioPlayerManagerProvider).player;
      _positionNotifier.value = player.position;
    } else {
      _positionSubscription?.pause();
    }
  }

  void _subscribeToPositionStream() {
    _positionSubscription?.cancel();
    if (widget.positionStream == null) return;

    _positionSubscription = widget.positionStream!.listen((position) {
      if (!_appActive) return;
      final now = DateTime.now();
      if (_lastPositionUpdate == null ||
          now.difference(_lastPositionUpdate!).inMilliseconds > 200) {
        _lastPositionUpdate = now;
        _positionNotifier.value = position;
      }
    });

    if (!_appActive) {
      _positionSubscription?.pause();
    }
  }

  @override
  void didUpdateWidget(ReactiveWaveformProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filename != widget.filename) {
      _loadToken++;
      _waveformSubscription?.cancel();
      _waveformSubscription = null;
      _positionNotifier.value = Duration.zero;
      _labelStyle = null;
      _peaks = null;
      _revealController.stop();
      _revealController.value = 0.0;

      _scheduleWaveformLoad();
    }

    if (oldWidget.total != widget.total) {
      _formattedTotalTime = _formatDuration(widget.total);
    }

    if (oldWidget.positionStream != widget.positionStream) {
      _subscribeToPositionStream();
    }
  }

  Future<void> _scheduleWaveformLoad() async {
    if (widget.filename.isEmpty || widget.path.isEmpty) return;

    final currentFilename = widget.filename;
    final token = ++_loadToken;
    final waveformService = ref.read(waveformServiceProvider);

    final inMemory = waveformService.cachedWaveformSync(currentFilename);
    if (inMemory != null && inMemory.isNotEmpty && mounted) {
      setState(() {
        _peaks = inMemory;
      });
      _animateRevealFast();
      return;
    }

    final isCached = await waveformService.isWaveformCached(currentFilename);
    if (!mounted || widget.filename != currentFilename || token != _loadToken) {
      return;
    }

    if (isCached) {
      await _loadWaveform(isCached: true);
      return;
    }

    await _loadWaveform(isCached: false);
  }

  Future<void> _loadWaveform({required bool isCached}) async {
    if (widget.filename.isEmpty || widget.path.isEmpty) return;

    final token = _loadToken;
    final currentFilename = widget.filename;
    final waveformService = ref.read(waveformServiceProvider);

    _waveformSubscription?.cancel();
    _waveformSubscription = waveformService
        .getWaveformProgressive(widget.filename, widget.path, widget.total)
        .listen((peaks) {
      if (!mounted ||
          widget.filename != currentFilename ||
          token != _loadToken) {
        return;
      }

      if (_peaks != null && peaks.length < _peaks!.length) return;

      setState(() {
        _peaks = peaks;
      });

      if (isCached || peaks.length >= WaveformService.targetWaveformSamples) {
        if (_revealController.value < 1.0) {
          if (isCached && _revealController.value == 0.0) {
            _animateRevealFast();
          } else {
            _animateRevealTo(1.0, isComplete: true);
          }
        }
      } else {
        final target = (peaks.length / WaveformService.targetWaveformSamples)
            .clamp(0.0, 1.0);
        if (target > _revealController.value) {
          _animateRevealTo(target, isComplete: false);
        }
      }
    }, onError: (e) {
      debugPrint('ReactiveWaveformProgressBar: load failed: $e');
    });
  }

  void _animateRevealFast() {
    _revealController.stop();
    _revealController.value = 0.0;
    _revealController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _animateRevealTo(double target, {required bool isComplete}) {
    final current = _revealController.value;
    if (target <= current) return;
    final delta = (target - current).clamp(0.0, 1.0);
    final int ms;
    final Curve curve;
    if (isComplete) {
      ms = (delta * 350).clamp(120, 240).round();
      curve = Curves.easeOutCubic;
    } else {
      ms = (delta * 500).clamp(80, 200).round();
      curve = Curves.easeOutQuad;
    }
    _revealController.animateTo(
      target,
      duration: Duration(milliseconds: ms),
      curve: curve,
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds';
    }
    return '${duration.inMinutes}:$twoDigitSeconds';
  }

  int _calculateBarIndex(double x, double width) {
    const step = 4.0;
    final totalBars = (width / step).floor();
    if (totalBars <= 0) return 0;
    return (x.clamp(0.0, width) / step).floor().clamp(0, totalBars - 1);
  }

  void _updateScrubDelta(double targetPercent) {
    if (widget.total.inMilliseconds <= 0) {
      _scrubDeltaNotifier.value = 0;
      return;
    }
    final targetMs = (widget.total.inMilliseconds * targetPercent).round();
    final deltaMs = targetMs - _dragOriginDuration.inMilliseconds;
    final deltaSec = (deltaMs / 1000).round();
    _scrubDeltaNotifier.value = deltaSec;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final accentColor = colorScheme.secondary;
    final inactiveColor = colorScheme.onSurface.withValues(alpha: 0.16);

    _labelStyle ??= TextStyle(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    if (_formattedTotalTime.isEmpty || _formattedTotalTime == '0:00') {
      _formattedTotalTime = _formatDuration(widget.total);
    }

    final controller = _spectrumController;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (details) {
            final box = context.findRenderObject() as RenderBox;
            final x = details.localPosition.dx;
            _dragPosition = (x / box.size.width).clamp(0.0, 1.0);
            _dragPositionNotifier.value = _dragPosition;
            _dragOriginDuration = _positionNotifier.value;
            _updateScrubDelta(_dragPosition!);
            _scrubController.forward();
            _lastHapticBarIndex = _calculateBarIndex(x, box.size.width);
          },
          onHorizontalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox;
            final x = details.localPosition.dx;
            _dragPosition = (x / box.size.width).clamp(0.0, 1.0);
            _dragPositionNotifier.value = _dragPosition;
            _updateScrubDelta(_dragPosition!);
            final currentBar = _calculateBarIndex(x, box.size.width);
            if (_lastHapticBarIndex != null &&
                currentBar != _lastHapticBarIndex) {
              if (ref.read(settingsProvider).waveformHapticsEnabled) {
                HapticFeedback.selectionClick();
              }
            }
            _lastHapticBarIndex = currentBar;
          },
          onHorizontalDragEnd: (details) {
            _lastHapticBarIndex = null;
            _scrubController.reverse();
            if (_dragPosition != null) {
              widget.onSeek(widget.total * _dragPosition!);
            }
            _dragPosition = null;
            _dragPositionNotifier.value = null;
            _scrubDeltaNotifier.value = null;
          },
          onHorizontalDragCancel: () {
            _lastHapticBarIndex = null;
            _scrubController.reverse();
            _dragPosition = null;
            _dragPositionNotifier.value = null;
            _scrubDeltaNotifier.value = null;
          },
          onTapUp: (details) {
            _lastHapticBarIndex = null;
            _scrubController.reverse();
            final box = context.findRenderObject() as RenderBox;
            final x = details.localPosition.dx.clamp(0.0, box.size.width);
            final percent = (x / box.size.width).clamp(0.0, 1.0);
            _dragPosition = null;
            _dragPositionNotifier.value = null;
            _scrubDeltaNotifier.value = null;
            widget.onSeek(widget.total * percent);
          },
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            final x = details.localPosition.dx.clamp(0.0, box.size.width);
            final percent = (x / box.size.width).clamp(0.0, 1.0);
            _dragPosition = percent;
            _dragPositionNotifier.value = percent;
            _dragOriginDuration = _positionNotifier.value;
            _updateScrubDelta(percent);
            _scrubController.forward();
            _lastHapticBarIndex = _calculateBarIndex(x, box.size.width);
          },
          onTapCancel: () {
            _lastHapticBarIndex = null;
            _scrubController.reverse();
            _dragPosition = null;
            _dragPositionNotifier.value = null;
            _scrubDeltaNotifier.value = null;
          },
          child: Container(
            height: 60,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedBuilder(
                  animation: _revealController,
                  builder: (context, child) {
                    return RepaintBoundary(
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: ReactiveWaveformPainter(
                          controller: controller,
                          peaks: _peaks,
                          revealProgress: _revealController.value,
                          positionNotifier: _positionNotifier,
                          dragPositionNotifier: _dragPositionNotifier,
                          total: widget.total,
                          primaryColor: primaryColor,
                          accentColor: accentColor,
                          inactiveColor: inactiveColor,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: PlayerTokens.s1),
        _ReactiveScrubOverlay(
          scrubAnimation: _scrubAnimation,
          scrubDeltaNotifier: _scrubDeltaNotifier,
          dragPositionNotifier: _dragPositionNotifier,
          positionNotifier: _positionNotifier,
          total: widget.total,
          formattedTotalTime: _formattedTotalTime,
          labelStyle: _labelStyle,
          formatDuration: _formatDuration,
          primaryColor: primaryColor,
        ),
      ],
    );
  }
}

class _ReactiveScrubOverlay extends StatelessWidget {
  final Animation<double> scrubAnimation;
  final ValueNotifier<int?> scrubDeltaNotifier;
  final ValueNotifier<double?> dragPositionNotifier;
  final ValueNotifier<Duration> positionNotifier;
  final Duration total;
  final String formattedTotalTime;
  final TextStyle? labelStyle;
  final String Function(Duration) formatDuration;
  final Color primaryColor;

  const _ReactiveScrubOverlay({
    required this.scrubAnimation,
    required this.scrubDeltaNotifier,
    required this.dragPositionNotifier,
    required this.positionNotifier,
    required this.total,
    required this.formattedTotalTime,
    required this.labelStyle,
    required this.formatDuration,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrubAnimation,
      builder: (context, child) {
        final animValue = scrubAnimation.value;
        final yOffset = animValue * 11.0;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            if (animValue > 0.01)
              Positioned(
                top: -3.0,
                child: Opacity(
                  opacity: animValue.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.85 + (0.15 * animValue),
                    child: ValueListenableBuilder<int?>(
                      valueListenable: scrubDeltaNotifier,
                      builder: (context, deltaSec, _) {
                        final delta = deltaSec ?? 0;
                        final String deltaText;
                        final absDelta = delta.abs();
                        if (absDelta >= 60) {
                          final m = absDelta ~/ 60;
                          final s = (absDelta % 60).toString().padLeft(2, '0');
                          deltaText = '${delta >= 0 ? '+' : '-'}${m}m ${s}s';
                        } else if (delta == 0) {
                          deltaText = '0s';
                        } else {
                          deltaText = '${delta > 0 ? '+' : '-'}${absDelta}s';
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: PlayerTokens.brSm,
                          ),
                          child: Text(
                            deltaText,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(0, yOffset),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ValueListenableBuilder<double?>(
                    valueListenable: dragPositionNotifier,
                    builder: (context, dragPos, child) {
                      if (dragPos != null) {
                        return Text(
                          formatDuration(total * dragPos),
                          style: labelStyle,
                        );
                      }
                      return ValueListenableBuilder<Duration>(
                        valueListenable: positionNotifier,
                        builder: (context, position, child) {
                          return Text(
                            formatDuration(position),
                            style: labelStyle,
                          );
                        },
                      );
                    },
                  ),
                  Text(
                    formattedTotalTime,
                    style: labelStyle,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Custom painter for the sound-reactive progress bar.
///
/// Draws:
///  * Track waveform bars with amplitude calibration.
///  * Beat and bass reactive height punch on the active playback track.
///  * Integrated 4-band spectrum cursor (bass, low-mid, mid, air) at the playhead.
///  * Solid color blocking without gradients or borders.
class ReactiveWaveformPainter extends CustomPainter {
  final SpectrumController? controller;
  final List<double>? peaks;
  final double revealProgress;
  final ValueNotifier<Duration> positionNotifier;
  final ValueNotifier<double?> dragPositionNotifier;
  final Duration total;
  final Color primaryColor;
  final Color accentColor;
  final Color inactiveColor;

  ReactiveWaveformPainter({
    required this.controller,
    required this.peaks,
    required this.revealProgress,
    required this.positionNotifier,
    required this.dragPositionNotifier,
    required this.total,
    required this.primaryColor,
    required this.accentColor,
    required this.inactiveColor,
  }) : super(
          repaint: Listenable.merge([
            if (controller != null) controller,
            positionNotifier,
            dragPositionNotifier,
          ]),
        );

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 2.4;
    const spacing = 1.6;
    const step = barWidth + spacing;
    final totalBarsCount = (size.width / step).floor();
    if (totalBarsCount <= 0) return;

    final double progress;
    if (dragPositionNotifier.value != null) {
      progress = dragPositionNotifier.value!;
    } else {
      progress = total.inMilliseconds > 0
          ? (positionNotifier.value.inMilliseconds / total.inMilliseconds)
              .clamp(0.0, 1.0)
          : 0.0;
    }

    final playheadBarIndex = progress * totalBarsCount;
    final peakData = peaks;
    final hasPeaks = peakData != null && peakData.isNotEmpty;
    const compressedBarHeight = 2.5;
    final frontSpan = 3.0 / totalBarsCount;

    // Read real-time frequency spectrum from the controller
    final double bass;
    final double lowMid;
    final double mid;
    final double air;
    if (controller != null &&
        controller!.levels.length >= SpectrumBars.barCount) {
      bass = controller!.levels[0];
      lowMid = controller!.levels[1];
      mid = controller!.levels[2];
      air = controller!.levels[3];
    } else {
      bass = SpectrumBars.floor;
      lowMid = SpectrumBars.floor;
      mid = SpectrumBars.floor;
      air = SpectrumBars.floor;
    }

    // Dynamic audio energy factors
    final beatEnergy = (bass * 0.5 + lowMid * 0.3 + mid * 0.15 + air * 0.05);
    final isPlayingNow = controller?.isSynced ?? false || beatEnergy > 0.1;

    final paint = Paint()..style = PaintingStyle.fill;
    final radius = const Radius.circular(1.2);

    final isScrubbing = dragPositionNotifier.value != null;

    const clusterBarWidth = 2.8;
    const clusterGap = 1.4;
    const totalClusterWidth = 4 * clusterBarWidth + 3 * clusterGap;
    final playheadX = (playheadBarIndex * step).clamp(0.0, size.width);
    final clusterLeft = (playheadX - totalClusterWidth / 2)
        .clamp(0.0, size.width - totalClusterWidth);
    final clusterRight = clusterLeft + totalClusterWidth;

    for (var i = 0; i < totalBarsCount; i++) {
      final x = i * step + spacing / 2;
      final xRight = x + barWidth;

      // Skip painting background bar if fully within the 4-band playhead cluster window
      if (xRight > clusterLeft && x < clusterRight) {
        continue;
      }

      // Smooth edge fade for bars immediately bordering the cluster to avoid hard cut flickers
      double edgeFade = 1.0;
      if (x < clusterLeft && xRight > clusterLeft - spacing) {
        edgeFade = ((clusterLeft - xRight) / spacing).clamp(0.0, 1.0);
      } else if (x > clusterRight && x < clusterRight + spacing) {
        edgeFade = ((x - clusterRight) / spacing).clamp(0.0, 1.0);
      }

      final barFraction = (i + 0.5) / totalBarsCount;

      final double revealFactor;
      if (revealProgress <= 0.0 || !hasPeaks) {
        revealFactor = 0.0;
      } else if (revealProgress >= 1.0) {
        revealFactor = 1.0;
      } else if (barFraction >= revealProgress) {
        revealFactor = 0.0;
      } else if (barFraction <= revealProgress - frontSpan) {
        revealFactor = 1.0;
      } else {
        final edgeDelta = (revealProgress - barFraction) / frontSpan;
        revealFactor =
            (edgeDelta * edgeDelta * (3.0 - 2.0 * edgeDelta)).clamp(0.0, 1.0);
      }

      final double targetHeight;
      if (hasPeaks) {
        final samplePos =
            (i / totalBarsCount) * WaveformService.targetWaveformSamples;
        final startIndex = samplePos.floor();
        final endIndex =
            (((i + 1) / totalBarsCount) * WaveformService.targetWaveformSamples)
                .ceil();

        double maxAmp = 0.0;
        if (startIndex < peakData.length) {
          final sliceEnd = math.min(endIndex, peakData.length);
          for (var s = startIndex; s < sliceEnd; s++) {
            if (peakData[s] > maxAmp) maxAmp = peakData[s];
          }
          if (maxAmp == 0.0 && startIndex < peakData.length) {
            maxAmp = peakData[startIndex];
          }
        }
        targetHeight = calculateWaveformBarHeight(maxAmp, size.height);
      } else {
        targetHeight = compressedBarHeight;
      }

      final double baseHeight =
          ui.lerpDouble(compressedBarHeight, targetHeight, revealFactor)!;

      final distanceFromPlayhead = (i - playheadBarIndex).abs();
      final isActive = i < playheadBarIndex;

      // Clean rhythm response: active track pulses with beat & bass,
      // smoothly lifting into the playhead without traveling sine wave ripples.
      // Unplayed track stays steady and calm.
      double dynamicScale = 1.0;
      if (isPlayingNow && !isScrubbing && isActive) {
        final proximity = (1.0 - (distanceFromPlayhead / 4.0)).clamp(0.0, 1.0);
        final leadIn = proximity * proximity * 0.06 * bass;
        dynamicScale = 1.0 + 0.08 * beatEnergy + 0.04 * bass + leadIn;
      }

      final finalHeight = (baseHeight * dynamicScale)
          .clamp(compressedBarHeight, size.height * 0.94);

      final Color barColor;
      if (isActive) {
        barColor = primaryColor;
      } else {
        barColor = inactiveColor;
      }

      final double alphaScale = ui.lerpDouble(0.65, 1.0, revealFactor)!;
      paint.color = barColor.withValues(
        alpha: (barColor.a * alphaScale * edgeFade).clamp(0.0, 1.0),
      );
      final y = (size.height - finalHeight) / 2;

      canvas.drawRRect(
        RRect.fromLTRBR(
          x,
          y,
          x + barWidth,
          y + finalHeight,
          radius,
        ),
        paint,
      );
    }

    // Integrated 4-band spectrum cursor at the exact playhead position
    _paintPlayheadVisualizer(
      canvas: canvas,
      size: size,
      centerX: playheadX,
      startX: clusterLeft,
      levels: [bass, lowMid, mid, air],
      accentColor: accentColor,
      isScrubbing: isScrubbing,
    );
  }

  void _paintPlayheadVisualizer({
    required Canvas canvas,
    required Size size,
    required double centerX,
    required double startX,
    required List<double> levels,
    required Color accentColor,
    required bool isScrubbing,
  }) {
    const clusterBarWidth = 2.8;
    const clusterGap = 1.4;

    final paint = Paint()..color = accentColor;
    const barRadius = Radius.circular(1.4);

    for (var b = 0; b < 4; b++) {
      final level = levels[b].clamp(SpectrumBars.floor, 1.0);
      final double barH;
      if (isScrubbing) {
        barH = (b == 1 || b == 2) ? size.height * 0.52 : size.height * 0.36;
      } else {
        barH = math.max(6.0, level * size.height * 0.88);
      }
      final bx = startX + b * (clusterBarWidth + clusterGap);
      final by = (size.height - barH) / 2;

      canvas.drawRRect(
        RRect.fromLTRBR(
          bx,
          by,
          bx + clusterBarWidth,
          by + barH,
          barRadius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ReactiveWaveformPainter oldDelegate) {
    return oldDelegate.peaks != peaks ||
        oldDelegate.revealProgress != revealProgress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.total != total;
  }
}
