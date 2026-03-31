// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package

import 'package:flutter/cupertino.dart' show CupertinoTheme;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide EditableTextState;
import 'package:flutter/material.dart'
    show
        InputCounterWidgetBuilder,
        Theme,
        Feedback,
        InputDecoration,
        MaterialLocalizations,
        ThemeData,
        debugCheckHasMaterial,
        debugCheckHasMaterialLocalizations,
        TextSelectionThemeData,
        iOSHorizontalOffset,
        WidgetStateProperty,
        WidgetState;
import 'package:mongol/src/base/mongol_text_align.dart';

import 'alignment.dart';
import 'mongol_editable_text.dart';
import 'mongol_input_decorator.dart';
import 'mongol_mouse_cursors.dart';
import 'mongol_toolbar_options.dart';
import 'platform_utils.dart';
import 'text_selection/mongol_text_selection.dart';
import 'text_selection/mongol_text_selection_controls.dart';

part 'mongol_text_field/selection_gesture_detector_builder.dart';
part 'mongol_text_field/widget.dart';
part 'mongol_text_field/state.dart';
