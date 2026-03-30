// Copyright 2014 The Flutter Authors.
// Copyright 2020 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'mongol_rich_text.dart';
import '../base/mongol_text_painter.dart';
import '../base/mongol_text_align.dart';

/// 用于显示垂直蒙古文文本的组件
///
/// 显示具有单一样式的垂直文本字符串，支持自动换行和多行显示。
/// 当未指定样式时，会继承最近的 [DefaultTextStyle]。
///
/// {@tool snippet}
/// 示例：显示居中对齐的粗体文本，溢出时显示省略号
/// ```dart
/// MongolText(
///   'Hello, $_name! How are you?',
///   textAlign: MongolTextAlign.center,
///   overflow: TextOverflow.ellipsis,
///   style: TextStyle(fontWeight: FontWeight.bold),
/// )
/// ```
/// {@end-tool}
///
/// {@tool snippet}
/// 示例：使用富文本显示不同样式的文本
/// ```dart
/// const MongolText.rich(
///   TextSpan(
///     text: 'Hello',
///     children: <TextSpan>[
///       TextSpan(text: ' beautiful ', style: TextStyle(fontStyle: FontStyle.italic)),
///       TextSpan(text: 'world', style: TextStyle(fontWeight: FontWeight.bold)),
///     ],
///   ),
/// )
/// ```
/// {@end-tool}
///
/// 另请参见：
///  * [MongolRichText] - 提供更精细的文本样式控制
///  * [DefaultTextStyle] - 为所有子级文本组件设置默认样式
class MongolText extends StatelessWidget {
  /// 创建用于垂直蒙古文布局的文本小部件
  const MongolText(
    String this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.softWrap,
    this.overflow,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    this.textScaleFactor,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.rotateCJK = true,
  })  : textSpan = null,
        assert(
          textScaler == null || textScaleFactor == null,
          'textScaleFactor is deprecated and cannot be specified when textScaler is specified.',
        );

  /// 使用 [TextSpan] 创建垂直蒙古文文本小部件
  const MongolText.rich(
    TextSpan this.textSpan, {
    super.key,
    this.style,
    this.textAlign,
    this.softWrap,
    this.overflow,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    this.textScaleFactor,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.rotateCJK = true,
  })  : data = null,
        assert(
          textScaler == null || textScaleFactor == null,
          'textScaleFactor is deprecated and cannot be specified when textScaler is specified.',
        );

  /// 要显示的文本内容
  final String? data;

  /// 要显示的富文本内容
  final TextSpan? textSpan;

  /// 文本样式
  final TextStyle? style;

  /// 文本垂直对齐方式
  final MongolTextAlign? textAlign;

  /// 是否允许文本在软换行处断开
  final bool? softWrap;

  /// 文本溢出时的处理方式
  final TextOverflow? overflow;

  /// 文本缩放因子（已弃用，请使用 [textScaler]）
  @Deprecated(
    'Use textScaler instead. '
    'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  final double? textScaleFactor;

  /// 文本缩放策略
  final TextScaler? textScaler;

  /// 文本最大行数
  final int? maxLines;

  /// 语义化标签，用于辅助功能
  final String? semanticsLabel;

  /// 中文、日文和韩文字符是否旋转90度
  /// 默认为 true
  final bool rotateCJK;

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = DefaultTextStyle.of(context);
    var effectiveTextStyle = style;
    if (style == null || style!.inherit) {
      effectiveTextStyle = defaultTextStyle.style.merge(effectiveTextStyle);
    }
    if (MediaQuery.boldTextOf(context)) {
      effectiveTextStyle = effectiveTextStyle!
          .merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    final defaultTextAlign =
        mapHorizontalToMongolTextAlign(defaultTextStyle.textAlign);
    final TextSpan effectiveSpan = TextSpan(
      style: effectiveTextStyle,
      text: data,
      children: textSpan != null ? <TextSpan>[textSpan!] : null,
    );

    final TextScaler effectiveTextScaler = switch ((textScaler, textScaleFactor)) {
      (final TextScaler scaler, _) => scaler,
      (null, final double factor) => TextScaler.linear(factor),
      (null, null) => MediaQuery.textScalerOf(context),
    };

    Widget result = MongolRichText(
      textAlign: textAlign ?? defaultTextAlign ?? MongolTextAlign.top,
      softWrap: softWrap ?? defaultTextStyle.softWrap,
      overflow: overflow ?? defaultTextStyle.overflow,
      textScaler: effectiveTextScaler,
      maxLines: maxLines ?? defaultTextStyle.maxLines,
      rotateCJK: rotateCJK,
      text: effectiveSpan,
    );
    if (semanticsLabel != null) {
      result = Semantics(
        // Use the ambient directionality so semantics reflect the app's
        // text direction (was previously hard-coded to LTR).
        textDirection: Directionality.of(context),
        label: semanticsLabel,
        child: ExcludeSemantics(
          child: result,
        ),
      );
    }
    return result;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('data', data, showName: false));
    if (textSpan != null) {
      properties.add(textSpan!.toDiagnosticsNode(
          name: 'textSpan', style: DiagnosticsTreeStyle.transition));
    }
    style?.debugFillProperties(properties);
    properties.add(EnumProperty<MongolTextAlign>('textAlign', textAlign,
        defaultValue: null));
    properties.add(FlagProperty('softWrap',
        value: softWrap,
        ifTrue: 'wrapping at box height',
        ifFalse: 'no wrapping except at line break characters',
        showName: true));
    properties.add(
        EnumProperty<TextOverflow>('overflow', overflow, defaultValue: null));
    properties.add(
        DoubleProperty('textScaleFactor', textScaleFactor, defaultValue: null));
    properties.add(DiagnosticsProperty<TextScaler>(
        'textScaler', textScaler, defaultValue: null));
    properties.add(IntProperty('maxLines', maxLines, defaultValue: null));
    if (semanticsLabel != null) {
      properties.add(StringProperty('semanticsLabel', semanticsLabel));
    }
    properties.add(FlagProperty('rotateCJK',
        value: rotateCJK,
        ifTrue: 'rotate CJK characters',
        ifFalse: 'do not rotate CJK characters',
        showName: true));
  }
}
