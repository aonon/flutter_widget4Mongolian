// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

/// Configures which actions are shown in Mongol text selection menus.
@immutable
class MongolToolbarOptions {
  const MongolToolbarOptions({
    this.copy = false,
    this.cut = false,
    this.paste = false,
    this.selectAll = false,
  });

  static const MongolToolbarOptions empty = MongolToolbarOptions();

  final bool copy;
  final bool cut;
  final bool paste;
  final bool selectAll;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MongolToolbarOptions &&
        other.copy == copy &&
        other.cut == cut &&
        other.paste == paste &&
        other.selectAll == selectAll;
  }

  @override
  int get hashCode => Object.hash(copy, cut, paste, selectAll);
}

const MongolToolbarOptions kMongolToolbarReadOnly = MongolToolbarOptions(
  selectAll: true,
  copy: true,
);

const MongolToolbarOptions kMongolToolbarEditableObscure = MongolToolbarOptions(
  selectAll: true,
  paste: true,
);

const MongolToolbarOptions kMongolToolbarEditableAll = MongolToolbarOptions(
  copy: true,
  cut: true,
  selectAll: true,
  paste: true,
);

MongolToolbarOptions resolveEditableToolbarOptions({
  required MongolToolbarOptions? toolbarOptions,
  required bool readOnly,
  required bool obscureText,
  required Object? selectionControls,
}) {
  if (selectionControls is TextSelectionHandleControls &&
      toolbarOptions == null) {
    return MongolToolbarOptions.empty;
  }
  if (toolbarOptions != null) {
    return toolbarOptions;
  }
  if (obscureText) {
    return readOnly
        ? MongolToolbarOptions.empty
        : kMongolToolbarEditableObscure;
  }
  return readOnly ? kMongolToolbarReadOnly : kMongolToolbarEditableAll;
}

MongolToolbarOptions resolveTextFieldToolbarOptions({
  required MongolToolbarOptions? toolbarOptions,
  required bool obscureText,
}) {
  return toolbarOptions ??
      (obscureText ? kMongolToolbarEditableObscure : kMongolToolbarEditableAll);
}
