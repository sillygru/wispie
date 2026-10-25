import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'motion_policy.dart';

/// Reference-counted frame clock for ambient motion. Effects read seconds, not
/// frame counts, so a dropped frame never slows them down.
class MotionClock extends ChangeNotifier {
  MotionClock({TickerProvider? vsync, String debugLabel = 'motion clock'}) {
    _ticker = vsync == null
        ? Ticker(_onTick, debugLabel: debugLabel)
        : vsync.createTicker(_onTick);
  }

  late final Ticker _ticker;
  int _refs = 0;

  /// Time banked across stops; [Ticker.start] otherwise rewinds to zero.
  Duration _base = Duration.zero;
  Duration _elapsed = Duration.zero;

  /// Seconds of ambient time accumulated by this clock.
  double get seconds =>
      _elapsed.inMicroseconds / Duration.microsecondsPerSecond;

  Duration get elapsed => _elapsed;

  bool get isRunning => _ticker.isActive;

  int get refCount => _refs;

  /// Registers a consumer. The first acquisition starts the ticker.
  void acquire() {
    _refs++;
    if (_refs == 1 && !_ticker.isActive) {
      _ticker.start();
    }
  }

  /// Unregisters a consumer. The last release stops the ticker and banks time.
  void release() {
    if (_refs == 0) return;
    _refs--;
    if (_refs == 0 && _ticker.isActive) {
      _ticker.stop();
      _base = _elapsed;
    }
  }

  void _onTick(Duration elapsed) {
    _elapsed = _base + elapsed;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker
      ..stop()
      ..dispose();
    super.dispose();
  }
}

/// Rebuilds with the ambient clock while visible and motion is allowed. A
/// covered route stops the clock; reduced motion holds it at zero.
class MotionClockBuilder extends StatefulWidget {
  const MotionClockBuilder({
    super.key,
    required this.builder,
    this.clock,
    this.enabled = true,
  });

  /// Receives ambient seconds; this rebuilds every frame while visible.
  final Widget Function(BuildContext context, double seconds) builder;

  /// Shared clock. Omit for a private one; several effects that drift together
  /// must share.
  final MotionClock? clock;

  /// Stops the clock without unmounting, e.g. when the effect is toggled off.
  final bool enabled;

  @override
  State<MotionClockBuilder> createState() => _MotionClockBuilderState();
}

class _MotionClockBuilderState extends State<MotionClockBuilder> {
  MotionClock? _owned;
  MotionClock get _clock => widget.clock ?? (_owned ??= MotionClock());

  bool _holding = false;
  bool _tickerMode = true;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerMode = TickerMode.valuesOf(context).enabled;
    _reduceMotion = MotionPolicy.of(context).reduceMotion;
    _sync();
  }

  @override
  void didUpdateWidget(MotionClockBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final bool shouldRun = widget.enabled && _tickerMode && !_reduceMotion;
    if (shouldRun && !_holding) {
      _holding = true;
      _clock
        ..acquire()
        ..addListener(_tick);
    } else if (!shouldRun && _holding) {
      _holding = false;
      _clock
        ..removeListener(_tick)
        ..release();
    }
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_holding) {
      _holding = false;
      _clock
        ..removeListener(_tick)
        ..release();
    }
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _reduceMotion ? 0 : _clock.seconds);
  }
}
