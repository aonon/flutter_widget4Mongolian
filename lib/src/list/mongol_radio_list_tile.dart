// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'mongol_list_tile.dart';

enum _RadioType { material, adaptive }

class MongolRadioListTile<T> extends StatelessWidget {
  static const Set<WidgetState> _selectedState = <WidgetState>{
    WidgetState.selected,
  };

  static const Set<WidgetState> _defaultState = <WidgetState>{};

  const MongolRadioListTile({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.mouseCursor,
    this.toggleable = false,
    this.activeColor,
    this.fillColor,
    this.hoverColor,
    this.overlayColor,
    this.splashRadius,
    this.materialTapTargetSize,
    this.title,
    this.subtitle,
    this.isThreeLine = false,
    this.dense,
    this.secondary,
    this.selected = false,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.autofocus = false,
    this.contentPadding,
    this.shape,
    this.tileColor,
    this.selectedTileColor,
    this.visualDensity,
    this.focusNode,
    this.onFocusChange,
    this.enableFeedback,
  })  : _radioType = _RadioType.material,
        useCupertinoCheckmarkStyle = false,
        assert(!isThreeLine || subtitle != null);

  const MongolRadioListTile.adaptive({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.mouseCursor,
    this.toggleable = false,
    this.activeColor,
    this.fillColor,
    this.hoverColor,
    this.overlayColor,
    this.splashRadius,
    this.materialTapTargetSize,
    this.title,
    this.subtitle,
    this.isThreeLine = false,
    this.dense,
    this.secondary,
    this.selected = false,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.autofocus = false,
    this.contentPadding,
    this.shape,
    this.tileColor,
    this.selectedTileColor,
    this.visualDensity,
    this.focusNode,
    this.onFocusChange,
    this.enableFeedback,
    this.useCupertinoCheckmarkStyle = false,
  })  : _radioType = _RadioType.adaptive,
        assert(!isThreeLine || subtitle != null);

  final T value;

  final T? groupValue;

  final ValueChanged<T?>? onChanged;

  final MouseCursor? mouseCursor;

  final bool toggleable;

  final Color? activeColor;

  final WidgetStateProperty<Color?>? fillColor;

  final MaterialTapTargetSize? materialTapTargetSize;

  final Color? hoverColor;

  final WidgetStateProperty<Color?>? overlayColor;

  final double? splashRadius;

  final Widget? title;

  final Widget? subtitle;

  final Widget? secondary;

  final bool isThreeLine;

  final bool? dense;

  final bool selected;

  final ListTileControlAffinity controlAffinity;

  final bool autofocus;

  final EdgeInsetsGeometry? contentPadding;

  bool get checked => value == groupValue;

  final ShapeBorder? shape;

  final Color? tileColor;

  final Color? selectedTileColor;

  final VisualDensity? visualDensity;

  final FocusNode? focusNode;

  final ValueChanged<bool>? onFocusChange;

  final bool? enableFeedback;

  final _RadioType _radioType;

  final bool useCupertinoCheckmarkStyle;

  MaterialTapTargetSize get _effectiveTapTargetSize =>
      materialTapTargetSize ?? MaterialTapTargetSize.shrinkWrap;

  void _handleTap() {
    if (onChanged == null) {
      return;
    }
    if (toggleable && checked) {
      onChanged!(null);
      return;
    }
    if (!checked) {
      onChanged!(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget control;
    switch (_radioType) {
      case _RadioType.material:
        control = Radio<T>(
          value: value,
          // ignore: deprecated_member_use
          groupValue: groupValue,
          // ignore: deprecated_member_use
          onChanged: onChanged,
          toggleable: toggleable,
          activeColor: activeColor,
          materialTapTargetSize: _effectiveTapTargetSize,
          autofocus: autofocus,
          fillColor: fillColor,
          mouseCursor: mouseCursor,
          hoverColor: hoverColor,
          overlayColor: overlayColor,
          splashRadius: splashRadius,
        );
      case _RadioType.adaptive:
        control = Radio<T>.adaptive(
          value: value,
          // ignore: deprecated_member_use
          groupValue: groupValue,
          // ignore: deprecated_member_use
          onChanged: onChanged,
          toggleable: toggleable,
          activeColor: activeColor,
          materialTapTargetSize: _effectiveTapTargetSize,
          autofocus: autofocus,
          fillColor: fillColor,
          mouseCursor: mouseCursor,
          hoverColor: hoverColor,
          overlayColor: overlayColor,
          splashRadius: splashRadius,
          useCupertinoCheckmarkStyle: useCupertinoCheckmarkStyle,
        );
    }

    final bool controlIsLeading =
        controlAffinity != ListTileControlAffinity.trailing;
    final Widget? leading = controlIsLeading ? control : secondary;
    final Widget? trailing = controlIsLeading ? secondary : control;
    final ThemeData theme = Theme.of(context);
    final RadioThemeData radioThemeData = RadioTheme.of(context);
    final Set<WidgetState> states = selected ? _selectedState : _defaultState;
    final Color effectiveActiveColor = activeColor ??
        radioThemeData.fillColor?.resolve(states) ??
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
        enabled: onChanged != null,
        shape: shape,
        tileColor: tileColor,
        selectedTileColor: selectedTileColor,
        onTap: onChanged != null ? _handleTap : null,
        selected: selected,
        autofocus: autofocus,
        contentPadding: contentPadding,
        visualDensity: visualDensity,
        focusNode: focusNode,
        onFocusChange: onFocusChange,
        enableFeedback: enableFeedback,
      ),
    );
  }
}
