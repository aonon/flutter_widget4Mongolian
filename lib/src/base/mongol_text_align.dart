// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// 蒙古文文本垂直对齐方式枚举
///
/// 蒙古文是从左到右垂直书写的，此枚举定义了垂直方向的对齐方式。
/// 底层会映射到 [TextAlign] 枚举：top → left，bottom → right。
enum MongolTextAlign {
  /// 文本顶部对齐容器顶部
  top,

  /// 文本底部对齐容器底部
  bottom,

  /// 文本在容器中垂直居中
  center,

  /// 拉伸软换行文本行以填充容器高度，硬换行文本行向上对齐
  justify,
}
