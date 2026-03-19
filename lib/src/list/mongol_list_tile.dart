// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show
        ColorScheme,
        Colors,
        Divider,
        IconButton,
        IconButtonTheme,
        IconButtonThemeData,
        Ink,
        InkWell,
        ListTileStyle,
        WidgetState,
        WidgetStateColor,
        WidgetStateMouseCursor,
        WidgetStateProperty,
        TextTheme,
        Theme,
        ThemeData,
        VisualDensity,
        debugCheckHasMaterial,
        kThemeChangeDuration;
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'mongol_checkbox_list_tile.dart';
import 'mongol_radio_list_tile.dart';
import 'mongol_switch_list_tile.dart';

/// 与 [MongolListTileTheme] 一起使用，为后代 [MongolListTile] 小部件定义默认属性值
///
/// 以及构建 [MongolListTile] 的类，如 [MongolCheckboxListTile]、[MongolRadioListTile] 和
/// [MongolSwitchListTile]。
///
/// 后代小部件使用 `MongolListTileTheme.of(context)` 获取当前的 [MongolListTileThemeData] 对象。
/// [MongolListTileThemeData] 的实例可以通过 [MongolListTileThemeData.copyWith] 进行自定义。
///
/// 与 Flutter 的 [ListTileThemeData] 不同，[MongolListTileThemeData] 不是通过 [ThemeData.listTileTheme]
/// 作为整体 [Theme] 的一部分指定的。相反，[MongolListTileThemeData] 在 [MongolListTileTheme.data] 中指定，
/// 并且 MongolListTileTheme 放置在小部件树的顶部，为子树指定主题。
/// 请参阅下面的示例代码。
/// ```dart
/// return MaterialApp(
///   title: 'mongol',
///   home: MongolListTileTheme(
///     data: MongolListTileThemeData(
///       minHorizontalPadding: 20,
///     ),
///     child: Scaffold(
///       appBar: AppBar(title: const Text(versionTitle)),
///       body: const HomeScreen(),
///     ),
///   )
/// );
///```
///
/// 所有 [MongolListTileThemeData] 属性默认为 `null`。
/// 当主题属性为 null 时，[MongolListTile] 将根据整体 [Theme] 的 textTheme 和
/// colorScheme 提供自己的默认值。有关详细信息，请参阅各个 [MongolListTile] 属性。
///
/// [Drawer] 小部件为其子女指定了一个列表 tile 主题，将 [style] 定义为 [ListTileStyle.drawer]。
@immutable
class MongolListTileThemeData with Diagnosticable {
  /// 创建一个 [MongolListTileThemeData]。
  const MongolListTileThemeData({
    this.dense,
    this.shape,
    this.style,
    this.selectedColor,
    this.iconColor,
    this.textColor,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.leadingAndTrailingTextStyle,
    this.contentPadding,
    this.tileColor,
    this.selectedTileColor,
    this.verticalTitleGap,
    this.minHorizontalPadding,
    this.minLeadingHeight,
    this.enableFeedback,
    this.mouseCursor,
    this.visualDensity,
    this.titleAlignment,
  });

  /// 覆盖 [MongolListTile.dense] 的默认值。
  final bool? dense;

  /// 覆盖 [MongolListTile.shape] 的默认值。
  final ShapeBorder? shape;

  /// 覆盖 [MongolListTile.style] 的默认值。
  final ListTileStyle? style;

  /// 覆盖 [MongolListTile.selectedColor] 的默认值。
  final Color? selectedColor;

  /// 覆盖 [MongolListTile.iconColor] 的默认值。
  final Color? iconColor;

  /// 覆盖 [MongolListTile.textColor] 的默认值。
  final Color? textColor;

  /// 覆盖 [MongolListTile.titleTextStyle] 的默认值。
  final TextStyle? titleTextStyle;

  /// 覆盖 [MongolListTile.subtitleTextStyle] 的默认值。
  final TextStyle? subtitleTextStyle;

  /// 覆盖 [MongolListTile.leadingAndTrailingTextStyle] 的默认值。
  final TextStyle? leadingAndTrailingTextStyle;

  /// 覆盖 [MongolListTile.contentPadding] 的默认值。
  final EdgeInsetsGeometry? contentPadding;

  /// 覆盖 [MongolListTile.tileColor] 的默认值。
  final Color? tileColor;

  /// 覆盖 [MongolListTile.selectedTileColor] 的默认值。
  final Color? selectedTileColor;

  /// 覆盖 [MongolListTile.verticalTitleGap] 的默认值。
  final double? verticalTitleGap;

  /// 覆盖 [MongolListTile.minHorizontalPadding] 的默认值。
  final double? minHorizontalPadding;

  /// 覆盖 [MongolListTile.minLeadingHeight] 的默认值。
  final double? minLeadingHeight;

  /// 覆盖 [MongolListTile.enableFeedback] 的默认值。
  final bool? enableFeedback;

  /// 如果指定，覆盖 [MongolListTile.mouseCursor] 的默认值。
  final WidgetStateProperty<MouseCursor?>? mouseCursor;

  /// 如果指定，覆盖 [MongolListTile.visualDensity] 的默认值。
  final VisualDensity? visualDensity;

  /// 如果指定，覆盖 [MongolListTile.titleAlignment] 的默认值。
  final MongolListTileTitleAlignment? titleAlignment;

  /// 创建此对象的副本，并将给定字段替换为新值。
  MongolListTileThemeData copyWith({
    bool? dense,
    ShapeBorder? shape,
    ListTileStyle? style,
    Color? selectedColor,
    Color? iconColor,
    Color? textColor,
    TextStyle? titleTextStyle,
    TextStyle? subtitleTextStyle,
    TextStyle? leadingAndTrailingTextStyle,
    EdgeInsetsGeometry? contentPadding,
    Color? tileColor,
    Color? selectedTileColor,
    double? verticalTitleGap,
    double? minHorizontalPadding,
    double? minLeadingHeight,
    bool? enableFeedback,
    WidgetStateProperty<MouseCursor?>? mouseCursor,
    bool? isThreeLine,
    VisualDensity? visualDensity,
    MongolListTileTitleAlignment? titleAlignment,
  }) {
    return MongolListTileThemeData(
      dense: dense ?? this.dense,
      shape: shape ?? this.shape,
      style: style ?? this.style,
      selectedColor: selectedColor ?? this.selectedColor,
      iconColor: iconColor ?? this.iconColor,
      textColor: textColor ?? this.textColor,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      subtitleTextStyle: subtitleTextStyle ?? this.subtitleTextStyle,
      leadingAndTrailingTextStyle:
          leadingAndTrailingTextStyle ?? this.leadingAndTrailingTextStyle,
      contentPadding: contentPadding ?? this.contentPadding,
      tileColor: tileColor ?? this.tileColor,
      selectedTileColor: selectedTileColor ?? this.selectedTileColor,
      verticalTitleGap: verticalTitleGap ?? this.verticalTitleGap,
      minHorizontalPadding: minHorizontalPadding ?? this.minHorizontalPadding,
      minLeadingHeight: minLeadingHeight ?? this.minLeadingHeight,
      enableFeedback: enableFeedback ?? this.enableFeedback,
      mouseCursor: mouseCursor ?? this.mouseCursor,
      visualDensity: visualDensity ?? this.visualDensity,
      titleAlignment: titleAlignment ?? this.titleAlignment,
    );
  }

  /// 在 MongolListTileThemeData 对象之间进行线性插值。
  static MongolListTileThemeData? lerp(
      MongolListTileThemeData? a, MongolListTileThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return MongolListTileThemeData(
      dense: t < 0.5 ? a?.dense : b?.dense,
      shape: ShapeBorder.lerp(a?.shape, b?.shape, t),
      style: t < 0.5 ? a?.style : b?.style,
      selectedColor: Color.lerp(a?.selectedColor, b?.selectedColor, t),
      iconColor: Color.lerp(a?.iconColor, b?.iconColor, t),
      textColor: Color.lerp(a?.textColor, b?.textColor, t),
      titleTextStyle: TextStyle.lerp(a?.titleTextStyle, b?.titleTextStyle, t),
      subtitleTextStyle:
          TextStyle.lerp(a?.subtitleTextStyle, b?.subtitleTextStyle, t),
      leadingAndTrailingTextStyle: TextStyle.lerp(
          a?.leadingAndTrailingTextStyle, b?.leadingAndTrailingTextStyle, t),
      contentPadding:
          EdgeInsetsGeometry.lerp(a?.contentPadding, b?.contentPadding, t),
      tileColor: Color.lerp(a?.tileColor, b?.tileColor, t),
      selectedTileColor:
          Color.lerp(a?.selectedTileColor, b?.selectedTileColor, t),
      verticalTitleGap: lerpDouble(a?.verticalTitleGap, b?.verticalTitleGap, t),
      minHorizontalPadding:
          lerpDouble(a?.minHorizontalPadding, b?.minHorizontalPadding, t),
      minLeadingHeight: lerpDouble(a?.minLeadingHeight, b?.minLeadingHeight, t),
      enableFeedback: t < 0.5 ? a?.enableFeedback : b?.enableFeedback,
      mouseCursor: t < 0.5 ? a?.mouseCursor : b?.mouseCursor,
      visualDensity: t < 0.5 ? a?.visualDensity : b?.visualDensity,
      titleAlignment: t < 0.5 ? a?.titleAlignment : b?.titleAlignment,
    );
  }

