import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Rebuilds only when a condition over a changing value flips, not on every
/// frame of the value itself.
class MotionValueCondition<T> extends StatefulWidget {
  const MotionValueCondition({
    super.key,
    required this.value,
    required this.condition,
    required this.builder,
    this.child,
  });

  final ValueListenable<T> value;
  final bool Function(T value) condition;
  final Widget Function(BuildContext context, bool matches) builder;

  /// Passed through untouched, so the subtree rebuilds only on a flip.
  final Widget? child;

  @override
  State<MotionValueCondition<T>> createState() =>
      _MotionValueConditionState<T>();
}

class _MotionValueConditionState<T> extends State<MotionValueCondition<T>> {
  late bool _matches;

  @override
  void initState() {
    super.initState();
    _matches = widget.condition(widget.value.value);
    widget.value.addListener(_sync);
  }

  @override
  void didUpdateWidget(MotionValueCondition<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.value, widget.value)) {
      oldWidget.value.removeListener(_sync);
      widget.value.addListener(_sync);
    }
    _sync();
  }

  void _sync() {
    final bool next = widget.condition(widget.value.value);
    if (next == _matches) return;
    setState(() => _matches = next);
  }

  @override
  void dispose() {
    widget.value.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _matches);
}

/// Keeps a render object subscribed to a [ValueListenable] without rebuilding
/// its parent. Subclasses decide between repaint and relayout.
mixin RenderListenableSync<T> on RenderObject {
  ValueListenable<T>? _source;

  @protected
  ValueListenable<T> get source => _source!;

  @protected
  set source(ValueListenable<T> next) {
    if (identical(next, _source)) return;
    if (attached) _source?.removeListener(_sync);
    _source = next;
    if (attached) {
      _source!.addListener(_sync);
      _sync();
    }
  }

  @protected
  void syncValue(T value);

  void _sync() => syncValue(source.value);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _source?.addListener(_sync);
    _sync();
  }

  @override
  void detach() {
    _source?.removeListener(_sync);
    super.detach();
  }
}

/// Translates its child by a live offset, painting instead of building, so a
/// drag never touches the widget tree. Hit-testing applies the same offset.
class ListenableTranslate extends SingleChildRenderObjectWidget {
  const ListenableTranslate({
    super.key,
    required this.offset,
    super.child,
  });

  final ValueListenable<Offset> offset;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderListenableTranslate(offset);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderListenableTranslate renderObject,
  ) {
    renderObject.listenable = offset;
  }
}

class RenderListenableTranslate extends RenderProxyBox
    with RenderListenableSync<Offset> {
  RenderListenableTranslate(ValueListenable<Offset> offset) {
    source = offset;
  }

  set listenable(ValueListenable<Offset> value) => source = value;

  Offset get _offset => source.value;

  @override
  void syncValue(Offset value) => markNeedsPaint();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) context.paintChild(child!, offset + _offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return child?.hitTest(result, position: position - _offset) ?? false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_offset.dx, _offset.dy, 0, 1);
  }
}

/// Pads its child by live insets without rebuilding the parent. Relayout, not
/// repaint.
class ListenablePadding extends SingleChildRenderObjectWidget {
  const ListenablePadding({
    super.key,
    required this.padding,
    super.child,
  });

  final ValueListenable<EdgeInsets> padding;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderListenablePadding(padding);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderListenablePadding renderObject,
  ) {
    renderObject.listenable = padding;
  }
}

class RenderListenablePadding extends RenderShiftedBox
    with RenderListenableSync<EdgeInsets> {
  RenderListenablePadding(ValueListenable<EdgeInsets> padding) : super(null) {
    source = padding;
  }

  set listenable(ValueListenable<EdgeInsets> value) => source = value;

  EdgeInsets get _padding => source.value;

  @override
  void syncValue(EdgeInsets value) => markNeedsLayout();

  @override
  void performLayout() {
    final EdgeInsets padding = _padding;
    final BoxConstraints constraints = this.constraints;
    if (child == null) {
      size = constraints.constrain(Size(
        padding.horizontal,
        padding.vertical,
      ));
      return;
    }
    child!.layout(
      constraints.deflate(padding),
      parentUsesSize: true,
    );
    size = constraints.constrain(Size(
      child!.size.width + padding.horizontal,
      child!.size.height + padding.vertical,
    ));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final EdgeInsets padding = _padding;
    if (child == null) {
      return constraints.constrain(Size(
        padding.horizontal,
        padding.vertical,
      ));
    }
    final Size childSize = child!.getDryLayout(
      constraints.deflate(padding),
    );
    return constraints.constrain(Size(
      childSize.width + padding.horizontal,
      childSize.height + padding.vertical,
    ));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.paintChild(child!, offset + _padding.topLeft);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return child?.hitTest(result, position: position - _padding.topLeft) ??
        false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_padding.left, _padding.top, 0, 1);
  }
}
