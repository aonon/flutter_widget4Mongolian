// Copyright 2014 The Flutter Authors.
// Copyright 2020 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 改编自 Flutter 的 [OverflowBar]，用于垂直文本布局。
/// 上下排列按钮并自动处理溢出。
class MongolButtonBar extends StatelessWidget {
  /// 创建按钮栏。
  const MongolButtonBar({
    super.key,
    this.alignment,
    this.mainAxisSize,
    this.buttonTextTheme,
    this.buttonMinWidth,
    this.buttonHeight,
    this.buttonPadding,
    this.layoutBehavior,
    this.children = const <Widget>[],
  })  : assert(buttonMinWidth == null || buttonMinWidth >= 0.0),
        assert(buttonHeight == null || buttonHeight >= 0.0);

  /// 按钮的对齐方式。默认为 [MainAxisAlignment.end]（右/下校准）。
  /// 需需覆盖[ButtonBarTheme.alignment]参数可改变主题。
  final MainAxisAlignment? alignment;

  /// 按钮应占据的空间。
  /// 默认为 [MainAxisSize.max]。参考 [ButtonBarTheme.mainAxisSize]。
  final MainAxisSize? mainAxisSize;

  /// 控制按钮文本样式。
  final ButtonTextTheme? buttonTextTheme;

  /// 按钮最小宽度。默认为 36.0。
  final double? buttonMinWidth;

  /// 按钮高度。默认为 64.0。
  final double? buttonHeight;

  /// 按钮内边距。默认为 8.0 纵向。
  final EdgeInsetsGeometry? buttonPadding;

  /// 布局模式：[ButtonBarLayoutBehavior.padded]（默认）或 constrained。
  final ButtonBarLayoutBehavior? layoutBehavior;

  /// 要排列的按钮（通常为 [ElevatedButton] 或 [TextButton]）。
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final buttonTheme = _resolveButtonTheme(context);
    final paddingUnit = buttonTheme.padding.vertical / 4.0;

    final columnChild = _buildButtonColumn(context, buttonTheme, paddingUnit);

    return _wrapWithLayoutBehavior(columnChild, buttonTheme, paddingUnit);
  }

  /// 解析按钮主题配置。
  ButtonThemeData _resolveButtonTheme(BuildContext context) {
    final parentButtonTheme = ButtonTheme.of(context);
    final barTheme = ButtonBarTheme.of(context);

    return parentButtonTheme.copyWith(
      textTheme: buttonTextTheme ??
          barTheme.buttonTextTheme ??
          ButtonTextTheme.primary,
      minWidth: buttonMinWidth ?? barTheme.buttonMinWidth ?? 36.0,
      height: buttonHeight ?? barTheme.buttonHeight ?? 64.0,
      padding: buttonPadding ??
          barTheme.buttonPadding ??
          const EdgeInsets.symmetric(vertical: 8.0),
      alignedDropdown: false,
      layoutBehavior: layoutBehavior ??
          barTheme.layoutBehavior ??
          ButtonBarLayoutBehavior.padded,
    );
  }

  /// 构建按钮栏列组的子组件。
  Widget _buildButtonColumn(
    BuildContext context,
    ButtonThemeData buttonTheme,
    double paddingUnit,
  ) {
    return ButtonTheme.fromButtonThemeData(
      data: buttonTheme,
      child: _ButtonBarColumn(
        mainAxisAlignment: alignment ??
            ButtonBarTheme.of(context).alignment ??
            MainAxisAlignment.end,
        mainAxisSize: mainAxisSize ??
            ButtonBarTheme.of(context).mainAxisSize ??
            MainAxisSize.max,
        children: children.map<Widget>((Widget button) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: paddingUnit),
            child: button,
          );
        }).toList(),
      ),
    );
  }

  /// 根据布局模式对欧组件进行包装。
  Widget _wrapWithLayoutBehavior(
    Widget child,
    ButtonThemeData buttonTheme,
    double paddingUnit,
  ) {
    return switch (buttonTheme.layoutBehavior) {
      ButtonBarLayoutBehavior.padded => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 2.0 * paddingUnit,
            vertical: paddingUnit,
          ),
          child: child,
        ),
      _ => Container(
          padding: EdgeInsets.symmetric(vertical: paddingUnit),
          constraints: const BoxConstraints(minWidth: 52.0),
          alignment: Alignment.center,
          child: child,
        ),
    };
  }
}

/// 按钮栏列的内部布局组件。
/// 如果垂直空间不足，则回滚到水平布局。
class _ButtonBarColumn extends Flex {
  const _ButtonBarColumn({
    required super.children,
    super.direction = Axis.vertical,
    super.mainAxisSize,
    super.mainAxisAlignment,
  });

  @override
  _RenderButtonBarColumn createRenderObject(BuildContext context) {
    return _RenderButtonBarColumn(
      direction: direction,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderButtonBarColumn renderObject) {
    renderObject
      ..direction = direction
      ..mainAxisAlignment = mainAxisAlignment
      ..mainAxisSize = mainAxisSize
      ..crossAxisAlignment = crossAxisAlignment;
  }
}

/// 按钮栏列的渲染对象。
/// 尝试垂直布局，砥直空间不足时切换为水平布局。
class _RenderButtonBarColumn extends RenderFlex {
  _RenderButtonBarColumn({
    super.direction = Axis.vertical,
    super.mainAxisSize,
    super.mainAxisAlignment,
    super.crossAxisAlignment,
  });

  bool _hasCheckedLayoutHeight = false;

  @override
  BoxConstraints get constraints {
    if (_hasCheckedLayoutHeight) return super.constraints;
    return super.constraints.copyWith(maxHeight: double.infinity);
  }

  @override
  void performLayout() {
    _hasCheckedLayoutHeight = false;
    super.performLayout();
    _hasCheckedLayoutHeight = true;

    if (size.height <= constraints.maxHeight) {
      super.performLayout();
    } else {
      // 灾直空间不足，切换到水平布局
      final childConstraints = constraints.copyWith(minHeight: 0.0);
      RenderBox? child;
      var currentWidth = 0.0;
      child = firstChild;

      while (child != null) {
        final childParentData = child.parentData as FlexParentData;
        child.layout(childConstraints, parentUsesSize: true);

        switch (mainAxisAlignment) {
          case MainAxisAlignment.center:
            final midpoint = (constraints.maxHeight - child.size.height) / 2.0;
            childParentData.offset = Offset(midpoint, currentWidth);
          case MainAxisAlignment.end:
            childParentData.offset =
                Offset(constraints.maxHeight - child.size.height, currentWidth);
          default:
            childParentData.offset = Offset(0, currentWidth);
        }

        currentWidth += child.size.width;
        child = childParentData.nextSibling;
      }

      size = constraints.constrain(Size(constraints.maxHeight, currentWidth));
    }
  }
}