  @override
  int get hashCode => Object.hash(
        dense,
        shape,
        style,
        selectedColor,
        iconColor,
        textColor,
        titleTextStyle,
        subtitleTextStyle,
        leadingAndTrailingTextStyle,
        contentPadding,
        tileColor,
        selectedTileColor,
        verticalTitleGap,
        minHorizontalPadding,
        minLeadingHeight,
        enableFeedback,
        mouseCursor,
        visualDensity,
        titleAlignment,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is MongolListTileThemeData &&
        other.dense == dense &&
        other.shape == shape &&
        other.style == style &&
        other.selectedColor == selectedColor &&
        other.iconColor == iconColor &&
        other.titleTextStyle == titleTextStyle &&
        other.subtitleTextStyle == subtitleTextStyle &&
        other.leadingAndTrailingTextStyle == leadingAndTrailingTextStyle &&
        other.textColor == textColor &&
        other.contentPadding == contentPadding &&
        other.tileColor == tileColor &&
        other.selectedTileColor == selectedTileColor &&
        other.verticalTitleGap == verticalTitleGap &&
        other.minHorizontalPadding == minHorizontalPadding &&
        other.minLeadingHeight == minLeadingHeight &&
        other.enableFeedback == enableFeedback &&
        other.mouseCursor == mouseCursor &&
        other.visualDensity == visualDensity &&
        other.titleAlignment == titleAlignment;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<bool>('dense', dense, defaultValue: null));
    properties.add(
        DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
    properties
        .add(EnumProperty<ListTileStyle>('style', style, defaultValue: null));
    properties
        .add(ColorProperty('selectedColor', selectedColor, defaultValue: null));
    properties.add(ColorProperty('iconColor', iconColor, defaultValue: null));
    properties.add(ColorProperty('textColor', textColor, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>(
        'titleTextStyle', titleTextStyle,
        defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>(
        'subtitleTextStyle', subtitleTextStyle,
        defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>(
        'leadingAndTrailingTextStyle', leadingAndTrailingTextStyle,
        defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>(
        'contentPadding', contentPadding,
        defaultValue: null));
    properties.add(ColorProperty('tileColor', tileColor, defaultValue: null));
    properties.add(ColorProperty('selectedTileColor', selectedTileColor,
        defaultValue: null));
    properties.add(DoubleProperty('verticalTitleGap', verticalTitleGap,
        defaultValue: null));
    properties.add(DoubleProperty('minHorizontalPadding', minHorizontalPadding,
        defaultValue: null));
    properties.add(DoubleProperty('minLeadingHeight', minLeadingHeight,
        defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('enableFeedback', enableFeedback,
        defaultValue: null));
    properties.add(DiagnosticsProperty<WidgetStateProperty<MouseCursor?>>(
        'mouseCursor', mouseCursor,
        defaultValue: null));
    properties.add(DiagnosticsProperty<VisualDensity>(
        'visualDensity', visualDensity,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MongolListTileTitleAlignment>(
        'titleAlignment', titleAlignment,
        defaultValue: null));
  }
}

/// 一个继承的小部件，为其子树中的 [MongolListTile] 定义颜色和样式参数
///
/// 这里指定的值用于 [MongolListTile] 未给出显式非空值的属性。
///
/// [MongolDrawer] 小部件为其子级指定了一个 tile 主题，将 [style] 设置为 [ListTileStyle.drawer]。
class MongolListTileTheme extends InheritedTheme {
  /// 创建一个列表 tile 主题，为后代 [MongolListTile] 定义颜色和样式参数
  ///
  /// 只应使用 [data] 参数。其他参数是冗余的（现在已过时），将在未来更新中被弃用。
  const MongolListTileTheme({
    Key? key,
    MongolListTileThemeData? data,
    bool? dense,
    ShapeBorder? shape,
    ListTileStyle? style,
    Color? selectedColor,
    Color? iconColor,
    Color? textColor,
    EdgeInsetsGeometry? contentPadding,
    Color? tileColor,
    Color? selectedTileColor,
    bool? enableFeedback,
    WidgetStateProperty<MouseCursor?>? mouseCursor,
    double? verticalTitleGap,
    double? minHorizontalPadding,
    double? minLeadingHeight,
    required super.child,
  })  : assert(data == null ||
            (shape ??
                    selectedColor ??
                    iconColor ??
                    textColor ??
                    contentPadding ??
                    tileColor ??
                    selectedTileColor ??
                    enableFeedback ??
                    mouseCursor ??
                    verticalTitleGap ??
                    minHorizontalPadding ??
                    minLeadingHeight) ==
                null),
        _data = data,
        _dense = dense,
        _shape = shape,
        _style = style,
        _selectedColor = selectedColor,
        _iconColor = iconColor,
        _textColor = textColor,
        _contentPadding = contentPadding,
        _tileColor = tileColor,
        _selectedTileColor = selectedTileColor,
        _enableFeedback = enableFeedback,
        _mouseCursor = mouseCursor,
        _verticalTitleGap = verticalTitleGap,
        _minHorizontalPadding = minHorizontalPadding,
        _minLeadingHeight = minLeadingHeight;

  final MongolListTileThemeData? _data;
  final bool? _dense;
  final ShapeBorder? _shape;
  final ListTileStyle? _style;
  final Color? _selectedColor;
  final Color? _iconColor;
  final Color? _textColor;
  final EdgeInsetsGeometry? _contentPadding;
  final Color? _tileColor;
  final Color? _selectedTileColor;
  final double? _verticalTitleGap;
  final double? _minHorizontalPadding;
  final double? _minLeadingHeight;
  final bool? _enableFeedback;
  final WidgetStateProperty<MouseCursor?>? _mouseCursor;

  /// 此主题的配置
  MongolListTileThemeData get data {
    return _data ??
        MongolListTileThemeData(
          dense: _dense,
          shape: _shape,
          style: _style,
          selectedColor: _selectedColor,
          iconColor: _iconColor,
          textColor: _textColor,
          contentPadding: _contentPadding,
          tileColor: _tileColor,
          selectedTileColor: _selectedTileColor,
          enableFeedback: _enableFeedback,
          mouseCursor: _mouseCursor,
          verticalTitleGap: _verticalTitleGap,
          minHorizontalPadding: _minHorizontalPadding,
          minLeadingHeight: _minLeadingHeight,
        );
  }

  /// 覆盖 [MongolListTile.dense] 的默认值
  ///
  /// 此属性已过时：请使用 [data] 的 [MongolListTileThemeData.dense] 属性代替。
  bool? get dense => _data != null ? _data?.dense : _dense;

  /// 覆盖 [ListTile.shape] 的默认值
  ///
  /// 此属性已过时：请使用 [data] 的 [MongolListTileThemeData.shape] 属性代替。
  ShapeBorder? get shape => _data != null ? _data?.shape : _shape;

  /// 覆盖 [ListTile.style] 的默认值
  ///
  /// 此属性已过时：请使用 [data] 的 [MongolListTileThemeData.style] 属性代替。
  ListTileStyle? get style => _data != null ? _data?.style : _style;

  /// 覆盖 [MongolListTile.selectedColor] 的默认值
  ///
  /// 此属性已过时：请使用 [data] 的 [MongolListTileThemeData.selectedColor] 属性代替。
  Color? get selectedColor =>
      _data != null ? _data?.selectedColor : _selectedColor;

  /// 覆盖 [MongolListTile.iconColor] 的默认值
  ///
  /// 此属性已过时：请使用 [data] 的 [MongolListTileThemeData.iconColor] 属性代替。
  Color? get iconColor => _data != null ? _data?.iconColor : _iconColor;

  /// 覆盖 [MongolListTile.textColor] 的默认值
  ///
  /// 此属性已过时：请使用 [data] 的 [MongolListTileThemeData.textColor] 属性代替。
  Color? get textColor => _data != null ? _data?.textColor : _textColor;

  /// 覆盖 [MongolListTile.contentPadding] 的默认值
  ///
  /// 此属性已过时：请使用 [data] 的 [MongolListTileThemeData.contentPadding] 属性代替。
  EdgeInsetsGeometry? get contentPadding =>
      _data != null ? _data?.contentPadding : _contentPadding;

  /// 覆盖 [MongolListTile.tileColor] 的默认值
  ///
  /// 此属性已过时：请使用 [data] 的 [MongolListTileThemeData.tileColor] 属性代替。
  Color? get tileColor => _data != null ? _data?.tileColor : _tileColor;

  /// 覆盖 [MongolListTile.selectedTileColor] 的默认值
  ///
  /// 此属性已过时：请使用 [data] 的 [MongolListTileThemeData.selectedTileColor] 属性代替。
  Color? get selectedTileColor =>
      _data != null ? _data?.selectedTileColor : _selectedTileColor;

  /// 覆盖 [MongolListTile.verticalTitleGap] 的默认值
  ///
  /// 此属性已过时：请使用 [data] 的 [MongolListTileThemeData.verticalTitleGap] 属性代替。
  double? get verticalTitleGap =>
      _data != null ? _data?.verticalTitleGap : _verticalTitleGap;

  /// 覆盖 [MongolListTile.minHorizontalPadding] 的默认值
  ///
  /// 此属性已过时：请使用 [data] 的 [MongolListTileThemeData.minHorizontalPadding] 属性代替。
  double? get minHorizontalPadding =>
      _data != null ? _data?.minHorizontalPadding : _minHorizontalPadding;

  /// 覆盖 [MongolListTile.minLeadingHeight] 的默认值
  ///
  /// 此属性已过时：请使用 [data] 的 [MongolListTileThemeData.minLeadingHeight] 属性代替。
  double? get minLeadingHeight =>
      _data != null ? _data?.minLeadingHeight : _minLeadingHeight;

  /// 覆盖 [MongolListTile.enableFeedback] 的默认值
  ///
  /// 此属性已过时：请使用 [data] 的 [MongolListTileThemeData.enableFeedback] 属性代替。
  bool? get enableFeedback =>
      _data != null ? _data?.enableFeedback : _enableFeedback;

  /// 包围给定上下文的此类最近实例的 [data] 属性
  ///
  /// 如果没有包围的 [MongolListTileTheme] 小部件，则返回 const MongolListTileThemeData()。
  ///
  /// 典型用法如下：
  ///
  /// ```dart
  /// MongolListTileThemeData theme = MongolListTileTheme.of(context);
  /// ```
  static MongolListTileThemeData of(BuildContext context) {
    final MongolListTileTheme? result =
        context.dependOnInheritedWidgetOfExactType<MongolListTileTheme>();
    return result?.data ?? const MongolListTileThemeData();
  }

  /// 创建一个列表 tile 主题，控制 [ListTile] 的颜色和样式参数，并合并当前的列表 tile 主题（如果有）
  static Widget merge({
    Key? key,
    bool? dense,
    ShapeBorder? shape,
    ListTileStyle? style,
    Color? selectedColor,
    Color? iconColor,
    Color? textColor,
    TextStyle? titleTextStyle,
    TextStyle? subtitleTextStyle,
    TextStyle? leadingAndTrailingTextStyle,
    EdgeInsetsGeometry? contentPadding,
    Color? tileColor,
    Color? selectedTileColor,
    bool? enableFeedback,
    double? verticalTitleGap,
    double? minHorizontalPadding,
    double? minLeadingHeight,
    MongolListTileTitleAlignment? titleAlignment,
    WidgetStateProperty<MouseCursor?>? mouseCursor,
    VisualDensity? visualDensity,
    required Widget child,
  }) {
    return Builder(
      builder: (BuildContext context) {
        final MongolListTileThemeData parent = MongolListTileTheme.of(context);
        return MongolListTileTheme(
          key: key,
          data: MongolListTileThemeData(
            dense: dense ?? parent.dense,
            shape: shape ?? parent.shape,
            style: style ?? parent.style,
            selectedColor: selectedColor ?? parent.selectedColor,
            iconColor: iconColor ?? parent.iconColor,
            textColor: textColor ?? parent.textColor,
            titleTextStyle: titleTextStyle ?? parent.titleTextStyle,
            subtitleTextStyle: subtitleTextStyle ?? parent.subtitleTextStyle,
            leadingAndTrailingTextStyle: leadingAndTrailingTextStyle ??
                parent.leadingAndTrailingTextStyle,
            contentPadding: contentPadding ?? parent.contentPadding,
            tileColor: tileColor ?? parent.tileColor,
            selectedTileColor: selectedTileColor ?? parent.selectedTileColor,
            enableFeedback: enableFeedback ?? parent.enableFeedback,
            verticalTitleGap: verticalTitleGap ?? parent.verticalTitleGap,
            minHorizontalPadding:
                minHorizontalPadding ?? parent.minHorizontalPadding,
            minLeadingHeight: minLeadingHeight ?? parent.minLeadingHeight,
            titleAlignment: titleAlignment ?? parent.titleAlignment,
            mouseCursor: mouseCursor ?? parent.mouseCursor,
            visualDensity: visualDensity ?? parent.visualDensity,
          ),
          child: child,
        );
      },
    );
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return MongolListTileTheme(
      data: MongolListTileThemeData(
        dense: dense,
        shape: shape,
        style: style,
        selectedColor: selectedColor,
        iconColor: iconColor,
        textColor: textColor,
        contentPadding: contentPadding,
        tileColor: tileColor,
        selectedTileColor: selectedTileColor,
        enableFeedback: enableFeedback,
        verticalTitleGap: verticalTitleGap,
        minHorizontalPadding: minHorizontalPadding,
        minLeadingHeight: minLeadingHeight,
      ),
      child: child,
    );
  }

  @override
  bool updateShouldNotify(MongolListTileTheme oldWidget) =>
      data != oldWidget.data;
}

/// 定义 [MongolListTile.leading] 和 [MongolListTile.trailing] 相对于 [MongolListTile] 标题
/// ([MongolListTile.title] 和 [MongolListTile.subtitle]) 的水平对齐方式。
///
/// 另请参阅：
///
///  * [MongolListTile.titleAlignment]，用于为单个 [MongolListTile] 配置标题对齐方式。
enum MongolListTileTitleAlignment {
  /// [MongolListTile.leading] 和 [MongolListTile.trailing] 小部件的左侧
  /// 如果 [MongolListTile.isThreeLine] 为 true，则放置在 [MongolListTile.title] 左侧的 [MongolListTile.minHorizontalPadding] 处，
  /// 否则它们相对于 [MongolListTile.title] 和 [MongolListTile.subtitle] 小部件居中。
  ///
  /// 当 [ThemeData.useMaterial3] 为 true 时，这是默认值。
  threeLine,

  /// [MongolListTile.leading] 和 [MongolListTile.trailing] 小部件的左侧
  /// 如果标题的整体宽度大于 72，则放置在 [MongolListTile.title] 左侧的 16 个单位处，
  /// 否则它们相对于 [MongolListTile.title] 和 [MongolListTile.subtitle] 小部件居中。
  ///
  /// 当 [ThemeData.useMaterial3] 为 false 时，这是默认值。
  titleWidth,

  /// [MongolListTile.leading] 和 [MongolListTile.trailing] 小部件的左侧
  /// 放置在 [MongolListTile.title] 左侧的 [MongolListTile.minHorizontalPadding] 处。
  left,

  /// [MongolListTile.leading] 和 [MongolListTile.trailing] 小部件
  /// 相对于 [MongolListTile] 的标题居中。
  center,

  /// [MongolListTile.leading] 和 [MongolListTile.trailing] 小部件的右侧
  /// 放置在 [MongolListTile] 标题右侧的 [MongolListTile.minHorizontalPadding] 处。
  right,
}

/// 一个固定宽度的垂直列，通常包含一些文本以及前置或后置图标
///
/// 此小部件是 [ListTile] 的垂直文本版本。
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=l8dj0yPBvgQ}
///
/// 列表 tile 包含一到三行文本，可选地两侧带有图标或其他小部件，如复选框。
/// tile 的图标（或其他小部件）由 [leading] 和 [trailing] 参数定义。
/// 第一行文本是必需的，由 [title] 指定。[subtitle] 是可选的，
/// 将占据为额外一行文本分配的空间，如果 [isThreeLine] 为 true，则占据两行。
/// 如果 [dense] 为 true，则此 tile 的整体宽度以及包装 [title] 和 [subtitle] 小部件的
/// [DefaultTextStyle] 的大小都会减小。
///
/// 调用者有责任确保 [title] 不换行，并确保 [subtitle] 不换行（如果 [isThreeLine] 为 false）
/// 或换行到两行（如果为 true）。
///
/// [leading] 和 [trailing] 小部件的宽度根据
/// [Material 规范](https://material.io/design/components/lists.html) 进行约束。
/// 为了可访问性，对单行 MongolListTile 做了例外处理。
/// 请参阅下面的示例，了解如何同时遵守 Material 规范和可访问性要求。
///
/// 请注意，[leading] 和 [trailing] 小部件可以在垂直方向上尽可能扩展，
/// 因此请确保它们受到适当的约束。
///
/// 列表 tile 通常用于水平 [ListView] 中，或在 [MongolDrawer] 和 [Card] 中排列成行。
///
/// 要求其祖先之一是 [Material] 小部件。
///
/// {@tool snippet}
///
/// 此示例使用 [ListView] 演示 [Card] 中 [MongolListTile] 的不同配置。
///
/// ![ListTile 的不同变体](https://flutter.github.io/assets-for-api-docs/assets/material/list_tile.png)
///
/// ```dart
/// ListView(
///   scrollDirection: Axis.horizontal,
///   children: const <Widget>[
///     Card(child: MongolListTile(title: Text('One-line MongolListTile'))),
///     Card(
///       child: MongolListTile(
///         leading: FlutterLogo(),
///         title: MongolText('One-line with leading widget'),
///       ),
///     ),
///     Card(
///       child: MongolListTile(
///         title: MongolText('One-line with trailing widget'),
///         trailing: Icon(Icons.more_vert),
///       ),
///     ),
///     Card(
///       child: MongolListTile(
///         leading: FlutterLogo(),
///         title: MongolText('One-line with both widgets'),
///         trailing: Icon(Icons.more_vert),
///       ),
///     ),
///     Card(
///       child: MongolListTile(
///         title: MongolText('One-line dense MongolListTile'),
///         dense: true,
///       ),
///     ),
///     Card(
///       child: MongolListTile(
///         leading: FlutterLogo(size: 56.0),
///         title: MongolText('Two-line MongolListTile'),
///         subtitle: MongolText('Here is a second line'),
///         trailing: Icon(Icons.more_vert),
///       ),
///     ),
///     Card(
///       child: MongolListTile(
///         leading: FlutterLogo(size: 72.0),
///         title: MongolText('Three-line MongolListTile'),
///         subtitle: MongolText(
///           'A sufficiently long subtitle warrants three lines.'
///         ),
///         trailing: Icon(Icons.more_vert),
///         isThreeLine: true,
///       ),
///     ),
///   ],
/// )
/// ```
/// {@end-tool}
/// {@tool snippet}
///
/// 要在 [Column] 中使用 [MongolListTile]，需要将其包装在 [Expanded] 小部件中。
/// [MongolListTile] 需要固定的高度约束，而 [Column] 不会约束其子级。
///
/// ```dart
/// Column(
///   children: const <Widget>[
///     Expanded(
///       child: MongolListTile(
///         leading: FlutterLogo(),
///         title: MongolText('These MongolListTiles are expanded '),
///       ),
///     ),
///     Expanded(
///       child: MongolListTile(
///         trailing: FlutterLogo(),
///         title: MongolText('to fill the available space.'),
///       ),
///     ),
///   ],
/// )
/// ```
/// {@end-tool}
/// {@tool snippet}
///
/// Tile 可以更加复杂。这是一个可以点击的 tile，但当 `_act` 变量不为 2 时会被禁用。
/// 当 tile 被点击时，整个列会有墨水飞溅效果（请参阅 [InkWell]）。
///
/// ```dart
/// int _act = 1;
/// // ...
/// MongolListTile(
///   leading: const Icon(Icons.flight_land),
///   title: const MongolText("Trix's airplane"),
///   subtitle: _act != 2 ? const MongolText('The airplane is only in Act II.') : null,
///   enabled: _act == 2,
///   onTap: () { /* react to the tile being tapped */ }
/// )
/// ```
/// {@end-tool}
///
/// 为了可访问性，可点击的 [leading] 和 [trailing] 小部件的大小必须至少为 48x48。
/// 然而，为了遵守 Material 规范，单行 MongolListTile 中的 [trailing] 和 [leading] 小部件
/// 在视觉上的宽度最多应为 32（[dense]：true）或 40（[dense]：false），这可能与可访问性要求冲突。
///
/// 因此，单行 MongolListTile 允许 [leading] 和 [trailing] 小部件的宽度受 MongolListTile 宽度的约束。
/// 这允许创建足够大的可点击 [leading] 和 [trailing] 小部件，
/// 但开发人员有责任确保他们的小部件遵守 Material 规范。
///
/// {@tool snippet}
///
/// 以下是一个单行、非 [dense] 的 MongolListTile 示例，带有一个可点击的前置小部件，
/// 该小部件符合可访问性要求和 Material 规范。要调整下面的用例以适应单行、[dense] 的
/// MongolListTile，请将水平内边距调整为 8.0。
///
/// ```dart
/// MongolListTile(
///   leading: GestureDetector(
///     behavior: HitTestBehavior.translucent,
///     onTap: () {},
///     child: Container(
///       width: 48,
///       height: 48,
///       padding: const EdgeInsets.symmetric(horizontal: 4.0),
///       alignment: Alignment.center,
///       child: const CircleAvatar(),
///     ),
///   ),
///   title: const MongolText('title'),
///   dense: false,
/// ),
/// ```
/// {@end-tool}
///
/// 另请参阅：
///
///  * [MongolListTileTheme]，为 [MongolListTile] 定义视觉属性。
///  * [ListView]，可以在滚动列表中显示任意数量的 [MongolListTile]。
///  * [CircleAvatar]，显示代表人物的图标，通常用作 MongolListTile 的 [leading] 元素。
///  * [Card]，可以与 [Row] 一起使用以显示几个 [MongolListTile]。
///  * [VerticalDivider]，可用于分隔 [MongolListTile]。
///  * [MongolListTile.divideTiles]，一个用于在 [MongolListTile] 之间插入 [VerticalDivider] 的实用程序。
///  * <https://material.io/design/components/lists.html>
///  *  cookbook: [使用列表](https://flutter.dev/docs/cookbook/lists/basic-list)
///  *  cookbook: [实现滑动删除](https://flutter.dev/docs/cookbook/gestures/dismissible)
class MongolListTile extends StatelessWidget {
  /// 创建一个垂直列表 tile
  ///
  /// 如果 [isThreeLine] 为 true，则 [subtitle] 不能为空。
  ///
  /// 要求其祖先之一是 [Material] 小部件。
  const MongolListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.isThreeLine = false,
    this.dense,
    this.visualDensity,
    this.shape,
    this.style,
    this.selectedColor,
    this.iconColor,
    this.textColor,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.leadingAndTrailingTextStyle,
    this.contentPadding,
    this.enabled = true,
    this.onTap,
    this.onLongPress,
    this.onFocusChange,
    this.mouseCursor,
    this.selected = false,
    this.focusColor,
    this.hoverColor,
    this.splashColor,
    this.focusNode,
    this.autofocus = false,
    this.tileColor,
    this.selectedTileColor,
    this.enableFeedback,
    this.verticalTitleGap,
    this.minHorizontalPadding,
    this.minLeadingHeight,
    this.titleAlignment,
  }) : assert(!isThreeLine || subtitle != null);

  /// 显示在标题上方的小部件
  ///
  /// 通常是 [Icon] 或 [CircleAvatar] 小部件。
  final Widget? leading;

  /// 列表 tile 的主要内容
  ///
  /// 通常是 [MongolText] 小部件。
  ///
  /// 这不应该换行。要强制单行限制，请使用 [MongolText.maxLines]。
  final Widget? title;

  /// 显示在标题下方的附加内容
  ///
  /// 通常是 [MongolText] 小部件。
  ///
  /// 如果 [isThreeLine] 为 false，这不应该换行。
  ///
  /// 如果 [isThreeLine] 为 true，这应该配置为最多占用两行。
  /// 例如，您可以使用 [MongolText.maxLines] 来强制行数。
  ///
  /// 副标题的默认 [TextStyle] 依赖于 [TextTheme.bodyText2]，除了 [TextStyle.color]。
  /// [TextStyle.color] 取决于 [enabled] 和 [selected] 的值。
  ///
  /// 当 [enabled] 为 false 时，文本颜色设置为 [ThemeData.disabledColor]。
  ///
  /// 当 [selected] 为 false 时，文本颜色设置为 [MongolListTileTheme.textColor]（如果不为 null），
  /// 如果 [MongolListTileTheme.textColor] 为 null，则设置为 [TextTheme.caption] 的颜色。
  final Widget? subtitle;

  /// 显示在标题下方的小部件
  ///
  /// 通常是 [Icon] 小部件。
  final Widget? trailing;

  /// 此列表 tile 是否旨在显示三行文本
  ///
  /// 如果为 true，则 [subtitle] 必须非空（因为它预计会给出第二行和第三行文本）。
  ///
  /// 如果为 false，如果 subtitle 为 null，则列表 tile 被视为具有一行，
  /// 如果 subtitle 非空，则被视为具有两行。
  ///
  /// 当为 [title] 和 [subtitle] 使用 [MongolText] 小部件时，
  /// 您可以使用 [MongolText.maxLines] 来强制行数限制。
  final bool isThreeLine;

  /// 此列表 tile 是否是水平密集列表的一部分
  ///
  /// 如果此属性为 null，则其值基于 [MongolListTileTheme.dense]。
  ///
  /// 密集列表 tile 默认宽度较小。
  final bool? dense;

  /// 定义列表 tile 布局的紧凑程度
  ///
  /// 另请参阅：
  ///
  ///  * [ThemeData.visualDensity]，为 [Theme] 中的所有小部件指定 [visualDensity]。
  final VisualDensity? visualDensity;

  /// tile 的形状
  ///
  /// 定义 tile 的 [InkWell.customBorder] 和 [Ink.decoration] 形状。
  ///
  /// 如果此属性为 null，则使用 [MongolListTileTheme.shape]。
  /// 如果那也为 null，则使用矩形 [Border]。
  final ShapeBorder? shape;

  /// 定义列表 tile 被选中时用于图标和文本的颜色
  ///
  /// 如果此属性为 null，则使用 [ListTileThemeData.selectedColor]。
  /// 如果那也为 null，则使用 [ColorScheme.primary]。
  ///
  /// 另请参阅：
  ///
  /// * [ListTileTheme.of]，返回最近的 [ListTileTheme] 的 [ListTileThemeData]。
  final Color? selectedColor;

  /// 定义 [leading] 和 [trailing] 图标的默认颜色
  ///
  /// 如果此属性为 null 且 [selected] 为 false，则使用 [ListTileThemeData.iconColor]。
  /// 如果那也为 null 且 [ThemeData.useMaterial3] 为 true，则使用 [ColorScheme.onSurfaceVariant]，
  /// 否则，如果 [ThemeData.brightness] 为 [Brightness.light]，则使用 [Colors.black54]，
  /// 如果 [ThemeData.brightness] 为 [Brightness.dark]，则值为 null。
  ///
  /// 如果此属性为 null 且 [selected] 为 true，则使用 [ListTileThemeData.selectedColor]。
  /// 如果那也为 null，则使用 [ColorScheme.primary]。
  ///
  /// 如果此颜色是 [WidgetStateColor]，它将根据 [WidgetState.selected] 和 [WidgetState.disabled] 状态进行解析。
  ///
  /// 另请参阅：
  ///
  /// * [ListTileTheme.of]，返回最近的 [ListTileTheme] 的 [ListTileThemeData]。
  final Color? iconColor;

  /// 定义 [title]、[subtitle]、[leading] 和 [trailing] 的文本颜色
  ///
  /// 如果此属性为 null 且 [selected] 为 false，则使用 [ListTileThemeData.textColor]。
  /// 如果那也为 null，则为 [title]、[subtitle]、[leading] 和 [trailing] 使用默认文本颜色。
  /// 除了 [subtitle]，如果 [ThemeData.useMaterial3] 为 false，则使用 [TextTheme.bodySmall]。
  ///
  /// 如果此属性为 null 且 [selected] 为 true，则使用 [ListTileThemeData.selectedColor]。
  /// 如果那也为 null，则使用 [ColorScheme.primary]。
  ///
  /// 如果此颜色是 [WidgetStateColor]，它将根据 [WidgetState.selected] 和 [WidgetState.disabled] 状态进行解析。
  ///
  /// 另请参阅：
  ///
  /// * [ListTileTheme.of]，返回最近的 [ListTileTheme] 的 [ListTileThemeData]。
  final Color? textColor;

  /// ListTile 的 [title] 的文本样式
  ///
  /// 如果此属性为 null，则使用 [ListTileThemeData.titleTextStyle]。
  /// 如果那也为 null 且 [ThemeData.useMaterial3] 为 true，则使用带有 [ColorScheme.onSurface] 的 [TextTheme.bodyLarge]。
  /// 否则，如果 ListTile 样式为 [ListTileStyle.list]，则使用 [TextTheme.titleMedium]，
  /// 如果 ListTile 样式为 [ListTileStyle.drawer]，则使用 [TextTheme.bodyLarge]。
  final TextStyle? titleTextStyle;

  /// ListTile 的 [subtitle] 的文本样式
  ///
  /// 如果此属性为 null，则使用 [ListTileThemeData.subtitleTextStyle]。
  /// 如果那也为 null 且 [ThemeData.useMaterial3] 为 true，则使用带有 [ColorScheme.onSurfaceVariant] 的 [TextTheme.bodyMedium]，
  /// 否则使用带有 [TextTheme.bodySmall] 颜色的 [TextTheme.bodyMedium]。
  final TextStyle? subtitleTextStyle;

  /// ListTile 的 [leading] 和 [trailing] 的文本样式
  ///
  /// 如果此属性为 null，则使用 [ListTileThemeData.leadingAndTrailingTextStyle]。
  /// 如果那也为 null 且 [ThemeData.useMaterial3] 为 true，则使用带有 [ColorScheme.onSurfaceVariant] 的 [TextTheme.labelSmall]，
  /// 否则使用 [TextTheme.bodyMedium]。
  final TextStyle? leadingAndTrailingTextStyle;

  /// 定义用于 [title] 的字体
  ///
  /// 如果此属性为 null，则使用 [ListTileThemeData.style]。
  /// 如果那也为 null，则使用 [ListTileStyle.list]。
  ///
  /// 另请参阅：
  ///
  /// * [ListTileTheme.of]，返回最近的 [ListTileTheme] 的 [ListTileThemeData]。
  final ListTileStyle? style;

  /// tile 的内部内边距
  ///
  /// 插入 [MongolListTile] 的内容：其 [leading]、[title]、[subtitle] 和 [trailing] 小部件。
  ///
  /// 如果为 null，则使用 `EdgeInsets.symmetric(vertical: 16.0)`。
  final EdgeInsetsGeometry? contentPadding;

  /// 此列表 tile 是否可交互
  ///
  /// 如果为 false，则此列表 tile 使用当前 [Theme] 中的禁用颜色设置样式，
  /// 并且 [onTap] 和 [onLongPress] 回调不起作用。
  final bool enabled;

  /// 当用户点击此列表 tile 时调用
  ///
  /// 如果 [enabled] 为 false，则不起作用。
  final GestureTapCallback? onTap;

  /// 当用户长按此列表 tile 时调用
  ///
  /// 如果 [enabled] 为 false，则不起作用。
  final GestureLongPressCallback? onLongPress;

  /// {@macro flutter.material.inkwell.onFocusChange}
  final ValueChanged<bool>? onFocusChange;

  /// 鼠标指针进入或悬停在小部件上时的光标
  ///
  /// 如果 [mouseCursor] 是 [MaterialStateProperty<MouseCursor>]，
  /// 则 [WidgetStateProperty.resolve] 用于以下 [WidgetState]：
  ///
  ///  * [WidgetState.selected]。
  ///  * [WidgetState.disabled]。
  ///
  /// 如果此属性为 null，则使用 [WidgetStateMouseCursor.clickable]。
  final MouseCursor? mouseCursor;

  /// 如果此 tile 也 [enabled]，则图标和文本使用相同的颜色
  ///
  /// 默认情况下，选中颜色是主题的主色。
  /// 选中颜色可以通过 [MongolListTileTheme] 覆盖。
  final bool selected;

  /// tile 的 [Material] 获得输入焦点时的颜色
  final Color? focusColor;

  /// 指针悬停在 tile 的 [Material] 上时的颜色
  final Color? hoverColor;

  /// tile 的 [Material] 的飞溅颜色
  final Color? splashColor;

  /// {@macro flutter.widgets.Focus.focusNode}
  final FocusNode? focusNode;

  /// {@macro flutter.widgets.Focus.autofocus}
  final bool autofocus;

  /// 定义 [selected] 为 false 时 `MongolListTile` 的背景颜色
  ///
  /// 当值为 null 时，如果 [MongolListTileTheme.tileColor] 不为 null，则 `tileColor` 设置为它，
  /// 如果为 null，则设置为 [Colors.transparent]。
  final Color? tileColor;

  /// 定义 [selected] 为 true 时 `MongolListTile` 的背景颜色
  ///
  /// 当值为 null 时，如果 [MongolListTileTheme.selectedTileColor] 不为 null，则 `selectedTileColor` 设置为它，
  /// 如果为 null，则设置为 [Colors.transparent]。
  final Color? selectedTileColor;

  /// 检测到的手势是否应提供声音和/或触觉反馈
  ///
  /// 例如，在 Android 上，当启用反馈时，点击会产生点击声，长按会产生短暂的振动。
  ///
  /// 另请参阅：
  ///
  ///  * [Feedback]，用于为某些操作提供特定于平台的反馈。
  final bool? enableFeedback;

  /// 标题与前置/后置小部件之间的垂直间隙
  ///
  /// 如果为 null，则使用 [MongolListTileTheme.verticalTitleGap] 的值。
  /// 如果那也为 null，则使用默认值 16。
  final double? verticalTitleGap;

  /// 标题和副标题小部件左右两侧的最小内边距
  ///
  /// 如果为 null，则使用 [MongolListTileTheme.minHorizontalPadding] 的值。
  /// 如果那也为 null，则使用默认值 4。
  final double? minHorizontalPadding;

  /// 为 [MongolListTile.leading] 小部件分配的最小高度
  ///
  /// 如果为 null，则使用 [MongolListTileTheme.minLeadingHeight] 的值。
  /// 如果那也为 null，则使用默认值 40。
  final double? minLeadingHeight;

  /// 定义 [MongolListTile.leading] 和 [MongolListTile.trailing] 相对于 [MongolListTile] 标题
  /// ([MongolListTile.title] 和 [MongolListTile.subtitle]) 的水平对齐方式
  ///
  /// 如果此属性为 null，则使用 [ListTileThemeData.titleAlignment]。
  /// 如果那也为 null，则使用 [ListTileTitleAlignment.threeLine]。
  ///
  /// 另请参阅：
  ///
  /// * [ListTileTheme.of]，返回最近的 [ListTileTheme] 的 [ListTileThemeData]。
  final MongolListTileTitleAlignment? titleAlignment;

  /// 在每个 tile 之间添加一个像素的边框。如果未指定颜色，则使用上下文 [Theme] 的 [ThemeData.dividerColor]。
  ///
  /// 另请参阅：
  ///
  ///  * [VerticalDivider]，您可以使用它手动获得此效果。
  /// todo material make it equal to ListTile.divideTiles
  static Iterable<Widget> divideTiles({
      BuildContext? context,
      required Iterable<Widget> tiles,
      Color? color}) sync* {
    assert(color != null || context != null);

    final Iterator<Widget> iterator = tiles.iterator;
    final bool hasNext = iterator.moveNext();
    if (!hasNext) return;

    final Decoration decoration = BoxDecoration(
      border: Border(
        right: Divider.createBorderSide(context, color: color),
      ),
    );

    Widget tile = iterator.current;
    while (iterator.moveNext()) {
      yield DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: decoration,
        child: tile,
      );
      tile = iterator.current;
    }
    if (hasNext) yield tile;
  }

  /// 检查是否为密集布局
  ///
  /// [theme]：当前主题
  /// [tileTheme]：列表 tile 主题
  /// 返回：是否为密集布局
  bool _isDenseLayout(ThemeData theme, MongolListTileThemeData? tileTheme) {
    return dense ?? tileTheme?.dense ?? theme.listTileTheme.dense ?? false;
  }

  /// 获取 tile 的背景颜色
  ///
  /// [theme]：当前主题
  /// [tileTheme]：列表 tile 主题
  /// [defaults]：默认主题数据
  /// 返回：计算后的背景颜色
  Color _tileBackgroundColor(ThemeData theme, MongolListTileThemeData tileTheme,
      MongolListTileThemeData defaults) {
    final Color? color = selected
        ? selectedTileColor ??
            tileTheme.selectedTileColor ??
            theme.listTileTheme.selectedTileColor
        : tileColor ?? tileTheme.tileColor ?? theme.listTileTheme.tileColor;
    return color ?? defaults.tileColor!;
  }

  /// 构建列表 tile 小部件
  ///
  /// [context]：构建上下文
  /// 返回：构建好的列表 tile 小部件
  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    final ThemeData theme = Theme.of(context);
    final MongolListTileThemeData tileTheme = MongolListTileTheme.of(context);
    final ListTileStyle listTileStyle = style ??
        tileTheme.style ??
        theme.listTileTheme.style ??
        ListTileStyle.list;
    final MongolListTileThemeData defaults = theme.useMaterial3
        ? _LisTileDefaultsM3(context)
        : _LisTileDefaultsM2(context, listTileStyle);
    final Set<WidgetState> states = <WidgetState>{
      if (!enabled) WidgetState.disabled,
      if (selected) WidgetState.selected,
    };

    // 解析颜色
    Color? resolveColor(
        Color? explicitColor, Color? selectedColor, Color? enabledColor,
        [Color? disabledColor]) {
      return _IndividualOverrides(
        explicitColor: explicitColor,
        selectedColor: selectedColor,
        enabledColor: enabledColor,
        disabledColor: disabledColor,
      ).resolve(states);
    }

    // 计算有效的图标颜色
    final Color? effectiveIconColor =
        resolveColor(iconColor, selectedColor, iconColor) ??
            resolveColor(tileTheme.iconColor, tileTheme.selectedColor,
                tileTheme.iconColor) ??
            resolveColor(
                theme.listTileTheme.iconColor,
                theme.listTileTheme.selectedColor,
                theme.listTileTheme.iconColor) ??
            resolveColor(defaults.iconColor, defaults.selectedColor,
                defaults.iconColor, theme.disabledColor);
    // 计算有效的文本颜色
    final Color? effectiveColor =
        resolveColor(textColor, selectedColor, textColor) ??
            resolveColor(tileTheme.textColor, tileTheme.selectedColor,
                tileTheme.textColor) ??
            resolveColor(
                theme.listTileTheme.textColor,
                theme.listTileTheme.selectedColor,
                theme.listTileTheme.textColor) ??
            resolveColor(defaults.textColor, defaults.selectedColor,
                defaults.textColor, theme.disabledColor);
    // 创建图标主题数据
    final IconThemeData iconThemeData =
        IconThemeData(color: effectiveIconColor);
    // 创建图标按钮主题数据
    final IconButtonThemeData iconButtonThemeData = IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: effectiveIconColor),
    );

