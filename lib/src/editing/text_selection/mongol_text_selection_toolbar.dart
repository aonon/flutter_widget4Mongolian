// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart'
    show Icons, Material, MaterialType, IconButton;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'mongol_text_selection_toolbar_layout_delegate.dart';

// 选择工具栏与视口所有边缘的最小填充。
const double _kToolbarScreenPadding = 8.0;
const double _kToolbarWidth = 44.0;

/// 功能齐全的 Material 风格文本选择工具栏。
///
/// 尝试将自己定位到 [anchorLeft] 的左侧，但如果不合适，
/// 则将自己定位到 [anchorRight] 的右侧。
///
/// 如果任何子项不适合菜单，将自动创建一个溢出菜单。
///
/// 另请参阅：
///
///  * [MongolTextSelectionControls.buildToolbar]，默认使用它来
///    构建 Android 风格的工具栏。
class MongolTextSelectionToolbar extends StatelessWidget {
  /// 创建 MongolTextSelectionToolbar 的实例。
  const MongolTextSelectionToolbar({
    super.key,
    required this.anchorLeft,
    required this.anchorRight,
    this.toolbarBuilder = _defaultToolbarBuilder,
    required this.children,
  })  : assert(children.length > 0);

  /// 工具栏尝试定位到其左侧的焦点。
  ///
  /// 如果在到达屏幕左侧之前左侧没有足够的空间，
  /// 则工具栏将定位到 [anchorRight] 的右侧。
  final Offset anchorLeft;

  /// 如果工具栏不适合 [anchorLeft] 的左侧，则它尝试定位到其右侧的焦点。
  final Offset anchorRight;

  /// 将在文本选择工具栏中显示的子项。
  ///
  /// 通常这些是按钮。
  ///
  /// 不能为空。
  ///
  /// 另请参阅：
  ///   * [MongolTextSelectionToolbarButton]，它构建工具栏按钮。
  final List<Widget> children;

  /// 构建工具栏容器。
  ///
  /// 对于自定义工具栏的高级背景很有用。给定的
  /// 子 Widget 将包含所有 [children]。
  final ToolbarBuilder toolbarBuilder;

