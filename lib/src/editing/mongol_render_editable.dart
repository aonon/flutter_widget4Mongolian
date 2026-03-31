// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:mongol/src/base/mongol_text_align.dart';
import 'package:mongol/src/base/mongol_text_painter.dart';
import 'package:mongol/src/base/mongol_paragraph.dart';

part 'mongol_render_editable/horizontal_caret_movement_run.dart';
part 'mongol_render_editable/render_editable.dart';
part 'mongol_render_editable/custom_paint_render_box.dart';
part 'mongol_render_editable/text_highlight_painter.dart';
part 'mongol_render_editable/caret_painter.dart';
part 'mongol_render_editable/composite_painter.dart';