    // 处理前置和后置小部件的文本样式
    TextStyle? leadingAndTrailingStyle;
    if (leading != null || trailing != null) {
      leadingAndTrailingStyle = leadingAndTrailingTextStyle ??
          tileTheme.leadingAndTrailingTextStyle ??
          defaults.leadingAndTrailingTextStyle!;
      final Color? leadingAndTrailingTextColor = effectiveColor;
      leadingAndTrailingStyle =
          leadingAndTrailingStyle.copyWith(color: leadingAndTrailingTextColor);
    }

    // 处理前置小部件
    Widget? leadingIcon;
    if (leading != null) {
      leadingIcon = AnimatedDefaultTextStyle(
        style: leadingAndTrailingStyle!,
        duration: kThemeChangeDuration,
        child: leading!,
      );
    }

    // 处理标题样式
    TextStyle titleStyle =
        titleTextStyle ?? tileTheme.titleTextStyle ?? defaults.titleTextStyle!;
    final Color? titleColor = effectiveColor;
    titleStyle = titleStyle.copyWith(
      color: titleColor,
      fontSize: _isDenseLayout(theme, tileTheme) ? 13.0 : null,
    );
    final Widget titleText = AnimatedDefaultTextStyle(
      style: titleStyle,
      duration: kThemeChangeDuration,
      child: title ?? const SizedBox(),
    );

