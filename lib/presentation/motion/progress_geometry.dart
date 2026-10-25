import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Layout derived from one progress value, recomputed once per tick.
///
/// Leaves listen here instead of to the controller, so a drag repaints only
/// what depends on the value. Call [bind] once subclass fields are ready.
abstract class ProgressGeometry extends ChangeNotifier {
  ProgressGeometry(this.controller);

  /// The single source of truth. Values outside the 0..1 range are allowed:
  /// overshoot lives there and [layout] is expected to mirror or clamp it.
  final AnimationController controller;

  bool _bound = false;

  /// True once [bind] has subscribed. Callers that must feed a width in before
  /// the first tick can check this instead of tracking it themselves.
  bool get isBound => _bound;

  double get progress => controller.value;

  /// Writes the derived fields. Runs once per tick; no allocation, no side
  /// effects.
  @protected
  void layout(double progress);

  /// Inputs from outside the motion (nav bar height, aspect ratio).
  @protected
  void updateInputs() => layout(progress);

  void bind() {
    if (_bound) return;
    _bound = true;
    controller.addListener(_onTick);
    updateInputs();
  }

  /// Recomputes now, after an input field changed or a silent jump.
  void refresh() => _onTick();

  /// Recomputes and notifies leaves after an input change.
  void notifyInputsChanged() {
    updateInputs();
    notifyListeners();
  }

  void _onTick() {
    layout(controller.value);
    notifyListeners();
  }

  @override
  void dispose() {
    controller.removeListener(_onTick);
    super.dispose();
  }
}
