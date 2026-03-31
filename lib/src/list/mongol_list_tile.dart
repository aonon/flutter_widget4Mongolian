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

@immutable
class MongolListTileThemeData with Diagnosticable {
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

  final bool? dense;

  final ShapeBorder? shape;

  final ListTileStyle? style;

  final Color? selectedColor;

  final Color? iconColor;

  final Color? textColor;

  final TextStyle? titleTextStyle;

  final TextStyle? subtitleTextStyle;

  final TextStyle? leadingAndTrailingTextStyle;

  final EdgeInsetsGeometry? contentPadding;

  final Color? tileColor;

  final Color? selectedTileColor;

  final double? verticalTitleGap;

  final double? minHorizontalPadding;

  final double? minLeadingHeight;

  final bool? enableFeedback;

  final WidgetStateProperty<MouseCursor?>? mouseCursor;

  final VisualDensity? visualDensity;

  final MongolListTileTitleAlignment? titleAlignment;

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

class MongolListTileTheme extends InheritedTheme {
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

  bool? get dense => _data != null ? _data?.dense : _dense;

  ShapeBorder? get shape => _data != null ? _data?.shape : _shape;

  ListTileStyle? get style => _data != null ? _data?.style : _style;

  Color? get selectedColor =>
      _data != null ? _data?.selectedColor : _selectedColor;

  Color? get iconColor => _data != null ? _data?.iconColor : _iconColor;

  Color? get textColor => _data != null ? _data?.textColor : _textColor;

  EdgeInsetsGeometry? get contentPadding =>
      _data != null ? _data?.contentPadding : _contentPadding;

  Color? get tileColor => _data != null ? _data?.tileColor : _tileColor;

  Color? get selectedTileColor =>
      _data != null ? _data?.selectedTileColor : _selectedTileColor;

  double? get verticalTitleGap =>
      _data != null ? _data?.verticalTitleGap : _verticalTitleGap;

  double? get minHorizontalPadding =>
      _data != null ? _data?.minHorizontalPadding : _minHorizontalPadding;

  double? get minLeadingHeight =>
      _data != null ? _data?.minLeadingHeight : _minLeadingHeight;

  bool? get enableFeedback =>
      _data != null ? _data?.enableFeedback : _enableFeedback;

  static MongolListTileThemeData of(BuildContext context) {
    final MongolListTileTheme? result =
        context.dependOnInheritedWidgetOfExactType<MongolListTileTheme>();
    return result?.data ?? const MongolListTileThemeData();
  }

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

enum MongolListTileTitleAlignment {
  threeLine,

  titleWidth,

  left,

  center,

  right,
}

class MongolListTile extends StatelessWidget {
  static const Set<WidgetState> _defaultState = <WidgetState>{};
  static const Set<WidgetState> _selectedState = <WidgetState>{
    WidgetState.selected,
  };
  static const Set<WidgetState> _disabledState = <WidgetState>{
    WidgetState.disabled,
  };
  static const Set<WidgetState> _disabledSelectedState = <WidgetState>{
    WidgetState.disabled,
    WidgetState.selected,
  };

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

  final Widget? leading;

  final Widget? title;

  final Widget? subtitle;

  final Widget? trailing;

  final bool isThreeLine;

  final bool? dense;

  final VisualDensity? visualDensity;

  final ShapeBorder? shape;

  final Color? selectedColor;

  final Color? iconColor;

  final Color? textColor;

  final TextStyle? titleTextStyle;

  final TextStyle? subtitleTextStyle;

  final TextStyle? leadingAndTrailingTextStyle;

  final ListTileStyle? style;

  final EdgeInsetsGeometry? contentPadding;

  final bool enabled;

  final GestureTapCallback? onTap;

  final GestureLongPressCallback? onLongPress;

  final ValueChanged<bool>? onFocusChange;

  final MouseCursor? mouseCursor;

  final bool selected;

  final Color? focusColor;

  final Color? hoverColor;

  final Color? splashColor;

  final FocusNode? focusNode;

  final bool autofocus;

  final Color? tileColor;

  final Color? selectedTileColor;

  final bool? enableFeedback;

  final double? verticalTitleGap;

  final double? minHorizontalPadding;

  final double? minLeadingHeight;

  final MongolListTileTitleAlignment? titleAlignment;