    // 处理副标题
    Widget? subtitleText;
    TextStyle? subtitleStyle;
    if (subtitle != null) {
      subtitleStyle = subtitleTextStyle ??
          tileTheme.subtitleTextStyle ??
          defaults.subtitleTextStyle!;
      final Color? subtitleColor = effectiveColor;
      subtitleStyle = subtitleStyle.copyWith(
        color: subtitleColor,
        fontSize: _isDenseLayout(theme, tileTheme) ? 12.0 : null,
      );
      subtitleText = AnimatedDefaultTextStyle(
        style: subtitleStyle,
        duration: kThemeChangeDuration,
        child: subtitle!,
      );
    }

    // 处理后置小部件
    Widget? trailingIcon;
    if (trailing != null) {
      trailingIcon = AnimatedDefaultTextStyle(
        style: leadingAndTrailingStyle!,
        duration: kThemeChangeDuration,
        child: trailing!,
      );
    }

    // 处理内容内边距
    const EdgeInsets defaultContentPadding =
        EdgeInsets.symmetric(vertical: 16.0);
    const TextDirection textDirection = TextDirection.ltr;
    final EdgeInsets resolvedContentPadding =
        contentPadding?.resolve(textDirection) ??
            tileTheme.contentPadding?.resolve(textDirection) ??
            defaultContentPadding;

