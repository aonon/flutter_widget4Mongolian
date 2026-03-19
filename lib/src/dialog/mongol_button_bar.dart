// Copyright 2014 The Flutter Authors.
// Copyright 2020 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 这些类是从 Flutter 的 [OverflowBar] 改编而来的
/// 用于垂直布局的蒙古文按钮栏组件

/// 垂直排列的按钮栏组件，用于在垂直方向上布局多个按钮
/// 这是一个无状态组件，用于在垂直方向上展示一组按钮
class MongolButtonBar extends StatelessWidget {
  /// 创建一个垂直排列的按钮栏
  /// 
  /// [key]：组件的唯一标识符
  /// [alignment]：子组件在垂直轴上的对齐方式
  /// [mainAxisSize]：水平空间的可用大小
  /// [buttonTextTheme]：按钮文本主题
  /// [buttonMinWidth]：按钮最小宽度
  /// [buttonHeight]：按钮高度
  /// [buttonPadding]：按钮内边距
  /// [layoutBehavior]：布局行为
  /// [children]：要排列的按钮列表
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

  /// 子组件在垂直轴上的对齐方式
  ///
  /// 如果为 null，则使用 [ButtonBarTheme.alignment]。如果那也为 null，
  /// 则默认为 [MainAxisAlignment.end]（底部对齐）。
  final MainAxisAlignment? alignment;

  /// 水平空间的可用大小。请参见 [Column.mainAxisSize]。
  ///
  /// 如果为 null，则使用周围的 [ButtonBarTheme.mainAxisSize]。
  /// 如果那也为 null，则默认为 [MainAxisSize.max]（最大宽度）。
  final MainAxisSize? mainAxisSize;

  /// 按钮文本主题，控制按钮文本的样式
  final ButtonTextTheme? buttonTextTheme;

  /// 按钮的最小宽度
  final double? buttonMinWidth;

  /// 按钮的高度
  final double? buttonHeight;

  /// 按钮的内边距
  final EdgeInsetsGeometry? buttonPadding;

  /// 布局行为，控制按钮栏的布局方式
  final ButtonBarLayoutBehavior? layoutBehavior;

  /// 要在水平方向上排列的按钮
  ///
  /// 通常是使用 [MongolText] 的 [ElevatedButton] 或 [TextButton] 组件。
  final List<Widget> children;

  /// 构建按钮栏组件
  /// 
  /// [context]：构建上下文
  /// 返回：构建好的按钮栏组件
  @override
  Widget build(BuildContext context) {
    // 获取父级按钮主题
    final parentButtonTheme = ButtonTheme.of(context);
    // 获取按钮栏主题
    final barTheme = ButtonBarTheme.of(context);

    // 创建按钮主题，优先使用传入的参数，然后是主题中的值，最后是默认值
    final buttonTheme = parentButtonTheme.copyWith(
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

    // 计算内边距单位
    final paddingUnit = buttonTheme.padding.vertical / 4.0;
    // 创建按钮栏列组件
    final Widget child = ButtonTheme.fromButtonThemeData(
      data: buttonTheme,
      child: _ButtonBarColumn(
        mainAxisAlignment:
            alignment ?? barTheme.alignment ?? MainAxisAlignment.end,
        mainAxisSize: mainAxisSize ?? barTheme.mainAxisSize ?? MainAxisSize.max,
        children: children.map<Widget>((Widget child) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: paddingUnit),
            child: child,
          );
        }).toList(),
      ),
    );
    // 根据布局行为返回不同的包装组件
    switch (buttonTheme.layoutBehavior) {
      case ButtonBarLayoutBehavior.padded:
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 2.0 * paddingUnit,
            vertical: paddingUnit,
          ),
          child: child,
        );
      default: // ButtonBarLayoutBehavior.constrained:
        return Container(
          padding: EdgeInsets.symmetric(vertical: paddingUnit),
          constraints: const BoxConstraints(minWidth: 52.0),
          alignment: Alignment.center,
          child: child,
        );
    }
  }
}

