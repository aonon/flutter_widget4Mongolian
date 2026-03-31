// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'mongol_list_tile.dart';

enum _CheckboxType { material, adaptive }

class MongolCheckboxListTile extends StatelessWidget {
  static const Set<WidgetState> _selectedState = <WidgetState>{
    WidgetState.selected,
  };

  static const Set<WidgetState> _defaultState = <WidgetState>{};

  const MongolCheckboxListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.mouseCursor,
    this.activeColor,
    this.fillColor,
    this.checkColor,
    this.hoverColor,
    this.overlayColor,
    this.splashRadius,
    this.materialTapTargetSize,
    this.visualDensity,
    this.focusNode,
    this.autofocus = false,
    this.shape,
    this.side,
    this.isError = false,
    this.enabled,
    this.tileColor,
    this.title,
    this.subtitle,
    this.isThreeLine = false,
    this.dense,
    this.secondary,
    this.selected = false,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.contentPadding,
    this.tristate = false,
    this.checkboxShape,
    this.selectedTileColor,
    this.onFocusChange,
    this.enableFeedback,
    this.checkboxSemanticLabel,
  })  : _checkboxType = _CheckboxType.material,
        assert(tristate || value != null),
        assert(!isThreeLine || subtitle != null);

  const MongolCheckboxListTile.adaptive({
    super.key,
    required this.value,
    required this.onChanged,
    this.mouseCursor,
    this.activeColor,
    this.fillColor,
    this.checkColor,
    this.hoverColor,
    this.overlayColor,
    this.splashRadius,
    this.materialTapTargetSize,
    this.visualDensity,
    this.focusNode,
    this.autofocus = false,
    this.shape,
    this.side,
    this.isError = false,
    this.enabled,
    this.tileColor,
    this.title,
    this.subtitle,
    this.isThreeLine = false,
    this.dense,
    this.secondary,
    this.selected = false,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.contentPadding,
    this.tristate = false,
    this.checkboxShape,
    this.selectedTileColor,
    this.onFocusChange,
    this.enableFeedback,
    this.checkboxSemanticLabel,
  })  : _checkboxType = _CheckboxType.adaptive,
        assert(tristate || value != null),
        assert(!isThreeLine || subtitle != null);

  final bool? value;

  final ValueChanged<bool?>? onChanged;

  final MouseCursor? mouseCursor;

  final Color? activeColor;

  final WidgetStateProperty<Color?>? fillColor;

  final Color? checkColor;

  final Color? hoverColor;

  final WidgetStateProperty<Color?>? overlayColor;

  final double? splashRadius;

  final MaterialTapTargetSize? materialTapTargetSize;

  final VisualDensity? visualDensity;

  final FocusNode? focusNode;

  final bool autofocus;

  final ShapeBorder? shape;

  final BorderSide? side;

  final bool isError;

  final Color? tileColor;

  final Widget? title;

  final Widget? subtitle;

  final Widget? secondary;

  final bool isThreeLine;

  final bool? dense;

  final bool selected;

  final ListTileControlAffinity controlAffinity;

  final EdgeInsetsGeometry? contentPadding;

  final bool tristate;

  final OutlinedBorder? checkboxShape;

  final Color? selectedTileColor;

  final ValueChanged<bool>? onFocusChange;

  final bool? enableFeedback;

  final bool? enabled;

  final String? checkboxSemanticLabel;

  final _CheckboxType _checkboxType;

  MaterialTapTargetSize get _effectiveTapTargetSize =>
      materialTapTargetSize ?? MaterialTapTargetSize.shrinkWrap;

  bool get _isInteractive => enabled ?? onChanged != null;

  void _handleValueChange() {
    assert(onChanged != null);
    final bool? nextValue;
    if (value == false) {
      nextValue = true;
    } else if (value == true) {
      nextValue = tristate ? null : false;
    } else {
      nextValue = false;
    }
    onChanged!(nextValue);
  }

  @override
  Widget build(BuildContext context) {
    final Widget control;

    switch (_checkboxType) {
      case _CheckboxType.material:
        control = Checkbox(
          value: value,
          onChanged: _isInteractive ? onChanged : null,
          mouseCursor: mouseCursor,
          activeColor: activeColor,
          fillColor: fillColor,
          checkColor: checkColor,
          hoverColor: hoverColor,
          overlayColor: overlayColor,
          splashRadius: splashRadius,
          materialTapTargetSize: _effectiveTapTargetSize,
          autofocus: autofocus,
          tristate: tristate,
          shape: checkboxShape,
          side: side,
          isError: isError,
          semanticLabel: checkboxSemanticLabel,
        );
      case _CheckboxType.adaptive:
        control = Checkbox.adaptive(
          value: value,
          onChanged: _isInteractive ? onChanged : null,
          mouseCursor: mouseCursor,
          activeColor: activeColor,
          fillColor: fillColor,
          checkColor: checkColor,
          hoverColor: hoverColor,
          overlayColor: overlayColor,
          splashRadius: splashRadius,
          materialTapTargetSize: _effectiveTapTargetSize,
          autofocus: autofocus,
          tristate: tristate,
          shape: checkboxShape,
          side: side,
          isError: isError,
          semanticLabel: checkboxSemanticLabel,
        );
    }

    final bool controlIsLeading =
        controlAffinity == ListTileControlAffinity.leading;
    final Widget? leading = controlIsLeading ? control : secondary;
    final Widget? trailing = controlIsLeading ? secondary : control;
    final ThemeData theme = Theme.of(context);
    final CheckboxThemeData checkboxTheme = CheckboxTheme.of(context);
    final Set<WidgetState> states = selected ? _selectedState : _defaultState;
    final Color effectiveActiveColor = activeColor ??
        checkboxTheme.fillColor?.resolve(states) ??
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
        enabled: _isInteractive,
        onTap: onChanged != null ? _handleValueChange : null,
        selected: selected,
        autofocus: autofocus,
        contentPadding: contentPadding,
        shape: shape,
        selectedTileColor: selectedTileColor,
        tileColor: tileColor,
        visualDensity: visualDensity,
        focusNode: focusNode,
        onFocusChange: onFocusChange,
        enableFeedback: enableFeedback,
      ),
    );
  }
}
