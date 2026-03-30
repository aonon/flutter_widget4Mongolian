// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui show Gradient, Shader;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:mongol/src/base/mongol_text_align.dart';

import '../base/mongol_text_painter.dart';

// 水平省略号。可以使用蒙古文省略号 U+1801 替代。
const String _kEllipsis = '\u2026';

/// 显示垂直蒙古文文本段落的渲染对象。
/// 
/// 这个类负责处理蒙古文文本的垂直布局和渲染，是 MongolText 和 MongolRichText 组件的底层实现。
class MongolRenderParagraph extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, TextParentData>,
        RenderInlineChildrenContainerDefaults,
        RelayoutWhenSystemFontsChangeMixin {
  /// 创建一个垂直段落渲染对象。
  ///
  /// [maxLines] 属性可以为 null（默认值为 null），但如果不为 null，必须大于 0。
  /// 
  /// 参数：
  /// - text: 要显示的文本内容
  /// - textAlign: 文本垂直对齐方式，默认为顶部对齐
  /// - softWrap: 是否在软换行符处换行，默认为 true
  /// - overflow: 文本溢出处理方式，默认为裁剪
  /// - textScaleFactor: 已弃用，请使用 [textScaler] 替代
  /// - textScaler: 文本缩放策略，默认为无缩放
  /// - maxLines: 最大行数，默认为 null（无限制）
  /// - rotateCJK: 是否将 CJK 字符旋转 90 度以在垂直列中显示，默认为 true
  MongolRenderParagraph(
    TextSpan text, {
    MongolTextAlign textAlign = MongolTextAlign.top,
    bool softWrap = true,
    TextOverflow overflow = TextOverflow.clip,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    double textScaleFactor = 1.0,
    TextScaler textScaler = TextScaler.noScaling,
    int? maxLines,
    bool rotateCJK = true,
  })  : assert(maxLines == null || maxLines > 0),
        assert(
          textScaleFactor == 1.0 || identical(textScaler, TextScaler.noScaling),
          'Use textScaler instead.',
        ),
        _softWrap = softWrap,
        _overflow = overflow,
        _textPainter = MongolTextPainter(
          text: text,
          textAlign: textAlign,
          textScaler: textScaler == TextScaler.noScaling
              ? TextScaler.linear(textScaleFactor)
              : textScaler,
          maxLines: maxLines,
          ellipsis: overflow == TextOverflow.ellipsis ? _kEllipsis : null,
          rotateCJK: rotateCJK,
        );

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! TextParentData) {
      child.parentData = TextParentData();
    }
  }

  // 蒙古文文本绘制器，负责实际的文本布局和绘制
  final MongolTextPainter _textPainter;

  /// 要显示的文本内容
  TextSpan get text => _textPainter.text!;
  set text(TextSpan value) {
    switch (_textPainter.text!.compareTo(value)) {
      case RenderComparison.identical:
      case RenderComparison.metadata:
        return;
      case RenderComparison.paint:
        _textPainter.text = value;
        markNeedsPaint();
        break;
      case RenderComparison.layout:
        _textPainter.text = value;
        markNeedsLayout();
        break;
    }
  }

  /// 文本的垂直对齐方式
  MongolTextAlign get textAlign => _textPainter.textAlign;
  set textAlign(MongolTextAlign value) {
    if (_textPainter.textAlign == value) {
      return;
    }
    _textPainter.textAlign = value;
    markNeedsPaint();
  }

  /// 文本是否应在软换行符处换行。
  ///
  /// 如果为 false，文本中的字形将被定位，就像有无限的垂直空间一样。
  ///
  /// 如果 [softWrap] 为 false，[overflow] 和 [textAlign] 可能会产生意外效果。
  bool get softWrap => _softWrap;
  bool _softWrap;
  set softWrap(bool value) {
    if (_softWrap == value) {
      return;
    }
    _softWrap = value;
    markNeedsLayout();
  }

  /// 视觉溢出的处理方式
  TextOverflow get overflow => _overflow;
  TextOverflow _overflow;
  set overflow(TextOverflow value) {
    if (_overflow == value) {
      return;
    }
    _overflow = value;
    _textPainter.ellipsis = value == TextOverflow.ellipsis ? _kEllipsis : null;
    markNeedsLayout();
  }

  /// 每个逻辑像素的字体像素数。
  ///
  /// 已弃用，请使用 [textScaler] 替代。
  @Deprecated(
    'Use textScaler instead. '
    'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  double get textScaleFactor => _textPainter.textScaleFactor;
  @Deprecated(
    'Use textScaler instead. '
    'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  set textScaleFactor(double value) {
    textScaler = TextScaler.linear(value);
  }

  /// 文本缩放策略，用于根据系统或用户设置调整字体大小。
  TextScaler get textScaler => _textPainter.textScaler;
  set textScaler(TextScaler value) {
    if (_textPainter.textScaler == value) return;
    _textPainter.textScaler = value;
    markNeedsLayout();
  }

  /// 文本可以跨越的可选最大行数，如果需要，会自动换行。
  /// 如果文本超过给定的行数，将根据 [overflow] 和 [softWrap] 进行截断。
  int? get maxLines => _textPainter.maxLines;

  /// 值可以为 null。如果不为 null，则必须大于 0。
  set maxLines(int? value) {
    assert(value == null || value > 0);
    if (_textPainter.maxLines == value) {
      return;
    }
    _textPainter.maxLines = value;
    _overflowShader = null;
    markNeedsLayout();
  }

  /// CJK 字符是否应旋转 90 度以在垂直列中显示为直立。
  bool get rotateCJK => _textPainter.rotateCJK;
  set rotateCJK(bool value) {
    if (_textPainter.rotateCJK == value) return;
    _textPainter.rotateCJK = value;
    markNeedsLayout();
  }

  // 是否需要裁剪文本
  bool _needsClipping = false;
  // 溢出效果的着色器
  ui.Shader? _overflowShader;

  /// 此段落当前是否有用于其溢出效果的 [dart:ui.Shader]。
  ///
  /// 用于测试此对象。不在生产环境中使用。
  @visibleForTesting
  bool get debugHasOverflowShader => _overflowShader != null;

  @override
  void systemFontsDidChange() {
    super.systemFontsDidChange();
    _textPainter.markNeedsLayout();
  }

  /// 布局文本
  /// 
  /// 参数：
  /// - minHeight: 最小高度，默认为 0.0
  /// - maxHeight: 最大高度，默认为无穷大
  void _layoutText({
    double minHeight = 0.0,
    double maxHeight = double.infinity,
  }) {
    final heightMatters = softWrap || overflow == TextOverflow.ellipsis;
    _textPainter.layout(
      minHeight: minHeight,
      maxHeight: heightMatters ? maxHeight : double.infinity,
    );
  }

  /// 使用约束条件布局文本
  /// 
  /// 参数：
  /// - constraints: 布局约束条件
  void _layoutTextWithConstraints(BoxConstraints constraints) {
    _layoutText(
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _layoutText();
    return _textPainter.minIntrinsicHeight;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    _layoutText();
    return _textPainter.maxIntrinsicHeight;
  }

  /// 计算内在宽度
  /// 
  /// 参数：
  /// - height: 高度
  /// 
  /// 返回：
  /// - 计算出的内在宽度
  double _computeIntrinsicWidth(double height) {
    _layoutText(minHeight: height, maxHeight: height);
    return _textPainter.width;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return _computeIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _computeIntrinsicWidth(height);
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    assert(!debugNeedsLayout);
    assert(constraints.debugAssertIsValid());
    _layoutTextWithConstraints(constraints);
    return _textPainter.computeDistanceToActualBaseline(baseline);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    if (event is! PointerDownEvent) return;
    _layoutTextWithConstraints(constraints);
    final offset = entry.localPosition;
    final position = _textPainter.getPositionForOffset(offset);
    final span = _textPainter.text!.getSpanForPosition(position);
    if (span == null) {
      return;
    }
    if (span is TextSpan) {
      span.recognizer?.addPointer(event);
    }
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    _layoutTextWithConstraints(constraints);

    // 我们在这里获取 _textPainter.size 和 _textPainter.didExceedMaxLines，因为
    // 分配给 `size` 将触发我们验证我们的内在大小，
    // 这将改变 _textPainter 的布局，因为内在大小
    // 计算是破坏性的。其他 _textPainter 状态也会
    // 受到影响。另请参阅具有类似问题的 MongolRenderEditable。
    final textSize = _textPainter.size;
    final textDidExceedMaxLines = _textPainter.didExceedMaxLines;
    size = constraints.constrain(textSize);

    final didOverflowWidth = size.width < textSize.width || textDidExceedMaxLines;
    final didOverflowHeight = size.height < textSize.height;
    final hasVisualOverflow = didOverflowHeight || didOverflowWidth;
    if (hasVisualOverflow) {
      switch (_overflow) {
        case TextOverflow.visible:
          _needsClipping = false;
          _overflowShader = null;
          break;
        case TextOverflow.clip:
        case TextOverflow.ellipsis:
          _needsClipping = true;
          _overflowShader = null;
          break;
        case TextOverflow.fade:
          _needsClipping = true;
          final fadeSizePainter = MongolTextPainter(
            text: TextSpan(style: _textPainter.text!.style, text: '\u2026'),
            textScaler: textScaler,
          )..layout();
          if (didOverflowWidth) {
            double fadeEnd, fadeStart;
            fadeEnd = size.height;
            fadeStart = fadeEnd - fadeSizePainter.height;
            _overflowShader = ui.Gradient.linear(
              Offset(0.0, fadeStart),
              Offset(0.0, fadeEnd),
              <Color>[const Color(0xFFFFFFFF), const Color(0x00FFFFFF)],
            );
          } else {
            final fadeEnd = size.width;
            final fadeStart = fadeEnd - fadeSizePainter.width / 2.0;
            _overflowShader = ui.Gradient.linear(
              Offset(fadeStart, 0.0),
              Offset(fadeEnd, 0.0),
              <Color>[const Color(0xFFFFFFFF), const Color(0x00FFFFFF)],
            );
          }
          break;
      }
    } else {
      _needsClipping = false;
      _overflowShader = null;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _layoutTextWithConstraints(constraints);
    assert(() {
      if (debugRepaintTextRainbowEnabled) {
        final paint = Paint()..color = debugCurrentRepaintColor.toColor();
        context.canvas.drawRect(offset & size, paint);
      }
      return true;
    }());

    if (_needsClipping) {
      final bounds = offset & size;
      if (_overflowShader != null) {
        // 这个层限制了下面的着色器混合的内容，使其仅与文本（而不是文本及其背景）混合。
        context.canvas.saveLayer(bounds, Paint());
      } else {
        context.canvas.save();
      }
      context.canvas.clipRect(bounds);
    }

    _textPainter.paint(context.canvas, offset);

    if (_needsClipping) {
      if (_overflowShader != null) {
        context.canvas.translate(offset.dx, offset.dy);
        final paint = Paint()
          ..blendMode = BlendMode.modulate
          ..shader = _overflowShader;
        context.canvas.drawRect(Offset.zero & size, paint);
      }
      context.canvas.restore();
    }
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return <DiagnosticsNode>[
      text.toDiagnosticsNode(
          name: 'text', style: DiagnosticsTreeStyle.transition)
    ];
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<MongolTextAlign>('textAlign', textAlign));
    properties.add(FlagProperty(
      'softWrap',
      value: softWrap,
      ifTrue: 'wrapping at box height',
      ifFalse: 'no wrapping except at line break characters',
      showName: true,
    ));
    properties.add(EnumProperty<TextOverflow>('overflow', overflow));
    properties.add(DiagnosticsProperty<TextScaler>(
        'textScaler', textScaler, defaultValue: TextScaler.noScaling));
    properties.add(IntProperty('maxLines', maxLines, ifNull: 'unlimited'));
  }
}