/// 按钮栏的列布局组件
/// 尝试在列中显示按钮，但如果垂直空间不足，则在行中显示
class _ButtonBarColumn extends Flex {
  /// 创建一个按钮栏列布局
  /// 
  /// [children]：要布局的子组件列表
  /// [direction]：布局方向，默认为垂直方向
  /// [mainAxisSize]：主轴大小，默认为最大
  /// [mainAxisAlignment]：主轴对齐方式，默认为起始对齐
  /// [crossAxisAlignment]：交叉轴对齐方式，默认为居中对齐
  const _ButtonBarColumn({
    required super.children,
    super.direction = Axis.vertical,
    super.mainAxisSize,
    super.mainAxisAlignment,
  });

  /// 创建渲染对象
  /// 
  /// [context]：构建上下文
  /// 返回：创建的渲染对象
  @override
  _RenderButtonBarColumn createRenderObject(BuildContext context) {
    return _RenderButtonBarColumn(
      direction: direction,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
    );
  }

  /// 更新渲染对象
  /// 
  /// [context]：构建上下文
  /// [renderObject]：要更新的渲染对象
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

/// 按钮栏列的渲染对象
/// 处理按钮栏的布局逻辑，包括垂直空间不足时的水平排列
class _RenderButtonBarColumn extends RenderFlex {
  /// 创建一个按钮栏列的渲染对象
  /// 
  /// [children]：子渲染对象列表
  /// [direction]：布局方向，默认为垂直方向
  /// [mainAxisSize]：主轴大小，默认为最大
  /// [mainAxisAlignment]：主轴对齐方式，默认为起始对齐
  /// [crossAxisAlignment]：交叉轴对齐方式，默认为居中对齐
  _RenderButtonBarColumn({
    super.direction = Axis.vertical,
    super.mainAxisSize,
    super.mainAxisAlignment,
    super.crossAxisAlignment,
  });

  /// 是否已经检查了布局高度
  bool _hasCheckedLayoutHeight = false;

  /// 获取约束条件
  /// 
  /// 返回：修改后的约束条件
  @override
  BoxConstraints get constraints {
    if (_hasCheckedLayoutHeight) return super.constraints;
    // 如果还没有检查布局高度，则设置最大高度为无限
    return super.constraints.copyWith(maxHeight: double.infinity);
  }

  /// 执行布局
  /// 
  /// 首先尝试垂直布局，如果空间不足则改为水平布局
  @override
  void performLayout() {
    // 重置布局高度检查标志
    _hasCheckedLayoutHeight = false;

    // 先执行默认的布局（垂直布局）
    super.performLayout();
    // 标记已检查布局高度
    _hasCheckedLayoutHeight = true;

    // 如果垂直空间足够，保持垂直布局
    if (size.height <= constraints.maxHeight) {
      super.performLayout();
    } else {
      // 如果垂直空间不足，改为水平布局
      final childConstraints = constraints.copyWith(minHeight: 0.0);
      RenderBox? child;
      var currentWidth = 0.0;
      child = firstChild;

      // 遍历所有子组件
      while (child != null) {
        final childParentData = child.parentData as FlexParentData;
        // 布局子组件
        child.layout(childConstraints, parentUsesSize: true);
        // 根据对齐方式设置子组件的偏移
        switch (mainAxisAlignment) {
          case MainAxisAlignment.center:
            final midpoint = (constraints.maxHeight - child.size.height) / 2.0;
            childParentData.offset = Offset(midpoint, currentWidth);
            break;
          case MainAxisAlignment.end:
            childParentData.offset =
                Offset(constraints.maxHeight - child.size.height, currentWidth);
            break;
          default:
            childParentData.offset = Offset(0, currentWidth);
            break;
        }
        // 更新当前宽度
        currentWidth += child.size.width;
        // 获取下一个子组件
        child = childParentData.nextSibling;
      }
      // 设置渲染对象的大小
      size = constraints.constrain(Size(constraints.maxHeight, currentWidth));
    }
  }
}