    // 处理鼠标光标
    // 当 MongolListTile 未启用或手势回调为 null 时显示基本光标。
    final Set<WidgetState> mouseStates = <WidgetState>{
      if (!enabled || (onTap == null && onLongPress == null))
        WidgetState.disabled,
    };
    final MouseCursor effectiveMouseCursor =
        WidgetStateProperty.resolveAs<MouseCursor?>(
                mouseCursor, mouseStates) ??
            tileTheme.mouseCursor?.resolve(mouseStates) ??
            WidgetStateMouseCursor.clickable.resolve(mouseStates);

    // 处理标题对齐方式
    final MongolListTileTitleAlignment effectiveTitleAlignment =
        titleAlignment ??
            tileTheme.titleAlignment ??
            (theme.useMaterial3
                ? MongolListTileTitleAlignment.threeLine
                : MongolListTileTitleAlignment.titleWidth);

    return InkWell(
      customBorder: shape ?? tileTheme.shape,
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      onFocusChange: onFocusChange,
      mouseCursor: effectiveMouseCursor,
      canRequestFocus: enabled,
      focusNode: focusNode,
      focusColor: focusColor,
      hoverColor: hoverColor,
      splashColor: splashColor,
      autofocus: autofocus,
      enableFeedback: enableFeedback ?? tileTheme.enableFeedback ?? true,
      child: Semantics(
        selected: selected,
        enabled: enabled,
        child: Ink(
          decoration: ShapeDecoration(
            shape: shape ?? tileTheme.shape ?? const Border(),
            color: _tileBackgroundColor(theme, tileTheme, defaults),
          ),
          child: SafeArea(
            left: false,
            right: false,
            minimum: resolvedContentPadding,
            child: IconTheme.merge(
              data: iconThemeData,
              child: IconButtonTheme(
                data: iconButtonThemeData,
                child: _MongolListTile(
                  leading: leadingIcon,
                  title: titleText,
                  subtitle: subtitleText,
                  trailing: trailingIcon,
                  isDense: _isDenseLayout(theme, tileTheme),
                  visualDensity: visualDensity ??
                      tileTheme.visualDensity ??
                      theme.visualDensity,
                  isThreeLine: isThreeLine,
                  titleBaselineType: titleStyle.textBaseline ??
                      defaults.titleTextStyle!.textBaseline!,
                  subtitleBaselineType: subtitleStyle?.textBaseline ??
                      defaults.subtitleTextStyle!.textBaseline!,
                  verticalTitleGap:
                      verticalTitleGap ?? tileTheme.verticalTitleGap ?? 16,
                  minHorizontalPadding: minHorizontalPadding ??
                      tileTheme.minHorizontalPadding ??
                      defaults.minHorizontalPadding!,
                  minLeadingHeight: minLeadingHeight ??
                      tileTheme.minLeadingHeight ??
                      defaults.minLeadingHeight!,
                  titleAlignment: effectiveTitleAlignment,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        DiagnosticsProperty<Widget>('leading', leading, defaultValue: null));
    properties
        .add(DiagnosticsProperty<Widget>('title', title, defaultValue: null));
    properties.add(
        DiagnosticsProperty<Widget>('subtitle', subtitle, defaultValue: null));
    properties.add(
        DiagnosticsProperty<Widget>('trailing', trailing, defaultValue: null));
    properties.add(FlagProperty('isThreeLine',
        value: isThreeLine,
        ifTrue: 'THREE_LINE',
        ifFalse: 'TWO_LINE',
        showName: true,
        defaultValue: false));
    properties.add(FlagProperty('dense',
        value: dense, ifTrue: 'true', ifFalse: 'false', showName: true));
    properties.add(DiagnosticsProperty<VisualDensity>(
        'visualDensity', visualDensity,
        defaultValue: null));
    properties.add(
        DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
    properties.add(
        DiagnosticsProperty<ListTileStyle>('style', style, defaultValue: null));
    properties
        .add(ColorProperty('selectedColor', selectedColor, defaultValue: null));
    properties.add(ColorProperty('iconColor', iconColor, defaultValue: null));
    properties.add(ColorProperty('textColor', textColor, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>(
        'titleTextStyle', titleTextStyle,
        defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>(
        'subtitleTextStyle', subtitleTextStyle,
        defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>(
        'leadingAndTrailingTextStyle', leadingAndTrailingTextStyle,
        defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>(
        'contentPadding', contentPadding,
        defaultValue: null));
    properties.add(FlagProperty('enabled',
        value: enabled,
        ifTrue: 'true',
        ifFalse: 'false',
        showName: true,
        defaultValue: true));
    properties
        .add(DiagnosticsProperty<Function>('onTap', onTap, defaultValue: null));
    properties.add(DiagnosticsProperty<Function>('onLongPress', onLongPress,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MouseCursor>('mouseCursor', mouseCursor,
        defaultValue: null));
    properties.add(FlagProperty('selected',
        value: selected,
        ifTrue: 'true',
        ifFalse: 'false',
        showName: true,
        defaultValue: false));
    properties.add(ColorProperty('focusColor', focusColor, defaultValue: null));
    properties.add(ColorProperty('hoverColor', hoverColor, defaultValue: null));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode,
        defaultValue: null));
    properties.add(FlagProperty('autofocus',
        value: autofocus,
        ifTrue: 'true',
        ifFalse: 'false',
        showName: true,
        defaultValue: false));
    properties.add(ColorProperty('tileColor', tileColor, defaultValue: null));
    properties.add(ColorProperty('selectedTileColor', selectedTileColor,
        defaultValue: null));
    properties.add(FlagProperty('enableFeedback',
        value: enableFeedback,
        ifTrue: 'true',
        ifFalse: 'false',
        showName: true));
    properties.add(DoubleProperty('horizontalTitleGap', verticalTitleGap,
        defaultValue: null));
    properties.add(DoubleProperty('minVerticalPadding', minHorizontalPadding,
        defaultValue: null));
    properties.add(DoubleProperty('minLeadingWidth', minLeadingHeight,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MongolListTileTitleAlignment>(
        'titleAlignment', titleAlignment,
        defaultValue: null));
  }
}

/// 用于根据小部件状态解析颜色的类
///
/// 处理颜色是 WidgetStateColor 或常规 Color 的情况
class _IndividualOverrides extends WidgetStateProperty<Color?> {
  /// 创建一个 _IndividualOverrides 实例
  ///
  /// [explicitColor]：显式指定的颜色
  /// [enabledColor]：启用状态的颜色
  /// [selectedColor]：选中状态的颜色
  /// [disabledColor]：禁用状态的颜色
  _IndividualOverrides({
    this.explicitColor,
    this.enabledColor,
    this.selectedColor,
    this.disabledColor,
  });

  /// 显式指定的颜色
  final Color? explicitColor;
  /// 启用状态的颜色
  final Color? enabledColor;
  /// 选中状态的颜色
  final Color? selectedColor;
  /// 禁用状态的颜色
  final Color? disabledColor;

  /// 根据小部件状态解析颜色
  ///
  /// [states]：小部件的状态集合
  /// 返回：解析后的颜色
  @override
  Color? resolve(Set<WidgetState> states) {
    if (explicitColor is WidgetStateColor) {
      return WidgetStateProperty.resolveAs<Color?>(explicitColor, states);
    }
    if (states.contains(WidgetState.disabled)) {
      return disabledColor;
    }
    if (states.contains(WidgetState.selected)) {
      return selectedColor;
    }
    return enabledColor;
  }
}

/// 标识 _MongolListTileElement 的子部件
enum _ListTileSlot {
  /// 前置小部件
  leading,
  /// 标题小部件
  title,
  /// 副标题小部件
  subtitle,
  /// 后置小部件
  trailing,
}

/// 蒙古文列表 tile 布局小部件
///
/// 负责管理列表 tile 的子部件布局
class _MongolListTile
    extends SlottedMultiChildRenderObjectWidget<_ListTileSlot, RenderBox> {
  /// 创建一个 _MongolListTile 实例
  ///
  /// [key]：小部件的唯一标识符
  /// [leading]：前置小部件
  /// [title]：标题小部件
  /// [subtitle]：副标题小部件
  /// [trailing]：后置小部件
  /// [isThreeLine]：是否显示三行文本
  /// [isDense]：是否为密集布局
  /// [visualDensity]：视觉密度
  /// [titleBaselineType]：标题的基线类型
  /// [verticalTitleGap]：标题与前置/后置小部件之间的垂直间隙
  /// [minHorizontalPadding]：标题和副标题左右两侧的最小内边距
  /// [minLeadingHeight]：前置小部件的最小高度
  /// [subtitleBaselineType]：副标题的基线类型
  /// [titleAlignment]：标题对齐方式
  const _MongolListTile({
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.isThreeLine,
    required this.isDense,
    required this.visualDensity,
    required this.titleBaselineType,
    required this.verticalTitleGap,
    required this.minHorizontalPadding,
    required this.minLeadingHeight,
    this.subtitleBaselineType,
    required this.titleAlignment,
  });

  /// 前置小部件
  final Widget? leading;
  /// 标题小部件
  final Widget title;
  /// 副标题小部件
  final Widget? subtitle;
  /// 后置小部件
  final Widget? trailing;
  /// 是否显示三行文本
  final bool isThreeLine;
  /// 是否为密集布局
  final bool isDense;
  /// 视觉密度
  final VisualDensity visualDensity;
  /// 标题的基线类型
  final TextBaseline titleBaselineType;
  /// 副标题的基线类型
  final TextBaseline? subtitleBaselineType;
  /// 标题与前置/后置小部件之间的垂直间隙
  final double verticalTitleGap;
  /// 标题和副标题左右两侧的最小内边距
  final double minHorizontalPadding;
  /// 前置小部件的最小高度
  final double minLeadingHeight;
  /// 标题对齐方式
  final MongolListTileTitleAlignment titleAlignment;

  @override
  Iterable<_ListTileSlot> get slots => _ListTileSlot.values;

  @override
  Widget? childForSlot(_ListTileSlot slot) {
    switch (slot) {
      case _ListTileSlot.leading:
        return leading;
      case _ListTileSlot.title:
        return title;
      case _ListTileSlot.subtitle:
        return subtitle;
      case _ListTileSlot.trailing:
        return trailing;
    }
  }

  @override
  _MongolRenderListTile createRenderObject(BuildContext context) {
    return _MongolRenderListTile(
      isThreeLine: isThreeLine,
      isDense: isDense,
      visualDensity: visualDensity,
      titleBaselineType: titleBaselineType,
      subtitleBaselineType: subtitleBaselineType,
      verticalTitleGap: verticalTitleGap,
      minHorizontalPadding: minHorizontalPadding,
      minLeadingHeight: minLeadingHeight,
      titleAlignment: titleAlignment,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, _MongolRenderListTile renderObject) {
    renderObject
      ..isThreeLine = isThreeLine
      ..isDense = isDense
      ..visualDensity = visualDensity
      ..titleBaselineType = titleBaselineType
      ..subtitleBaselineType = subtitleBaselineType
      ..verticalTitleGap = verticalTitleGap
      ..minHorizontalPadding = minHorizontalPadding
      ..minLeadingHeight = minLeadingHeight
      ..titleAlignment = titleAlignment;
  }
}

/// 蒙古文列表 tile 的渲染对象
///
/// 负责处理蒙古文列表 tile 的布局计算、绘制和命中测试
/// 继承自 RenderBox 并混合了 SlottedContainerRenderObjectMixin 以管理子部件
class _MongolRenderListTile extends RenderBox
    with SlottedContainerRenderObjectMixin<_ListTileSlot, RenderBox> {
  /// 创建一个 _MongolRenderListTile 实例
  ///
  /// [isDense]：是否为密集布局
  /// [visualDensity]：视觉密度
  /// [isThreeLine]：是否显示三行文本
  /// [titleBaselineType]：标题的基线类型
  /// [subtitleBaselineType]：副标题的基线类型
  /// [verticalTitleGap]：标题与前置/后置小部件之间的垂直间隙
  /// [minHorizontalPadding]：标题和副标题左右两侧的最小内边距
  /// [minLeadingHeight]：前置小部件的最小高度
  /// [titleAlignment]：标题对齐方式
  _MongolRenderListTile({
    required bool isDense,
    required VisualDensity visualDensity,
    required bool isThreeLine,
    required TextBaseline titleBaselineType,
    TextBaseline? subtitleBaselineType,
    required double verticalTitleGap,
    required double minHorizontalPadding,
    required double minLeadingHeight,
    required MongolListTileTitleAlignment titleAlignment,
  })  : _isDense = isDense,
        _visualDensity = visualDensity,
        _isThreeLine = isThreeLine,
        _titleBaselineType = titleBaselineType,
        _subtitleBaselineType = subtitleBaselineType,
        _verticalTitleGap = verticalTitleGap,
        _minHorizontalPadding = minHorizontalPadding,
        _minLeadingHeight = minLeadingHeight,
        _titleAlignment = titleAlignment;

  /// 获取前置小部件
  RenderBox? get leading => childForSlot(_ListTileSlot.leading);
  /// 获取标题小部件
  RenderBox? get title => childForSlot(_ListTileSlot.title);
  /// 获取副标题小部件
  RenderBox? get subtitle => childForSlot(_ListTileSlot.subtitle);
  /// 获取后置小部件
  RenderBox? get trailing => childForSlot(_ListTileSlot.trailing);

  /// 返回用于命中测试的子部件列表（按顺序）
  @override
  Iterable<RenderBox> get children {
    return <RenderBox>[
      if (leading != null) leading!,
      if (title != null) title!,
      if (subtitle != null) subtitle!,
      if (trailing != null) trailing!,
    ];
  }

  /// 是否为密集布局
  bool get isDense => _isDense;
  bool _isDense;
  set isDense(bool value) {
    if (_isDense == value) return;
    _isDense = value;
    markNeedsLayout();
  }

  /// 视觉密度
  VisualDensity get visualDensity => _visualDensity;
  VisualDensity _visualDensity;
  set visualDensity(VisualDensity value) {
    if (_visualDensity == value) return;
    _visualDensity = value;
    markNeedsLayout();
  }

  /// 是否显示三行文本
  bool get isThreeLine => _isThreeLine;
  bool _isThreeLine;
  set isThreeLine(bool value) {
    if (_isThreeLine == value) return;
    _isThreeLine = value;
    markNeedsLayout();
  }

  /// 标题的基线类型
  TextBaseline get titleBaselineType => _titleBaselineType;
  TextBaseline _titleBaselineType;
  set titleBaselineType(TextBaseline value) {
    if (_titleBaselineType == value) return;
    _titleBaselineType = value;
    markNeedsLayout();
  }

  /// 副标题的基线类型
  TextBaseline? get subtitleBaselineType => _subtitleBaselineType;
  TextBaseline? _subtitleBaselineType;
  set subtitleBaselineType(TextBaseline? value) {
    if (_subtitleBaselineType == value) return;
    _subtitleBaselineType = value;
    markNeedsLayout();
  }

  /// 标题与前置/后置小部件之间的垂直间隙
  double get verticalTitleGap => _verticalTitleGap;
  double _verticalTitleGap;
  /// 考虑视觉密度后的有效垂直间隙
  double get _effectiveVerticalTitleGap =>
      _verticalTitleGap + visualDensity.vertical * 2.0;

  set verticalTitleGap(double value) {
    if (_verticalTitleGap == value) return;
    _verticalTitleGap = value;
    markNeedsLayout();
  }

  /// 标题和副标题左右两侧的最小内边距
  double get minHorizontalPadding => _minHorizontalPadding;
  double _minHorizontalPadding;

  set minHorizontalPadding(double value) {
    if (_minHorizontalPadding == value) return;
    _minHorizontalPadding = value;
    markNeedsLayout();
  }

  /// 前置小部件的最小高度
  double get minLeadingHeight => _minLeadingHeight;
  double _minLeadingHeight;

  set minLeadingHeight(double value) {
    if (_minLeadingHeight == value) return;
    _minLeadingHeight = value;
    markNeedsLayout();
  }

  /// 标题对齐方式
  MongolListTileTitleAlignment get titleAlignment => _titleAlignment;
  MongolListTileTitleAlignment _titleAlignment;
  set titleAlignment(MongolListTileTitleAlignment value) {
    if (_titleAlignment == value) return;
    _titleAlignment = value;
    markNeedsLayout();
  }

  @override
  bool get sizedByParent => false;

  /// 获取小部件的最小内在高度
  static double _minHeight(RenderBox? box, double width) {
    return box == null ? 0.0 : box.getMinIntrinsicHeight(width);
  }

  /// 获取小部件的最大内在高度
  static double _maxHeight(RenderBox? box, double width) {
    return box == null ? 0.0 : box.getMaxIntrinsicHeight(width);
  }

  /// 计算最小内在高度
  @override
  double computeMinIntrinsicHeight(double width) {
    final double leadingHeight = leading != null
        ? math.max(leading!.getMinIntrinsicHeight(width), _minLeadingHeight) +
            _effectiveVerticalTitleGap
        : 0.0;
    return leadingHeight +
        math.max(_minHeight(title, width), _minHeight(subtitle, width)) +
        _maxHeight(trailing, width);
  }

  /// 计算最大内在高度
  @override
  double computeMaxIntrinsicHeight(double width) {
    final double leadingHeight = leading != null
        ? math.max(leading!.getMaxIntrinsicHeight(width), _minLeadingHeight) +
            _effectiveVerticalTitleGap
        : 0.0;
    return leadingHeight +
        math.max(_maxHeight(title, width), _maxHeight(subtitle, width)) +
        _maxHeight(trailing, width);
  }

  /// 获取默认的 tile 宽度
  double get _defaultTileWidth {
    final bool hasSubtitle = subtitle != null;
    final bool isTwoLine = !isThreeLine && hasSubtitle;
    final bool isOneLine = !isThreeLine && !hasSubtitle;

    final Offset baseDensity = visualDensity.baseSizeAdjustment;
    if (isOneLine) return (isDense ? 48.0 : 56.0) + baseDensity.dx;
    if (isTwoLine) return (isDense ? 64.0 : 72.0) + baseDensity.dx;
    return (isDense ? 76.0 : 88.0) + baseDensity.dx;
  }

  /// 计算最小内在宽度
  @override
  double computeMinIntrinsicWidth(double height) {
    return math.max(
      _defaultTileWidth,
      title!.getMinIntrinsicWidth(height) +
          (subtitle?.getMinIntrinsicWidth(height) ?? 0.0),
    );
  }

  /// 计算最大内在宽度
  @override
  double computeMaxIntrinsicWidth(double height) {
    return computeMinIntrinsicWidth(height);
  }

  /// 计算到实际基线的距离
  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    assert(title != null);
    final BoxParentData parentData = title!.parentData! as BoxParentData;
    return parentData.offset.dx + title!.getDistanceToActualBaseline(baseline)!;
  }

  /// 获取小部件的基线
  static double? _boxBaseline(RenderBox box, TextBaseline baseline) {
    return box.getDistanceToBaseline(baseline);
  }

  /// 布局小部件并返回其大小
  static Size _layoutBox(RenderBox? box, BoxConstraints constraints) {
    if (box == null) return Size.zero;
    box.layout(constraints, parentUsesSize: true);
    return box.size;
  }

  /// 定位小部件
  static void _positionBox(RenderBox box, Offset offset) {
    final BoxParentData parentData = box.parentData! as BoxParentData;
    parentData.offset = offset;
  }

  /// 计算干布局（不实际布局子部件）
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(debugCannotComputeDryLayout(
      reason:
          'Layout requires baseline metrics, which are only available after a full layout.',
    ));
    return Size.zero;
  }

  // 以下所有尺寸均来自 Material Design 规范：
  // https://material.io/design/components/lists.html#specs
  /// 执行布局计算
  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    final bool hasLeading = leading != null;
    final bool hasSubtitle = subtitle != null;
    final bool hasTrailing = trailing != null;
    final bool isTwoLine = !isThreeLine && hasSubtitle;
    final bool isOneLine = !isThreeLine && !hasSubtitle;
    final Offset densityAdjustment = visualDensity.baseSizeAdjustment;

    final BoxConstraints maxIconWidthConstraint = BoxConstraints(
      // One-line trailing and leading widget widths do not follow
      // Material specifications, but this sizing is required to adhere
      // to accessibility requirements for smallest tappable widget.
      // Two- and three-line trailing widget widths are constrained
      // properly according to the Material spec.
      maxWidth: (isDense ? 48.0 : 56.0) + densityAdjustment.dx,
    );
    final BoxConstraints looseConstraints = constraints.loosen();
    final BoxConstraints iconConstraints =
        looseConstraints.enforce(maxIconWidthConstraint);

    final double tileHeight = looseConstraints.maxHeight;
    final Size leadingSize = _layoutBox(leading, iconConstraints);
    final Size trailingSize = _layoutBox(trailing, iconConstraints);
    assert(
      tileHeight != leadingSize.height || tileHeight == 0.0,
      'Leading widget consumes entire tile height. Please use a sized widget, '
      'or consider replacing MongolListTile with a custom widget '
      '(see https://api.flutter.dev/flutter/material/ListTile-class.html#material.ListTile.4)',
    );
    assert(
      tileHeight != trailingSize.height || tileHeight == 0.0,
      'Trailing widget consumes entire tile height. Please use a sized widget, '
      'or consider replacing MongolListTile with a custom widget '
      '(see https://api.flutter.dev/flutter/material/ListTile-class.html#material.ListTile.4)',
    );

    final double titleStart = hasLeading
        ? math.max(_minLeadingHeight, leadingSize.height) +
            _effectiveVerticalTitleGap
        : 0.0;
    final double adjustedLeadingHeight = hasLeading
        ? math.max(leadingSize.height + _effectiveVerticalTitleGap, 32.0)
        : 0.0;
    final double adjustedTrailingHeight =
        hasTrailing ? math.max(trailingSize.height, 32.0) : 0.0;
    final BoxConstraints textConstraints = looseConstraints.tighten(
      height: tileHeight - titleStart - adjustedTrailingHeight,
    );
    final Size titleSize = _layoutBox(title, textConstraints);
    final Size subtitleSize = _layoutBox(subtitle, textConstraints);

    double? titleBaseline;
    double? subtitleBaseline;
    if (isTwoLine) {
      titleBaseline = isDense ? 28.0 : 32.0;
      subtitleBaseline = isDense ? 48.0 : 52.0;
    } else if (isThreeLine) {
      titleBaseline = isDense ? 22.0 : 28.0;
      subtitleBaseline = isDense ? 42.0 : 48.0;
    } else {
      assert(isOneLine);
    }

    final double defaultTileWidth = _defaultTileWidth;

    double tileWidth;
    double titleX;
    double? subtitleX;
    if (!hasSubtitle) {
      tileWidth = math.max(
          defaultTileWidth, titleSize.width + 2.0 * _minHorizontalPadding);
      titleX = (tileWidth - titleSize.width) / 2.0;
    } else {
      assert(subtitleBaselineType != null);
      titleX = titleBaseline! - _boxBaseline(title!, titleBaselineType)!;
      subtitleX = subtitleBaseline! -
          _boxBaseline(subtitle!, subtitleBaselineType!)! +
          visualDensity.horizontal * 2.0;
      tileWidth = defaultTileWidth;

      // If the title and subtitle overlap, move the title left by half
      // the overlap and the subtitle right by the same amount, and adjust
      // tileWidth so that both titles fit.
      final double titleOverlap = titleX + titleSize.width - subtitleX;
      if (titleOverlap > 0.0) {
        titleX -= titleOverlap / 2.0;
        subtitleX += titleOverlap / 2.0;
      }

      // If the title or subtitle overflow tileWidth then punt: title
      // and subtitle are arranged in a column, tileWidth = row width plus
      // _minHorizontalPadding on the left and right.
      if (titleX < _minHorizontalPadding ||
          (subtitleX + subtitleSize.width + _minHorizontalPadding) >
              tileWidth) {
        tileWidth =
            titleSize.width + subtitleSize.width + 2.0 * _minHorizontalPadding;
        titleX = _minHorizontalPadding;
        subtitleX = titleSize.width + _minHorizontalPadding;
      }
    }

    final double leadingX;
    final double trailingX;

    switch (titleAlignment) {
      case MongolListTileTitleAlignment.threeLine:
        {
          if (isThreeLine) {
            leadingX = _minHorizontalPadding;
            trailingX = _minHorizontalPadding;
          } else {
            leadingX = (tileWidth - leadingSize.width) / 2.0;
            trailingX = (tileWidth - trailingSize.width) / 2.0;
          }
          break;
        }
      case MongolListTileTitleAlignment.titleWidth:
        {
          // This attempts to implement the redlines for the horizontal position of the
          // leading and trailing icons on the spec page:
          //   https://m2.material.io/components/lists#specs
          // The interpretation for these redlines is as follows:
          //  - For large tiles (> 72dp), both leading and trailing controls should be
          //    a fixed distance from left. As per guidelines this is set to 16dp.
          //  - For smaller tiles, trailing should always be centered. Leading can be
          //    centered or closer to the left. It should never be further than 16dp
          //    to the left.
          if (tileWidth > 72.0) {
            leadingX = 16.0;
            trailingX = 16.0;
          } else {
            leadingX = math.min((tileWidth - leadingSize.width) / 2.0, 16.0);
            trailingX = (tileWidth - trailingSize.width) / 2.0;
          }
          break;
        }
      case MongolListTileTitleAlignment.left:
        {
          leadingX = _minHorizontalPadding;
          trailingX = _minHorizontalPadding;
          break;
        }
      case MongolListTileTitleAlignment.center:
        {
          leadingX = (tileWidth - leadingSize.width) / 2.0;
          trailingX = (tileWidth - trailingSize.width) / 2.0;
          break;
        }
      case MongolListTileTitleAlignment.right:
        {
          leadingX = tileWidth - leadingSize.width - _minHorizontalPadding;
          trailingX = tileWidth - trailingSize.width - _minHorizontalPadding;
          break;
        }
    }

    if (hasLeading) {
      _positionBox(leading!, Offset(leadingX, 0.0));
    }
    _positionBox(title!, Offset(titleX, adjustedLeadingHeight));
    if (hasSubtitle) {
      _positionBox(subtitle!, Offset(subtitleX!, adjustedLeadingHeight));
    }
    if (hasTrailing) {
      _positionBox(
          trailing!, Offset(trailingX, tileHeight - trailingSize.height));
    }

    size = constraints.constrain(Size(tileWidth, tileHeight));
    assert(size.width == constraints.constrainWidth(tileWidth));
    assert(size.height == constraints.constrainHeight(tileHeight));
  }

  /// 绘制子部件
  @override
  void paint(PaintingContext context, Offset offset) {
    void doPaint(RenderBox? child) {
      if (child != null) {
        final BoxParentData parentData = child.parentData! as BoxParentData;
        context.paintChild(child, parentData.offset + offset);
      }
    }

    doPaint(leading);
    doPaint(title);
    doPaint(subtitle);
    doPaint(trailing);
  }

  /// 测试自身是否被命中
  @override
  bool hitTestSelf(Offset position) => true;

  /// 测试子部件是否被命中
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final RenderBox child in children) {
      final BoxParentData parentData = child.parentData! as BoxParentData;
      final bool isHit = result.addWithPaintOffset(
        offset: parentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          assert(transformed == position - parentData.offset);
          return child.hitTest(result, position: transformed);
        },
      );
      if (isHit) return true;
    }
    return false;
  }
}

/// Material 2 风格的列表 tile 默认值
///
/// 提供 Material 2 设计规范下的列表 tile 默认样式和颜色
class _LisTileDefaultsM2 extends MongolListTileThemeData {
  /// 创建一个 _LisTileDefaultsM2 实例
  ///
  /// [context]：构建上下文
  /// [style]：列表 tile 样式
  _LisTileDefaultsM2(this.context, ListTileStyle style)
      : super(
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
          minLeadingHeight: 40,
          minHorizontalPadding: 4,
          shape: const Border(),
          style: style,
        );

  /// 构建上下文
  final BuildContext context;
  /// 当前主题
  late final ThemeData _theme = Theme.of(context);
  /// 当前文本主题
  late final TextTheme _textTheme = _theme.textTheme;

  /// 获取 tile 背景颜色
  @override
  Color? get tileColor => Colors.transparent;

  /// 获取标题文本样式
  @override
  TextStyle? get titleTextStyle {
    switch (style!) {
      case ListTileStyle.drawer:
        return _textTheme.bodyLarge;
      case ListTileStyle.list:
        return _textTheme.titleMedium;
    }
  }

  /// 获取副标题文本样式
  @override
  TextStyle? get subtitleTextStyle =>
      _textTheme.bodyMedium!.copyWith(color: _textTheme.bodySmall!.color);

  /// 获取前置和后置小部件的文本样式
  @override
  TextStyle? get leadingAndTrailingTextStyle => _textTheme.bodyMedium;

  /// 获取选中状态的颜色
  @override
  Color? get selectedColor => _theme.colorScheme.primary;

  /// 获取图标颜色
  @override
  Color? get iconColor {
    switch (_theme.brightness) {
      case Brightness.light:
        // 为了向后兼容，未选中 tile 的默认值是 Colors.black45
        // 而不是 colorScheme.onSurface.withAlpha(0x73)。
        return Colors.black45;
      case Brightness.dark:
        return null; // null，使用当前图标主题颜色
    }
  }
}

// BEGIN GENERATED TOKEN PROPERTIES - LisTile

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

/// Material 3 风格的列表 tile 默认值
///
/// 提供 Material 3 设计规范下的列表 tile 默认样式和颜色
class _LisTileDefaultsM3 extends MongolListTileThemeData {
  /// 创建一个 _LisTileDefaultsM3 实例
  ///
  /// [context]：构建上下文
  _LisTileDefaultsM3(this.context)
      : super(
          contentPadding:
              const EdgeInsetsDirectional.only(top: 16.0, bottom: 24.0),
          minLeadingHeight: 24,
          minHorizontalPadding: 8,
          shape: const RoundedRectangleBorder(),
        );

  /// 构建上下文
  final BuildContext context;
  /// 当前主题
  late final ThemeData _theme = Theme.of(context);
  /// 当前颜色方案
  late final ColorScheme _colors = _theme.colorScheme;
  /// 当前文本主题
  late final TextTheme _textTheme = _theme.textTheme;

  /// 获取 tile 背景颜色
  @override
  Color? get tileColor => Colors.transparent;

  /// 获取标题文本样式
  @override
  TextStyle? get titleTextStyle =>
      _textTheme.bodyLarge!.copyWith(color: _colors.onSurface);

  /// 获取副标题文本样式
  @override
  TextStyle? get subtitleTextStyle =>
      _textTheme.bodyMedium!.copyWith(color: _colors.onSurfaceVariant);

  /// 获取前置和后置小部件的文本样式
  @override
  TextStyle? get leadingAndTrailingTextStyle =>
      _textTheme.labelSmall!.copyWith(color: _colors.onSurfaceVariant);

  /// 获取选中状态的颜色
  @override
  Color? get selectedColor => _colors.primary;

  /// 获取图标颜色
  @override
  Color? get iconColor => _colors.onSurfaceVariant;
}

// END GENERATED TOKEN PROPERTIES - LisTile