  // 构建默认的文本选择菜单工具栏。
  static Widget _defaultToolbarBuilder(BuildContext context, Widget child) {
    return _TextSelectionToolbarContainer(
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final paddingLeft =
        MediaQuery.of(context).padding.left + _kToolbarScreenPadding;
    final availableWidth = anchorLeft.dx - paddingLeft;
    final fitsLeft = _kToolbarWidth <= availableWidth;
    final localAdjustment = Offset(paddingLeft, _kToolbarScreenPadding);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        paddingLeft,
        _kToolbarScreenPadding,
        _kToolbarScreenPadding,
        _kToolbarScreenPadding,
      ),
      child: Stack(
        children: <Widget>[
          CustomSingleChildLayout(
            delegate: MongolTextSelectionToolbarLayoutDelegate(
              anchorLeft: anchorLeft - localAdjustment,
              anchorRight: anchorRight - localAdjustment,
              fitsLeft: fitsLeft,
            ),
            child: _TextSelectionToolbarOverflowable(
              isLeft: fitsLeft,
              toolbarBuilder: toolbarBuilder,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// 包含给定子项的工具栏。如果它们超出可用高度，
// 则溢出的子项将显示在溢出菜单中。
class _TextSelectionToolbarOverflowable extends StatefulWidget {
  const _TextSelectionToolbarOverflowable({
    required this.isLeft,
    required this.toolbarBuilder,
    required this.children,
  })  : assert(children.length > 0);

  final List<Widget> children;

  // 当为 true 时，工具栏适合其锚点的左侧，并将定位在那里。
  final bool isLeft;

  // 构建将填充子项并适合调整溢出的布局内的工具栏。
  final ToolbarBuilder toolbarBuilder;

  @override
  _TextSelectionToolbarOverflowableState createState() =>
      _TextSelectionToolbarOverflowableState();
}

class _TextSelectionToolbarOverflowableState
    extends State<_TextSelectionToolbarOverflowable>
    with TickerProviderStateMixin {
  // 溢出菜单是否打开。当它关闭时，显示不溢出的菜单项。
  // 当它打开时，只显示溢出的菜单项。
  bool _overflowOpen = false;

  // _TextSelectionToolbarTrailingEdgeAlign 的键。
  UniqueKey _containerKey = UniqueKey();

  // 关闭菜单并重置布局计算，例如当菜单已更改且保存的值不再相关时。
  // 这应该在 setState 或发生重建的其他上下文中调用。
  void _reset() {
    // 当菜单更改时更改 _TextSelectionToolbarTrailingEdgeAlign 的键，
    // 以使其重建。这使其能够为新的子项集重新计算其保存的高度，
    // 并防止 AnimatedSize 对大小变化进行动画处理。
    _containerKey = UniqueKey();
    // 如果菜单项更改，确保溢出菜单已关闭。
    // 这可以防止进入 _overflowOpen 为 true 但没有足够子项导致溢出的损坏状态。
    _overflowOpen = false;
  }

  @override
  void didUpdateWidget(_TextSelectionToolbarOverflowable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果子项有任何变化，当前页面应重置。
    if (!listEquals(widget.children, oldWidget.children)) {
      _reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _TextSelectionToolbarTrailingEdgeAlign(
      key: _containerKey,
      overflowOpen: _overflowOpen,
      child: AnimatedSize(
        // 此持续时间是在运行 Android API 28 的 Pixel 2 模拟器上目测的。
        duration: const Duration(milliseconds: 140),
        child: widget.toolbarBuilder(
            context,
            _TextSelectionToolbarItemsLayout(
              isLeft: widget.isLeft,
              overflowOpen: _overflowOpen,
              children: <Widget>[
                _TextSelectionToolbarOverflowButton(
                  icon:
                      Icon(_overflowOpen ? Icons.arrow_back : Icons.more_horiz),
                  onPressed: () {
                    setState(() {
                      _overflowOpen = !_overflowOpen;
                    });
                  },
                ),
                ...widget.children,
              ],
            )),
      ),
    );
  }
}

// 当溢出菜单打开时，它尝试将其 trailing edge 与关闭菜单的 trailing edge 对齐。
// 此小部件通过测量和维护关闭菜单的高度并将子项对齐到该侧来处理此效果。
class _TextSelectionToolbarTrailingEdgeAlign
    extends SingleChildRenderObjectWidget {
  const _TextSelectionToolbarTrailingEdgeAlign({
    super.key,
    required Widget super.child,
    required this.overflowOpen,
  });

  final bool overflowOpen;

  @override
  _TextSelectionToolbarTrailingEdgeAlignRenderBox createRenderObject(
      BuildContext context) {
    return _TextSelectionToolbarTrailingEdgeAlignRenderBox(
      overflowOpen: overflowOpen,
    );
  }

  @override
  void updateRenderObject(BuildContext context,
      _TextSelectionToolbarTrailingEdgeAlignRenderBox renderObject) {
    renderObject.overflowOpen = overflowOpen;
  }
}

class _TextSelectionToolbarTrailingEdgeAlignRenderBox extends RenderProxyBox {
  _TextSelectionToolbarTrailingEdgeAlignRenderBox({
    required bool overflowOpen,
  })  : _overflowOpen = overflowOpen,
        super();

  // 菜单关闭时的高度。这用于实现打开菜单将其 trailing edge 与关闭菜单的
  // trailing edge 对齐的行为。
  double? _closedHeight;

  bool _overflowOpen;
  bool get overflowOpen => _overflowOpen;
  set overflowOpen(bool value) {
    if (value == overflowOpen) {
      return;
    }
    _overflowOpen = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(constraints.loosen(), parentUsesSize: true);

    // 保存菜单关闭时的高度。如果菜单更改，此高度无效，
    // 因此重要的是在此情况下重新创建此 RenderBox。
    // 目前，这是通过向 _TextSelectionToolbarTrailingEdgeAlign 提供新键来实现的。
    if (!overflowOpen && _closedHeight == null) {
      _closedHeight = child!.size.height;
    }

    size = constraints.constrain(Size(
      child!.size.width,
      // 如果打开的菜单比关闭的菜单高，只需使用其自身的高度
      // 而不担心对齐 trailing edge。
      // 即使菜单关闭时也使用 _closedHeight，以允许它在保持相同边缘对齐的同时为其大小设置动画。
      _closedHeight == null || child!.size.height > _closedHeight!
          ? child!.size.height
          : _closedHeight!,
    ));

    // 在父数据中设置偏移，使子项将对齐到 trailing edge。
    final childParentData = child!.parentData! as ToolbarItemsParentData;
    childParentData.offset = Offset(
      0.0,
      size.height - child!.size.height,
    );
  }

  // 在父数据中设置的偏移处绘制。
  @override
  void paint(PaintingContext context, Offset offset) {
    final childParentData = child!.parentData! as ToolbarItemsParentData;
    context.paintChild(child!, childParentData.offset + offset);
  }

  // 在命中测试中包含父数据偏移。
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // x, y 参数以节点框的左上角为原点。
    final childParentData = child!.parentData! as ToolbarItemsParentData;
    return result.addWithPaintOffset(
      offset: childParentData.offset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        assert(transformed == position - childParentData.offset);
        return child!.hitTest(result, position: transformed);
      },
    );
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ToolbarItemsParentData) {
      child.parentData = ToolbarItemsParentData();
    }
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final childParentData = child.parentData! as ToolbarItemsParentData;
    transform.translateByDouble(childParentData.offset.dx, childParentData.offset.dy, 0.0, 0.0);
    super.applyPaintTransform(child, transform);
  }
}

// 根据计算哪个项目首先溢出，在菜单及其溢出子菜单中的正确位置渲染菜单项。
class _TextSelectionToolbarItemsLayout extends MultiChildRenderObjectWidget {
  const _TextSelectionToolbarItemsLayout({
    required this.isLeft,
    required this.overflowOpen,
    required super.children,
  });

  final bool isLeft;
  final bool overflowOpen;

  @override
  _RenderTextSelectionToolbarItemsLayout createRenderObject(
      BuildContext context) {
    return _RenderTextSelectionToolbarItemsLayout(
      isLeft: isLeft,
      overflowOpen: overflowOpen,
    );
  }

  @override
  void updateRenderObject(BuildContext context,
      _RenderTextSelectionToolbarItemsLayout renderObject) {
    renderObject
      ..isLeft = isLeft
      ..overflowOpen = overflowOpen;
  }

  @override
  _TextSelectionToolbarItemsLayoutElement createElement() =>
      _TextSelectionToolbarItemsLayoutElement(this);
}

class _TextSelectionToolbarItemsLayoutElement
    extends MultiChildRenderObjectElement {
  _TextSelectionToolbarItemsLayoutElement(
    super.widget,
  );

  static bool _shouldPaint(Element child) {
    return (child.renderObject!.parentData! as ToolbarItemsParentData)
        .shouldPaint;
  }

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    children.where(_shouldPaint).forEach(visitor);
  }
}

class _RenderTextSelectionToolbarItemsLayout extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, ToolbarItemsParentData> {
  _RenderTextSelectionToolbarItemsLayout({
    required bool isLeft,
    required bool overflowOpen,
  })  : _isLeft = isLeft,
        _overflowOpen = overflowOpen,
        super();

  // 不溢出的最后一个项目的索引。
  int _lastIndexThatFits = -1;

  bool _isLeft;
  bool get isLeft => _isLeft;
  set isLeft(bool value) {
    if (value == isLeft) {
      return;
    }
    _isLeft = value;
    markNeedsLayout();
  }

  bool _overflowOpen;
  bool get overflowOpen => _overflowOpen;
  set overflowOpen(bool value) {
    if (value == overflowOpen) {
      return;
    }
    _overflowOpen = value;
    markNeedsLayout();
  }

  // 布局必要的子项，并找出子项首先溢出的位置（如果有的话）。
  void _layoutChildren() {
    // 当溢出未打开时，工具栏始终具有特定宽度。
    final sizedConstraints = _overflowOpen
        ? constraints
        : BoxConstraints.loose(Size(
            _kToolbarWidth,
            constraints.maxHeight,
          ));

    var i = -1;
    var height = 0.0;
    visitChildren((RenderObject renderObjectChild) {
      i++;

      // 当溢出菜单关闭时，无需布局其内部的子项。
      // 相反的情况并非如此。当溢出菜单打开时，需要布局不溢出的子项，
      // 以便计算 _lastIndexThatFits。
      if (_lastIndexThatFits != -1 && !overflowOpen) {
        return;
      }

      final child = renderObjectChild as RenderBox;
      child.layout(sizedConstraints.loosen(), parentUsesSize: true);
      height += child.size.height;

      if (height > sizedConstraints.maxHeight && _lastIndexThatFits == -1) {
        _lastIndexThatFits = i - 1;
      }
    });

    // 如果最后一个子项溢出，但只是因为溢出按钮的高度，
    // 则只显示它并隐藏溢出按钮。
    final navButton = firstChild!;
    if (_lastIndexThatFits != -1 &&
        _lastIndexThatFits == childCount - 2 &&
        height - navButton.size.height <= sizedConstraints.maxHeight) {
      _lastIndexThatFits = -1;
    }
  }

  // 当子项应该被绘制时返回 true，否则返回 false。
  bool _shouldPaintChild(RenderObject renderObjectChild, int index) {
    // 当有溢出时绘制导航按钮。
    if (renderObjectChild == firstChild) {
      return _lastIndexThatFits != -1;
    }

    // 如果没有溢出，除导航按钮外的所有子项都被绘制。
    if (_lastIndexThatFits == -1) {
      return true;
    }

    // 当有溢出时，如果子项在当前打开的菜单部分中，则绘制。
    // 当溢出菜单打开时绘制溢出的子项，当溢出菜单关闭时绘制适合的子项。
    return (index > _lastIndexThatFits) == overflowOpen;
  }

  // 决定哪些子项将被绘制，设置它们的 shouldPaint，并设置绘制子项将被放置的偏移。
  void _placeChildren() {
    var i = -1;
    var nextSize = const Size(0.0, 0.0);
    var fitHeight = 0.0;
    final navButton = firstChild!;
    var overflowWidth = overflowOpen && !isLeft ? navButton.size.width : 0.0;
    visitChildren((RenderObject renderObjectChild) {
      i++;

      final child = renderObjectChild as RenderBox;
      final childParentData = child.parentData! as ToolbarItemsParentData;

      // 在迭代所有子项后处理放置导航按钮。
      if (renderObjectChild == navButton) {
        return;
      }

      // 无需放置不会被绘制的子项。
      if (!_shouldPaintChild(renderObjectChild, i)) {
        childParentData.shouldPaint = false;
        return;
      }
      childParentData.shouldPaint = true;

      if (!overflowOpen) {
        childParentData.offset = Offset(0.0, fitHeight);
        fitHeight += child.size.height;
        nextSize = Size(
          math.max(child.size.width, nextSize.width),
          fitHeight,
        );
      } else {
        childParentData.offset = Offset(overflowWidth, 0.0);
        overflowWidth += child.size.width;
        nextSize = Size(
          overflowWidth,
          math.max(child.size.height, nextSize.height),
        );
      }
    });

    // 如果需要，放置导航按钮。
    final navButtonParentData = navButton.parentData! as ToolbarItemsParentData;
    if (_shouldPaintChild(firstChild!, 0)) {
      navButtonParentData.shouldPaint = true;
      if (overflowOpen) {
        navButtonParentData.offset =
            isLeft ? Offset(overflowWidth, 0.0) : Offset.zero;
        nextSize = Size(
          isLeft ? nextSize.width + navButton.size.width : nextSize.width,
          nextSize.height,
        );
      } else {
        navButtonParentData.offset = Offset(0.0, fitHeight);
        nextSize =
            Size(nextSize.width, nextSize.height + navButton.size.height);
      }
    } else {
      navButtonParentData.shouldPaint = false;
    }

    size = nextSize;
  }

  @override
  void performLayout() {
    _lastIndexThatFits = -1;
    if (firstChild == null) {
      size = constraints.smallest;
      return;
    }

    _layoutChildren();
    _placeChildren();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    visitChildren((RenderObject renderObjectChild) {
      final child = renderObjectChild as RenderBox;
      final childParentData = child.parentData! as ToolbarItemsParentData;
      if (!childParentData.shouldPaint) {
        return;
      }

      context.paintChild(child, childParentData.offset + offset);
    });
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ToolbarItemsParentData) {
      child.parentData = ToolbarItemsParentData();
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // x, y 参数以节点框的左上角为原点。
    var child = lastChild;
    while (child != null) {
      final childParentData = child.parentData! as ToolbarItemsParentData;

      // 不要对未显示的子项进行命中测试。
      if (!childParentData.shouldPaint) {
        child = childParentData.previousSibling;
        continue;
      }

      final isHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          assert(transformed == position - childParentData.offset);
          return child!.hitTest(result, position: transformed);
        },
      );
      if (isHit) {
        return true;
      }
      child = childParentData.previousSibling;
    }
    return false;
  }

  // 仅访问应该被绘制的子项。
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitChildren((RenderObject renderObjectChild) {
      final child = renderObjectChild as RenderBox;
      final childParentData = child.parentData! as ToolbarItemsParentData;
      if (childParentData.shouldPaint) {
        visitor(renderObjectChild);
      }
    });
  }
}

// Material 风格的工具栏轮廓。用任何你想要的小部件填充它。没有溢出能力。
class _TextSelectionToolbarContainer extends StatelessWidget {
  const _TextSelectionToolbarContainer({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      // 此值是在运行 Android 10 的 Pixel 2 上目测以匹配原生文本选择菜单。
      borderRadius: const BorderRadius.all(Radius.circular(7.0)),
      clipBehavior: Clip.antiAlias,
      elevation: 1.0,
      type: MaterialType.card,
      child: child,
    );
  }
}

// 样式类似于 Material 原生 Android 文本选择溢出菜单前进和后退控件的按钮。
class _TextSelectionToolbarOverflowButton extends StatelessWidget {
  const _TextSelectionToolbarOverflowButton({
    required this.icon,
    this.onPressed,
    // ignore: unused_element_parameter
    this.tooltip,
  });

  final Icon icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.card,
      color: const Color(0x00000000),
      child: IconButton(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}
