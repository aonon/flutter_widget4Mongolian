// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Examples can assume:
// void setState(VoidCallback fn) { }
// bool _isSelected = true;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import 'mongol_list_tile.dart';
import 'mongol_checkbox_list_tile.dart';
import 'mongol_radio_list_tile.dart';
import '../text/mongol_text.dart';
import '../text/mongol_rich_text.dart';

/// 开关列表项的类型枚举
///
/// - material: 使用 Material 风格的开关
/// - adaptive: 根据平台自动适配风格的开关（iOS/macOS 上使用 Cupertino 风格，其他平台使用 Material 风格）
enum _SwitchListTileType { material, adaptive }

/// 一个带有旋转开关的 [MongolListTile]，换句话说，就是一个带标签的开关。
///
/// 整个列表项都是可交互的：点击列表项的任何地方都会切换开关状态。
/// 点击并拖动 [Switch] 也会触发 [onChanged] 回调。
///
/// 为了确保 [onChanged] 正确触发，传递给 [value] 的状态必须被正确管理。
/// 通常是通过在 [onChanged] 中调用 [State.setState] 来切换状态值。
///
/// 此小部件的 [value]、[onChanged]、[activeColor]、[activeThumbImage] 和
/// [inactiveThumbImage] 属性与 [Switch] 小部件上的同名属性相同。
///
/// [title]、[subtitle]、[isThreeLine] 和 [dense] 属性与
/// [MongolListTile] 上的同名属性类似。
///
/// 此小部件上的 [selected] 属性类似于 [MongolListTile.selected] 属性。
/// 选中项的文本颜色使用此 tile 的 [activeColor]，如果 [activeColor] 为 null，则使用主题的
/// [SwitchThemeData.overlayColor]。
///
/// 此小部件不会协调 [selected] 状态和 [value] 状态；
/// 要使列表项在开关打开时显示为选中状态，请为两者使用相同的值。
///
/// 开关默认显示在底部（即 [MongolListTile.trailing] 位置），
/// 可以使用 [controlAffinity] 更改。[secondary] 小部件放置在
/// [MongolListTile.leading] 位置。
///
/// 此小部件需要树中有 [Material] 小部件祖先来绘制自身，
/// 这通常由应用程序的 [Scaffold] 提供。[tileColor] 和 [selectedTileColor]
/// 不是由 [MongolSwitchListTile] 本身绘制的，而是由 [Material] 小部件祖先绘制的。
/// 在这种情况下，可以在 [MongolSwitchListTile] 周围包装一个 [Material] 小部件，例如：
///
/// ```dart
/// ColoredBox(
///   color: Colors.green,
///   child: Material(
///     child: MongolSwitchListTile(
///       tileColor: Colors.red,
///       title: const MongolText('MongolSwitchListTile with red background'),
///       value: true,
///       onChanged:(bool? value) { },
///     ),
///   ),
/// )
/// ```
///
/// ## 性能考虑
///
/// 单独用 [Material] 包装大量 [MongolSwitchListTile] 是昂贵的。
/// 考虑只包装需要它的 [MongolSwitchListTile]，或者在可能的情况下包含一个公共的 [Material] 祖先。
///
/// 要显示禁用的 [MongolSwitchListTile]，请将 null 作为 [onChanged] 回调传递。
///
/// ## MongolSwitchListTile 中的语义
///
/// 由于整个 MongolSwitchListTile 都是交互式的，它应该将自己表示为一个单一的交互实体。
///
/// 为此，MongolSwitchListTile 小部件用 [MergeSemantics] 小部件包装其子女。
/// [MergeSemantics] 将尝试将其后代 [Semantics] 节点合并到语义树中的一个节点中。
/// 因此，如果其任何子女需要自己的 [Semantics] 节点，MongolSwitchListTile 将抛出错误。
///
/// 例如，不能将 [MongolRichText] 小部件嵌套为 MongolSwitchListTile 的后代。
/// [MongolRichText] 有一个嵌入的手势识别器，需要自己的 [Semantics] 节点，
/// 这直接与 MongolSwitchListTile 将所有后代语义节点合并为一个的愿望相冲突。
/// 因此，可能需要创建一个自定义的单选 tile 小部件来适应类似的用例。
///
/// ## 自定义开关列表项
///
/// 如果 MongolSwitchListTile 填充和定位其元素的方式不完全符合您的要求，
/// 您可以通过将 [Switch] 与其他小部件（如 [MongolText]、[Padding] 和 [InkWell]）
/// 组合来创建自定义标签开关小部件。
///
/// 另请参阅：
///
///  * [MongolListTileTheme]，可用于影响列表项的样式，包括开关列表项。
///  * [MongolCheckboxListTile]，用于复选框的类似小部件。
///  * [MongolRadioListTile]，用于单选按钮的类似小部件。
///  * [MongolListTile] 和 [Switch]，此小部件由这些小部件组成。
class MongolSwitchListTile extends StatelessWidget {
  /// 创建一个列表项和开关的组合。
  ///
  /// 开关 tile 本身不维护任何状态。相反，当开关状态改变时，
  /// 小部件会调用 [onChanged] 回调。大多数使用开关的小部件会监听 [onChanged] 回调，
  /// 并使用新的 [value] 重建开关 tile 以更新开关的视觉外观。
  ///
  /// 以下参数是必需的：
  ///
  /// * [value] 确定此开关是打开还是关闭。
  /// * [onChanged] 在用户切换开关打开或关闭时调用。
  const MongolSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.activeTrackColor,
    this.inactiveThumbColor,
    this.inactiveTrackColor,
    this.activeThumbImage,
    this.onActiveThumbImageError,
    this.inactiveThumbImage,
    this.onInactiveThumbImageError,
    this.thumbColor,
    this.trackColor,
    this.trackOutlineColor,
    this.thumbIcon,
    this.materialTapTargetSize,
    this.dragStartBehavior = DragStartBehavior.start,
    this.mouseCursor,
    this.overlayColor,
    this.splashRadius,
    this.focusNode,
    this.onFocusChange,
    this.autofocus = false,
    this.tileColor,
    this.title,
    this.subtitle,
    this.isThreeLine = false,
    this.dense,
    this.contentPadding,
    this.secondary,
    this.selected = false,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.shape,
    this.selectedTileColor,
    this.visualDensity,
    this.enableFeedback,
    this.hoverColor,
  })  : _switchListTileType = _SwitchListTileType.material,
        applyCupertinoTheme = false,
        assert(activeThumbImage != null || onActiveThumbImageError == null),
        assert(inactiveThumbImage != null || onInactiveThumbImageError == null),
        assert(!isThreeLine || subtitle != null);

  /// 创建一个带有自适应开关的 Material [ListTile]，遵循 Material 设计的
  /// [跨平台指南](https://material.io/design/platform-guidance/cross-platform-adaptation.html)。
  ///
  /// 此小部件使用 [Switch.adaptive] 根据环境 [ThemeData.platform] 更改开关组件的图形。
  /// 在 iOS 和 macOS 上，将使用 [CupertinoSwitch]。在其他平台上，将使用 Material 设计的 [Switch]。
  ///
  /// 如果创建了 [CupertinoSwitch]，则忽略以下参数：
  /// [activeTrackColor]、[inactiveThumbColor]、[inactiveTrackColor]、
  /// [activeThumbImage]、[inactiveThumbImage]。
  const MongolSwitchListTile.adaptive({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.activeTrackColor,
    this.inactiveThumbColor,
    this.inactiveTrackColor,
    this.activeThumbImage,
    this.onActiveThumbImageError,
    this.inactiveThumbImage,
    this.onInactiveThumbImageError,
    this.thumbColor,
    this.trackColor,
    this.trackOutlineColor,
    this.thumbIcon,
    this.materialTapTargetSize,
    this.dragStartBehavior = DragStartBehavior.start,
    this.mouseCursor,
    this.overlayColor,
    this.splashRadius,
    this.focusNode,
    this.onFocusChange,
    this.autofocus = false,
    this.applyCupertinoTheme,
    this.tileColor,
    this.title,
    this.subtitle,
    this.isThreeLine = false,
    this.dense,
    this.contentPadding,
    this.secondary,
    this.selected = false,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.shape,
    this.selectedTileColor,
    this.visualDensity,
    this.enableFeedback,
    this.hoverColor,
  })  : _switchListTileType = _SwitchListTileType.adaptive,
        assert(!isThreeLine || subtitle != null),
        assert(activeThumbImage != null || onActiveThumbImageError == null),
        assert(inactiveThumbImage != null || onInactiveThumbImageError == null);

  /// 此开关是否被选中。
  final bool value;

  /// 在用户切换开关打开或关闭时调用。
  ///
  /// 开关将新值传递给回调，但实际上不会改变状态，
  /// 直到父小部件使用新值重建开关 tile。
  ///
  /// 如果为 null，开关将显示为禁用状态。
  ///
  /// 提供给 [onChanged] 的回调应使用 [State.setState] 方法更新父 [StatefulWidget] 的状态，
  /// 以便父小部件得到重建；例如：
  ///
  /// ```dart
  /// SwitchListTile(
  ///   value: _isSelected,
  ///   onChanged: (bool newValue) {
  ///     setState(() {
  ///       _isSelected = newValue;
  ///     });
  ///   },
  ///   title: const Text('Selection'),
  /// )
  /// ```
  final ValueChanged<bool>? onChanged;

  /// 开关激活状态的颜色。
  ///
  /// 默认为当前 [Theme] 的 [ColorScheme.secondary]。
  final Color? activeColor;

  /// 开关激活状态下滑道的颜色。
  ///
  /// 默认为 [ThemeData.toggleableActiveColor]，不透明度设置为 50%。
  ///
  /// 如果使用 [SwitchListTile.adaptive] 创建，则忽略此参数。
  final Color? activeTrackColor;

  /// 开关非激活状态下thumb的颜色。
  ///
  /// 默认为 Material 设计规范中描述的颜色。
  ///
  /// 如果使用 [SwitchListTile.adaptive] 创建，则忽略此参数。
  final Color? inactiveThumbColor;

  /// 开关非激活状态下滑道的颜色。
  ///
  /// 默认为 Material 设计规范中描述的颜色。
  ///
  /// 如果使用 [SwitchListTile.adaptive] 创建，则忽略此参数。
  final Color? inactiveTrackColor;

  /// 开关激活状态下thumb的图像。
  final ImageProvider? activeThumbImage;

  /// 当激活状态下thumb图像加载失败时调用的回调。
  final ImageErrorListener? onActiveThumbImageError;

  /// 开关非激活状态下thumb的图像。
  ///
  /// 如果使用 [SwitchListTile.adaptive] 创建，则忽略此参数。
  final ImageProvider? inactiveThumbImage;

  /// 当非激活状态下thumb图像加载失败时调用的回调。
  final ImageErrorListener? onInactiveThumbImageError;

  /// 此开关thumb的颜色。
  ///
  /// 在以下状态中解析：
  ///  * [WidgetState.selected]（选中状态）。
  ///  * [WidgetState.hovered]（悬停状态）。
  ///  * [WidgetState.disabled]（禁用状态）。
  ///
  /// 如果为 null，则在选中状态下使用 [activeColor] 的值，
  /// 在默认状态下使用 [inactiveThumbColor] 的值。如果这也是 null，
  /// 则使用 [SwitchThemeData.thumbColor] 的值。如果这也是 null，
  /// 则使用默认值。
  final WidgetStateProperty<Color?>? thumbColor;

  /// 此开关滑道的颜色。
  ///
  /// 在以下状态中解析：
  ///  * [WidgetState.selected]（选中状态）。
  ///  * [WidgetState.hovered]（悬停状态）。
  ///  * [WidgetState.disabled]（禁用状态）。
  ///
  /// 如果为 null，则在选中状态下使用 [activeTrackColor] 的值，
  /// 在默认状态下使用 [inactiveTrackColor] 的值。如果这也是 null，
  /// 则使用 [SwitchThemeData.trackColor] 的值。如果这也是 null，
  /// 则使用默认值。
  final WidgetStateProperty<Color?>? trackColor;

  /// 此开关滑道轮廓的颜色。
  ///
  /// 当此 [SwitchListTile] 请求焦点时，[ListTile] 将获得焦点，
  /// 因此开关的焦点轮廓颜色将被忽略。
  ///
  /// 在 Material 3 中，轮廓颜色在选中状态下默认为透明，
  /// 在未选中状态下默认为 [ColorScheme.outline]。在 Material 2 中，
  /// [Switch] 滑道没有轮廓。
  final WidgetStateProperty<Color?>? trackOutlineColor;

  /// 此开关thumb上使用的图标。
  ///
  /// 在以下状态中解析：
  ///  * [WidgetState.selected]（选中状态）。
  ///  * [WidgetState.hovered]（悬停状态）。
  ///  * [WidgetState.disabled]（禁用状态）。
  ///
  /// 如果为 null，则使用 [SwitchThemeData.thumbIcon] 的值。如果这也是 null，
  /// 则 [Switch] 的thumb上没有任何图标。
  final WidgetStateProperty<Icon?>? thumbIcon;

  /// 开关的点击目标大小。
  ///
  /// 默认为 [MaterialTapTargetSize.shrinkWrap]。
  final MaterialTapTargetSize? materialTapTargetSize;

  /// 拖动开始的行为方式。
  final DragStartBehavior dragStartBehavior;

  /// 鼠标指针进入或悬停在小部件上时的光标。
  ///
  /// 如果 [mouseCursor] 是 [MaterialStateProperty<MouseCursor>]，
  /// 则 [WidgetStateProperty.resolve] 用于以下 [WidgetState]：
  ///
  ///  * [WidgetState.selected]（选中状态）。
  ///  * [WidgetState.hovered]（悬停状态）。
  ///  * [WidgetState.disabled]（禁用状态）。
  ///
  /// 如果为 null，则使用 [SwitchThemeData.mouseCursor] 的值。如果这也是 null，
  /// 则使用 [WidgetStateMouseCursor.clickable]。
  final MouseCursor? mouseCursor;

  /// 开关 [Material] 的颜色。
  ///
  /// 在以下状态中解析：
  ///  * [WidgetState.pressed]（按下状态）。
  ///  * [WidgetState.selected]（选中状态）。
  ///  * [WidgetState.hovered]（悬停状态）。
  ///
  /// 如果为 null，则在按下和悬停状态下使用带有 alpha [kRadialReactionAlpha] 的 [activeColor] 值
  /// 和 [hoverColor]。如果这也是 null，则使用 [SwitchThemeData.overlayColor] 的值。
  /// 如果这也是 null，则在按下和悬停状态下使用默认值。
  final WidgetStateProperty<Color?>? overlayColor;

  /// 开关按下时水波纹效果的半径。
  ///
  /// 如果为 null，则使用 [SwitchThemeData.splashRadius] 的值。如果这也是 null，
  /// 则使用 [kRadialReactionRadius]。
  final double? splashRadius;

  /// 用于控制此小部件的焦点状态的焦点节点。
  final FocusNode? focusNode;

  /// 当此小部件的焦点状态改变时调用的回调。
  final ValueChanged<bool>? onFocusChange;

  /// 是否在首次构建时自动获取焦点。
  final bool autofocus;

  /// 列表项的背景颜色。
  final Color? tileColor;

  /// 列表项的主要内容。
  ///
  /// 通常是一个 [Text] 小部件。
  final Widget? title;

  /// 显示在标题下方的附加内容。
  ///
  /// 通常是一个 [Text] 小部件。
  final Widget? subtitle;

  /// 显示在与开关相反一侧的小部件。
  ///
  /// 通常是一个 [Icon] 小部件。
  final Widget? secondary;

  /// 此列表项是否旨在显示三行文本。
  ///
  /// 如果为 false，则当 subtitle 为 null 时，列表项被视为有一行，
  /// 当 subtitle 不为 null 时，列表项被视为有两行。
  final bool isThreeLine;

  /// 此列表项是否属于垂直密集列表的一部分。
  ///
  /// 如果此属性为 null，则其值基于 [ListTileThemeData.dense]。
  final bool? dense;

  /// 列表项的内部边距。
  ///
  /// 为 [SwitchListTile] 的内容设置内边距：其 [title]、[subtitle]、
  /// [secondary] 和 [Switch] 小部件。
  ///
  /// 如果为 null，则使用 [ListTile] 的默认值 `EdgeInsets.symmetric(horizontal: 16.0)`。
  final EdgeInsetsGeometry? contentPadding;

  /// 是否以 [activeColor] 渲染图标和文本。
  ///
  /// 不会自动协调 [selected] 状态和 [value] 状态。
  /// 要使列表项在开关打开时显示为选中状态，请为两者传递相同的值。
  ///
  /// 通常，此属性保持其默认值 false。
  final bool selected;

  /// 开关列表项的类型。
  ///
  /// 如果是 adaptive，则使用 [Switch.adaptive] 创建开关。
  final _SwitchListTileType _switchListTileType;

  /// 定义控件和 [secondary] 相对于文本的位置。
  ///
  /// 默认情况下，[controlAffinity] 的值为 [ListTileControlAffinity.platform]。
  final ListTileControlAffinity controlAffinity;

  /// 列表项的形状。
  final ShapeBorder? shape;

  /// 如果不为 null，则定义 [SwitchListTile.selected] 为 true 时的背景颜色。
  final Color? selectedTileColor;

  /// 定义列表项布局的紧凑程度。
  ///
  /// 控制列表项的垂直和水平间距。
  final VisualDensity? visualDensity;

  /// 是否为点击提供平台特定的反馈。
  ///
  /// 另请参阅：
  ///
  ///  * [Feedback] 用于为某些操作提供平台特定的反馈。
  final bool? enableFeedback;

  /// 当指针悬停在列表项 [Material] 上时的颜色。
  final Color? hoverColor;

  /// 是否应用 Cupertino 主题到 CupertinoSwitch。
  final bool? applyCupertinoTheme;

  /// 构建此小部件的 UI。
  ///
  /// 根据 [_switchListTileType] 创建适当类型的开关，
  /// 将开关旋转 90 度使其垂直显示，
  /// 根据 [controlAffinity] 确定开关和 secondary 小部件的位置，
  /// 计算有效的激活颜色，
  /// 最后返回一个包含所有内容的 [MongolListTile]。
  @override
  Widget build(BuildContext context) {
    Widget control;
    switch (_switchListTileType) {
      case _SwitchListTileType.adaptive:
        control = Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: activeColor,
          activeThumbImage: activeThumbImage,
          inactiveThumbImage: inactiveThumbImage,
          materialTapTargetSize:
              materialTapTargetSize ?? MaterialTapTargetSize.shrinkWrap,
          activeTrackColor: activeTrackColor,
          inactiveTrackColor: inactiveTrackColor,
          inactiveThumbColor: inactiveThumbColor,
          autofocus: autofocus,
          onFocusChange: onFocusChange,
          onActiveThumbImageError: onActiveThumbImageError,
          onInactiveThumbImageError: onInactiveThumbImageError,
          thumbColor: thumbColor,
          trackColor: trackColor,
          trackOutlineColor: trackOutlineColor,
          thumbIcon: thumbIcon,
          applyCupertinoTheme: applyCupertinoTheme,
          dragStartBehavior: dragStartBehavior,
          mouseCursor: mouseCursor,
          splashRadius: splashRadius,
          overlayColor: overlayColor,
        );

      case _SwitchListTileType.material:
        control = Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: activeColor,
          activeThumbImage: activeThumbImage,
          inactiveThumbImage: inactiveThumbImage,
          materialTapTargetSize:
              materialTapTargetSize ?? MaterialTapTargetSize.shrinkWrap,
          activeTrackColor: activeTrackColor,
          inactiveTrackColor: inactiveTrackColor,
          inactiveThumbColor: inactiveThumbColor,
          autofocus: autofocus,
          onFocusChange: onFocusChange,
          onActiveThumbImageError: onActiveThumbImageError,
          onInactiveThumbImageError: onInactiveThumbImageError,
          thumbColor: thumbColor,
          trackColor: trackColor,
          trackOutlineColor: trackOutlineColor,
          thumbIcon: thumbIcon,
          dragStartBehavior: dragStartBehavior,
          mouseCursor: mouseCursor,
          splashRadius: splashRadius,
          overlayColor: overlayColor,
        );
    }

    // rotate the switch 90 degrees to make it vertical
    control = RotatedBox(quarterTurns: 1, child: control);

    Widget? leading, trailing;
    switch (controlAffinity) {
      case ListTileControlAffinity.leading:
        leading = control;
        trailing = secondary;
      case ListTileControlAffinity.trailing:
      case ListTileControlAffinity.platform:
        leading = secondary;
        trailing = control;
    }

    final ThemeData theme = Theme.of(context);
    final SwitchThemeData switchTheme = SwitchTheme.of(context);
    final Set<WidgetState> states = <WidgetState>{
      if (selected) WidgetState.selected,
    };
    final Color effectiveActiveColor = activeColor ??
        switchTheme.thumbColor?.resolve(states) ??
        theme.colorScheme.secondary;
    return MergeSemantics(
      child: MongolListTile(
        selectedColor: effectiveActiveColor,
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        isThreeLine: isThreeLine,
        dense: dense,
        contentPadding: contentPadding,
        enabled: onChanged != null,
        onTap: onChanged != null
            ? () {
                onChanged!(!value);
              }
            : null,
        selected: selected,
        selectedTileColor: selectedTileColor,
        autofocus: autofocus,
        shape: shape,
        tileColor: tileColor,
        visualDensity: visualDensity,
        focusNode: focusNode,
        onFocusChange: onFocusChange,
        enableFeedback: enableFeedback,
        hoverColor: hoverColor,
      ),
    );
  }
}
