// Copyright 2014 The Flutter Authors.
// Copyright 2024 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

/// TextEditingController 的扩展方法
/// 提供用于检查文本选择是否在文本边界内的功能
extension TextEditingControllerExtension on TextEditingController {
  /// 检查 [selection] 是否在 [text] 的边界内
  /// 
  /// 当选择的起始位置和结束位置都不超过文本长度时，返回 true
  bool isSelectionWithinTextBounds(TextSelection selection) {
    return selection.start <= text.length && selection.end <= text.length;
  }
}
