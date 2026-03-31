// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: omit_local_variable_types

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show
        InputBorder,
        Colors,
        VisualDensity,
        kMinInteractiveDimension,
        FloatingLabelBehavior,
        WidgetStateProperty,
        WidgetState,
        WidgetStateTextStyle,
        WidgetStateColor,
        WidgetStateBorderSide,
        InputDecoration,
        InputDecorationTheme,
        FloatingLabelAlignment,
        IconButtonTheme,
        IconButtonThemeData,
        IconButton,
        Theme,
        ColorScheme,
        ThemeData,
        TextTheme,
        Brightness;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Text;

import '../base/mongol_text_align.dart';
import '../text/mongol_text.dart';
import 'alignment.dart';
import 'input_border.dart';

part 'mongol_input_decorator/border_and_helper_widgets.dart';
part 'mongol_input_decorator/render_decoration.dart';
part 'mongol_input_decorator/widget.dart';
part 'mongol_input_decorator/defaults.dart';