  static Iterable<Widget> divideTiles(
      {BuildContext? context,
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
    yield tile;
  }

  bool _isDenseLayout(ThemeData theme, MongolListTileThemeData? tileTheme) {
    return dense ?? tileTheme?.dense ?? theme.listTileTheme.dense ?? false;
  }

  Color _tileBackgroundColor(ThemeData theme, MongolListTileThemeData tileTheme,
      MongolListTileThemeData defaults) {
    final Color? color = selected
        ? selectedTileColor ??
            tileTheme.selectedTileColor ??
            theme.listTileTheme.selectedTileColor
        : tileColor ?? tileTheme.tileColor ?? theme.listTileTheme.tileColor;
    return color ?? defaults.tileColor!;
  }

  Set<WidgetState> _statesForTile() {
    if (enabled) {
      return selected ? _selectedState : _defaultState;
    }
    return selected ? _disabledSelectedState : _disabledState;
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    final ThemeData theme = Theme.of(context);
    final MongolListTileThemeData tileTheme = MongolListTileTheme.of(context);
    final bool isDenseLayout = _isDenseLayout(theme, tileTheme);
    final ListTileStyle listTileStyle = style ??
        tileTheme.style ??
        theme.listTileTheme.style ??
        ListTileStyle.list;
    final MongolListTileThemeData defaults = theme.useMaterial3
        ? _LisTileDefaultsM3(context)
        : _LisTileDefaultsM2(context, listTileStyle);
    final Set<WidgetState> states = _statesForTile();

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
    final Color? effectiveTextColor =
        resolveColor(textColor, selectedColor, textColor) ??
            resolveColor(tileTheme.textColor, tileTheme.selectedColor,
                tileTheme.textColor) ??
            resolveColor(
                theme.listTileTheme.textColor,
                theme.listTileTheme.selectedColor,
                theme.listTileTheme.textColor) ??
            resolveColor(defaults.textColor, defaults.selectedColor,
                defaults.textColor, theme.disabledColor);
    final IconThemeData iconThemeData =
        IconThemeData(color: effectiveIconColor);
    final IconButtonThemeData iconButtonThemeData = IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: effectiveIconColor),
    );

    TextStyle? leadingAndTrailingStyle;
    if (leading != null || trailing != null) {
      leadingAndTrailingStyle = leadingAndTrailingTextStyle ??
          tileTheme.leadingAndTrailingTextStyle ??
          defaults.leadingAndTrailingTextStyle!;
      final Color? leadingAndTrailingTextColor = effectiveTextColor;
      leadingAndTrailingStyle =
          leadingAndTrailingStyle.copyWith(color: leadingAndTrailingTextColor);
    }

    Widget? leadingIcon;
    if (leading != null) {
      leadingIcon = AnimatedDefaultTextStyle(
        style: leadingAndTrailingStyle!,
        duration: kThemeChangeDuration,
        child: leading!,
      );
    }

    TextStyle titleStyle =
        titleTextStyle ?? tileTheme.titleTextStyle ?? defaults.titleTextStyle!;
    final Color? titleColor = effectiveTextColor;
    titleStyle = titleStyle.copyWith(
      color: titleColor,
      fontSize: isDenseLayout ? 13.0 : null,
    );
    final Widget titleText = AnimatedDefaultTextStyle(
      style: titleStyle,
      duration: kThemeChangeDuration,
      child: title ?? const SizedBox(),
    );

    Widget? subtitleText;
    TextStyle? subtitleStyle;
    if (subtitle != null) {
      subtitleStyle = subtitleTextStyle ??
          tileTheme.subtitleTextStyle ??
          defaults.subtitleTextStyle!;
      final Color? subtitleColor = effectiveTextColor;
      subtitleStyle = subtitleStyle.copyWith(
        color: subtitleColor,
        fontSize: isDenseLayout ? 12.0 : null,
      );
      subtitleText = AnimatedDefaultTextStyle(
        style: subtitleStyle,
        duration: kThemeChangeDuration,
        child: subtitle!,
      );
    }

    Widget? trailingIcon;
    if (trailing != null) {
      trailingIcon = AnimatedDefaultTextStyle(
        style: leadingAndTrailingStyle!,
        duration: kThemeChangeDuration,
        child: trailing!,
      );
    }

    const EdgeInsets defaultContentPadding =
        EdgeInsets.symmetric(vertical: 16.0);
    const TextDirection textDirection = TextDirection.ltr;
    final EdgeInsets resolvedContentPadding =
        contentPadding?.resolve(textDirection) ??
            tileTheme.contentPadding?.resolve(textDirection) ??
            defaultContentPadding;

    // Show a basic cursor when disabled or without gesture handlers.
    final Set<WidgetState> mouseStates = <WidgetState>{
      if (!enabled || (onTap == null && onLongPress == null))
        WidgetState.disabled,
    };
    final MouseCursor effectiveMouseCursor =
        WidgetStateProperty.resolveAs<MouseCursor?>(mouseCursor, mouseStates) ??
            tileTheme.mouseCursor?.resolve(mouseStates) ??
            WidgetStateMouseCursor.clickable.resolve(mouseStates);

