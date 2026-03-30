// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'mongol_render_paragraph.dart';
import '../base/mongol_text_align.dart';

/// 用于显示垂直蒙古文富文本的组件
///
/// 显示使用多种不同样式的垂直文本，通过 [TextSpan] 对象树描述文本和样式关系。
/// 支持自动换行和多行显示。
///
/// 建议：
/// - 当所有文本使用相同样式时，使用 [MongolText] 更简洁
/// - 当需要混合多种样式时，使用 [MongolRichText] 或 [MongolText.rich]
///
/// {@tool snippet}
/// 示例：显示混合样式的垂直文本
/// ```dart
/// MongolRichText(
///   text: TextSpan(
///     text: 'Hello ',
///     style: DefaultTextStyle.of(context).style,
///     children: <TextSpan>[
///       TextSpan(text: 'bold', style: TextStyle(fontWeight: FontWeight.bold)),
///       TextSpan(text: ' world!'),
///     ],
///   ),
/// )
/// ```
/// {@end-tool}
///
/// 另请参见：
///  * [TextStyle] - 文本样式设置
///  * [TextSpan] - 段落文本描述
///  * [MongolText] - 单一样式垂直文本组件
///  * [MongolText.rich] - 支持富文本的常量文本组件
class MongolRichText extends LeafRenderObjectWidget {
  /// 创建垂直方向的蒙古文富文本段落
  MongolRichText({
    super.key,
    required this.text,
    this.textAlign = MongolTextAlign.top,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    double textScaleFactor = 1.0,
    TextScaler textScaler = TextScaler.noScaling,
    this.maxLines,
    this.rotateCJK = true,
  }) : assert(maxLines == null || maxLines > 0),
       assert(
         textScaleFactor == 1.0 || identical(textScaler, TextScaler.noScaling),
         'Use textScaler instead.',
       ),
       textScaler = _effectiveTextScalerFrom(textScaler, textScaleFactor);

  static TextScaler _effectiveTextScalerFrom(
      TextScaler textScaler, double textScaleFactor) {
    return switch ((textScaler, textScaleFactor)) {
      (final TextScaler scaler, 1.0) => scaler,
      (TextScaler.noScaling, final double factor) => TextScaler.linear(factor),
      (final TextScaler scaler, _) => scaler,
    };
  }

  /// 要显示的富文本内容
  final TextSpan text;

  /// 文本垂直对齐方式
  final MongolTextAlign textAlign;

  /// 是否允许文本在软换行处断开
  final bool softWrap;

  /// 文本溢出时的处理方式
  final TextOverflow overflow;

  /// 文本缩放因子（已弃用，请使用 [textScaler]）
  @Deprecated(
    'Use textScaler instead. '
    'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  double get textScaleFactor => textScaler.textScaleFactor;

  /// 文本缩放策略
  final TextScaler textScaler;

  /// 文本最大行数
  final int? maxLines;

  /// 中文、日文和韩文字符是否旋转90度
  /// 默认为 true
  final bool rotateCJK;

  @override
  MongolRenderParagraph createRenderObject(BuildContext context) {
    return MongolRenderParagraph(
      text,
      textAlign: textAlign,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      rotateCJK: rotateCJK,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, MongolRenderParagraph renderObject) {
    renderObject
      ..text = text
      ..textAlign = textAlign
      ..softWrap = softWrap
      ..overflow = overflow
      ..textScaler = textScaler
      ..maxLines = maxLines
      ..rotateCJK = rotateCJK;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('text', text.toPlainText()));
    properties.add(EnumProperty<MongolTextAlign>('textAlign', textAlign,
        defaultValue: MongolTextAlign.top));
    properties.add(FlagProperty('softWrap',
        value: softWrap,
        ifTrue: 'wrapping at box height',
        ifFalse: 'no wrapping except at line break characters',
        showName: true));
    properties.add(EnumProperty<TextOverflow>('overflow', overflow,
        defaultValue: TextOverflow.clip));
    properties.add(DiagnosticsProperty<TextScaler>(
        'textScaler', textScaler, defaultValue: TextScaler.noScaling));
    properties.add(IntProperty('maxLines', maxLines, ifNull: 'unlimited'));
    properties.add(FlagProperty('rotateCJK',
        value: rotateCJK,
        ifTrue: 'rotate CJK characters',
        ifFalse: 'do not rotate CJK characters',
        showName: true));
  }
}
