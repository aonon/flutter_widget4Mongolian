part of '../mongol_render_editable.dart';

class _CompositeRenderEditablePainter extends MongolRenderEditablePainter {
  _CompositeRenderEditablePainter({required this.painters});

  final List<MongolRenderEditablePainter> painters;

  @override
  void addListener(VoidCallback listener) {
    for (final painter in painters) {
      painter.addListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    for (final painter in painters) {
      painter.removeListener(listener);
    }
  }

  @override
  void paint(Canvas canvas, Size size, MongolRenderEditable renderEditable) {
    for (final painter in painters) {
      painter.paint(canvas, size, renderEditable);
    }
  }

  @override
  bool shouldRepaint(MongolRenderEditablePainter? oldDelegate) {
    if (identical(oldDelegate, this)) return false;
    if (oldDelegate is! _CompositeRenderEditablePainter ||
        oldDelegate.painters.length != painters.length) {
      return true;
    }

    final oldPainters = oldDelegate.painters.iterator;
    final newPainters = painters.iterator;
    while (oldPainters.moveNext() && newPainters.moveNext()) {
      if (newPainters.current.shouldRepaint(oldPainters.current)) return true;
    }

    return false;
  }
}