    // Resolve title alignment from widget, theme, and Material defaults.
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
                  isDense: isDenseLayout,
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

class _IndividualOverrides extends WidgetStateProperty<Color?> {
  _IndividualOverrides({
    this.explicitColor,
    this.enabledColor,
    this.selectedColor,
    this.disabledColor,
  });

  final Color? explicitColor;
  final Color? enabledColor;
  final Color? selectedColor;
  final Color? disabledColor;

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

enum _ListTileSlot {
  leading,
  title,
  subtitle,
  trailing,
}

class _MongolListTile
    extends SlottedMultiChildRenderObjectWidget<_ListTileSlot, RenderBox> {
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

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final bool isThreeLine;
  final bool isDense;
  final VisualDensity visualDensity;
  final TextBaseline titleBaselineType;
  final TextBaseline? subtitleBaselineType;
  final double verticalTitleGap;
  final double minHorizontalPadding;
  final double minLeadingHeight;
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

class _MongolRenderListTile extends RenderBox
    with SlottedContainerRenderObjectMixin<_ListTileSlot, RenderBox> {
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

  RenderBox? get leading => childForSlot(_ListTileSlot.leading);
  RenderBox? get title => childForSlot(_ListTileSlot.title);
  RenderBox? get subtitle => childForSlot(_ListTileSlot.subtitle);
  RenderBox? get trailing => childForSlot(_ListTileSlot.trailing);

  @override
  Iterable<RenderBox> get children {
    return <RenderBox>[
      if (leading != null) leading!,
      if (title != null) title!,
      if (subtitle != null) subtitle!,
      if (trailing != null) trailing!,
    ];
  }

  bool get isDense => _isDense;
  bool _isDense;
  set isDense(bool value) {
    if (_isDense == value) return;
    _isDense = value;
    markNeedsLayout();
  }

  VisualDensity get visualDensity => _visualDensity;
  VisualDensity _visualDensity;
  set visualDensity(VisualDensity value) {
    if (_visualDensity == value) return;
    _visualDensity = value;
    markNeedsLayout();
  }

  bool get isThreeLine => _isThreeLine;
  bool _isThreeLine;
  set isThreeLine(bool value) {
    if (_isThreeLine == value) return;
    _isThreeLine = value;
    markNeedsLayout();
  }

  TextBaseline get titleBaselineType => _titleBaselineType;
  TextBaseline _titleBaselineType;
  set titleBaselineType(TextBaseline value) {
    if (_titleBaselineType == value) return;
    _titleBaselineType = value;
    markNeedsLayout();
  }

  TextBaseline? get subtitleBaselineType => _subtitleBaselineType;
  TextBaseline? _subtitleBaselineType;
  set subtitleBaselineType(TextBaseline? value) {
    if (_subtitleBaselineType == value) return;
    _subtitleBaselineType = value;
    markNeedsLayout();
  }

  double get verticalTitleGap => _verticalTitleGap;
  double _verticalTitleGap;
  double get _effectiveVerticalTitleGap =>
      _verticalTitleGap + visualDensity.vertical * 2.0;

  set verticalTitleGap(double value) {
    if (_verticalTitleGap == value) return;
    _verticalTitleGap = value;
    markNeedsLayout();
  }

  double get minHorizontalPadding => _minHorizontalPadding;
  double _minHorizontalPadding;

  set minHorizontalPadding(double value) {
    if (_minHorizontalPadding == value) return;
    _minHorizontalPadding = value;
    markNeedsLayout();
  }

  double get minLeadingHeight => _minLeadingHeight;
  double _minLeadingHeight;

  set minLeadingHeight(double value) {
    if (_minLeadingHeight == value) return;
    _minLeadingHeight = value;
    markNeedsLayout();
  }

  MongolListTileTitleAlignment get titleAlignment => _titleAlignment;
  MongolListTileTitleAlignment _titleAlignment;
  set titleAlignment(MongolListTileTitleAlignment value) {
    if (_titleAlignment == value) return;
    _titleAlignment = value;
    markNeedsLayout();
  }

  @override
  bool get sizedByParent => false;

  static double _minHeight(RenderBox? box, double width) {
    return box == null ? 0.0 : box.getMinIntrinsicHeight(width);
  }

  static double _maxHeight(RenderBox? box, double width) {
    return box == null ? 0.0 : box.getMaxIntrinsicHeight(width);
  }

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

  double get _defaultTileWidth {
    final bool hasSubtitle = subtitle != null;
    final bool isTwoLine = !isThreeLine && hasSubtitle;
    final bool isOneLine = !isThreeLine && !hasSubtitle;

    final Offset baseDensity = visualDensity.baseSizeAdjustment;
    if (isOneLine) return (isDense ? 48.0 : 56.0) + baseDensity.dx;
    if (isTwoLine) return (isDense ? 64.0 : 72.0) + baseDensity.dx;
    return (isDense ? 76.0 : 88.0) + baseDensity.dx;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return math.max(
      _defaultTileWidth,
      title!.getMinIntrinsicWidth(height) +
          (subtitle?.getMinIntrinsicWidth(height) ?? 0.0),
    );
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return computeMinIntrinsicWidth(height);
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    assert(title != null);
    final BoxParentData parentData = title!.parentData! as BoxParentData;
    return parentData.offset.dx + title!.getDistanceToActualBaseline(baseline)!;
  }

  static double? _boxBaseline(RenderBox box, TextBaseline baseline) {
    return box.getDistanceToBaseline(baseline);
  }

  static Size _layoutBox(RenderBox? box, BoxConstraints constraints) {
    if (box == null) return Size.zero;
    box.layout(constraints, parentUsesSize: true);
    return box.size;
  }

  static void _positionBox(RenderBox box, Offset offset) {
    final BoxParentData parentData = box.parentData! as BoxParentData;
    parentData.offset = offset;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(debugCannotComputeDryLayout(
      reason:
          'Layout requires baseline metrics, which are only available after a full layout.',
    ));
    return Size.zero;
  }

  // Layout constants below follow Material list specifications.
  // https://material.io/design/components/lists.html#specs
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

  @override
  bool hitTestSelf(Offset position) => true;

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

class _LisTileDefaultsM2 extends MongolListTileThemeData {
  _LisTileDefaultsM2(this.context, ListTileStyle style)
      : super(
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
          minLeadingHeight: 40,
          minHorizontalPadding: 4,
          shape: const Border(),
          style: style,
        );

  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);
  late final TextTheme _textTheme = _theme.textTheme;

  @override
  Color? get tileColor => Colors.transparent;

  @override
  TextStyle? get titleTextStyle {
    switch (style!) {
      case ListTileStyle.drawer:
        return _textTheme.bodyLarge;
      case ListTileStyle.list:
        return _textTheme.titleMedium;
    }
  }

  @override
  TextStyle? get subtitleTextStyle =>
      _textTheme.bodyMedium!.copyWith(color: _textTheme.bodySmall!.color);

  @override
  TextStyle? get leadingAndTrailingTextStyle => _textTheme.bodyMedium;

  @override
  Color? get selectedColor => _theme.colorScheme.primary;

  @override
  Color? get iconColor {
    switch (_theme.brightness) {
      case Brightness.light:
        // ä¸ºäº†å‘åŽå…¼å®¹ï¼Œæœªé€‰ä¸­ tile çš„é»˜è®¤å€¼æ˜¯ Colors.black45
        // è€Œä¸æ˜¯ colorScheme.onSurface.withAlpha(0x73)ã€‚
        return Colors.black45;
      case Brightness.dark:
        return null; // nullï¼Œä½¿ç”¨å½“å‰å›¾æ ‡ä¸»é¢˜é¢œè‰²
    }
  }
}

// BEGIN GENERATED TOKEN PROPERTIES - LisTile

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _LisTileDefaultsM3 extends MongolListTileThemeData {
  _LisTileDefaultsM3(this.context)
      : super(
          contentPadding:
              const EdgeInsetsDirectional.only(top: 16.0, bottom: 24.0),
          minLeadingHeight: 24,
          minHorizontalPadding: 8,
          shape: const RoundedRectangleBorder(),
        );

  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);
  late final ColorScheme _colors = _theme.colorScheme;
  late final TextTheme _textTheme = _theme.textTheme;

  @override
  Color? get tileColor => Colors.transparent;

  @override
  TextStyle? get titleTextStyle =>
      _textTheme.bodyLarge!.copyWith(color: _colors.onSurface);

  @override
  TextStyle? get subtitleTextStyle =>
      _textTheme.bodyMedium!.copyWith(color: _colors.onSurfaceVariant);

  @override
  TextStyle? get leadingAndTrailingTextStyle =>
      _textTheme.labelSmall!.copyWith(color: _colors.onSurfaceVariant);

  @override
  Color? get selectedColor => _colors.primary;

  @override
  Color? get iconColor => _colors.onSurfaceVariant;
}

// END GENERATED TOKEN PROPERTIES - LisTile
