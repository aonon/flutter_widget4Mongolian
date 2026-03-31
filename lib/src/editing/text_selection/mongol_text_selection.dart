// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: deprecated_member_use_from_same_package, deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show ValueListenable, defaultTargetPlatform, kIsWeb, listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show kMinInteractiveDimension;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/services.dart'
    show
        HapticFeedback,
        LineBoundary,
        LogicalKeyboardKey,
        ParagraphBoundary,
        HardwareKeyboard,
        TextBoundary;
export 'package:flutter/services.dart' show TextSelectionDelegate;
import 'package:flutter/widgets.dart';

import '../mongol_editable_text.dart';
import '../platform_utils.dart';
import '../mongol_render_editable.dart';

part 'mongol_text_selection/overlay_controller.dart';
part 'mongol_text_selection/gesture_detector_builder.dart';
part 'mongol_text_selection/selection_overlay_widgets.dart';
