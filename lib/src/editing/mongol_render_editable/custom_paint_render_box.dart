part of '../mongol_render_editable.dart';

class _MongolRenderEditableCustomPaint extends RenderBox {
  _MongolRenderEditableCustomPaint({
    MongolRenderEditablePainter? painter,
  })  : _painter = painter,
        super();

  @override
  MongolRenderEditable? get parent => super.parent as MongolRenderEditable?;

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  MongolRenderEditablePainter? get painter => _painter;
  MongolRenderEditablePainter? _painter;

  set painter(MongolRenderEditablePainter? newValue) {
    if (newValue == painter) return;

    final oldPainter = painter;
    _painter = newValue;

    if (newValue?.shouldRepaint(oldPainter) ?? true) markNeedsPaint();

    if (attached) {
      oldPainter?.removeListener(markNeedsPaint);
      newValue?.addListener(markNeedsPaint);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final parent = this.parent;
    assert(parent != null);
    final painter = this.painter;
    if (painter != null && parent != null) {
      parent._computeTextMetricsIfNeeded();
      painter.paint(context.canvas, size, parent);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _painter?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _painter?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;
}

/// An interface that paints within a [MongolRenderEditable]'s bounds, above or
/// beneath its text content.
///
/// This painter is typically used for painting auxiliary content that depends
/// on text layout metrics (for instance, for painting carets and text highlight
/// blocks). It can paint independently from its [MongolRenderEditable],
/// allowing it to repaint without triggering a repaint on the entire
/// [MongolRenderEditable] stack when only auxiliary content changes (e.g. a
/// blinking cursor) are present. It will be scheduled to repaint when:
///
///  * It's assigned to a new [MongolRenderEditable] and the [shouldRepaint]
///    method returns true.
///  * Any of the [MongolRenderEditable]s it is attached to repaints.
///  * The [notifyListeners] method is called, which typically happens when the
///    painter's attributes change.
///
/// See also:
///
///  * [MongolRenderEditable.foregroundPainter], which takes a
///    [MongolRenderEditablePainter] and sets it as the foreground painter of
///    the [MongolRenderEditable].
///  * [MongolRenderEditable.painter], which takes a [MongolRenderEditablePainter]
///    and sets it as the background painter of the [MongolRenderEditable].
///  * [CustomPainter] a similar class which paints within a [RenderCustomPaint].
abstract class MongolRenderEditablePainter extends ChangeNotifier {
  /// Determines whether repaint is needed when a new
  /// [MongolRenderEditablePainter] is provided to a [MongolRenderEditable].
  ///
  /// If the new instance represents different information than the old
  /// instance, then the method should return true, otherwise it should return
  /// false. When [oldDelegate] is null, this method should always return true
  /// unless the new painter initially does not paint anything.
  ///
  /// If the method returns false, then the [paint] call might be optimized
  /// away. However, the [paint] method will get called whenever the
  /// [MongolRenderEditable]s it attaches to repaint, even if [shouldRepaint]
  /// returns false.
  bool shouldRepaint(MongolRenderEditablePainter? oldDelegate);

  /// Paints within the bounds of a [MongolRenderEditable].
  ///
  /// The given [Canvas] has the same coordinate space as the
  /// [MongolRenderEditable], which may be different from the coordinate space
  /// the [MongolRenderEditable]'s [MongolTextPainter] uses, when the text moves
  /// inside the [MongolRenderEditable].
  ///
  /// Paint operations performed outside of the region defined by the [canvas]'s
  /// origin and the [size] parameter may get clipped, when
  /// [MongolRenderEditable]'s [MongolRenderEditable.clipBehavior] is not
  /// [Clip.none].
  void paint(Canvas canvas, Size size, MongolRenderEditable renderEditable);
}

