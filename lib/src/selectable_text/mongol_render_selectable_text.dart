// Copyright 2014 The Flutter Authors.
// Copyright 2020 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../base/mongol_text_align.dart';
import '../base/mongol_text_painter.dart';

const String _kEllipsis = '\u2026';

/// 显示垂直蒙古文可选择文本的渲染对象
///
/// 这个类负责处理蒙古文可选择文本的布局、渲染和选择管理。
/// 支持长按选择、拖动扩展选择和复制到剪切板。
class MongolRenderSelectableText extends RenderBox {
  /// 创建一个垂直可选择文本渲染对象
  MongolRenderSelectableText(
    TextSpan text, {
    MongolTextAlign textAlign = MongolTextAlign.top,
    bool softWrap = true,
    TextOverflow overflow = TextOverflow.clip,
    double textScaleFactor = 1.0,
    int? maxLines,
    bool rotateCJK = true,
    Color selectionColor = const Color.fromARGB(64, 66, 133, 244),
    TextSelectionGestureDetectorBuilder? selectionGestureDetectorBuilder,
    VoidCallback? onSelectionChanged,
  })  : assert(maxLines == null || maxLines > 0),
        _softWrap = softWrap,
        _overflow = overflow,
        _textPainter = MongolTextPainter(
          text: text,
          textAlign: textAlign,
          textScaleFactor: textScaleFactor,
          maxLines: maxLines,
          ellipsis: overflow == TextOverflow.ellipsis ? _kEllipsis : null,
          rotateCJK: rotateCJK,
        ),
        _selectionColor = selectionColor;

  // 蒙古文文本绘制器，负责实际的文本布局和绘制
  final MongolTextPainter _textPainter;

  /// 获取纯文本内容
  String get plainText => _textPainter.plainText;

  // 当前文本选择范围
  TextSelection? _selection;
  TextSelection? get selection => _selection;
  set selection(TextSelection? value) {
    if (_selection == value) return;
    _selection = value;
    markNeedsPaint();
  }

  // 选区高亮颜色
  Color _selectionColor;
  Color get selectionColor => _selectionColor;
  set selectionColor(Color value) {
    if (_selectionColor == value) return;
    _selectionColor = value;
    markNeedsPaint();
  }

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

  /// 文本是否应在软换行符处换行
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

  /// 每个逻辑像素的字体像素数
  double get textScaleFactor => _textPainter.textScaleFactor;
  set textScaleFactor(double value) {
    if (_textPainter.textScaleFactor == value) return;
    _textPainter.textScaleFactor = value;
    markNeedsLayout();
  }

  /// 文本可以跨越的可选最大行数
  int? get maxLines => _textPainter.maxLines;
  set maxLines(int? value) {
    assert(value == null || value > 0);
    if (_textPainter.maxLines == value) {
      return;
    }
    _textPainter.maxLines = value;
    markNeedsLayout();
  }

  /// CJK 字符是否应旋转 90 度
  bool get rotateCJK => _textPainter.rotateCJK;
  set rotateCJK(bool value) {
    if (_textPainter.rotateCJK == value) return;
    _textPainter.rotateCJK = value;
    markNeedsLayout();
  }

  bool _needsClipping = false;
  ui.Shader? _overflowShader;

  /// 布局文本
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
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    _layoutTextWithConstraints(constraints);

    final textSize = _textPainter.size;
    final textDidExceedMaxLines = _textPainter.didExceedMaxLines;
    size = constraints.constrain(textSize);

    final didOverflowWidth =
        size.width < textSize.width || textDidExceedMaxLines;
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
            textScaleFactor: textScaleFactor,
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

    // 绘制选区高亮
    if (_selection != null && !_selection!.isCollapsed) {
      _paintSelection(context, offset);
    }

    // 绘制文本
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

  /// 绘制选区高亮
  void _paintSelection(PaintingContext context, Offset offset) {
    if (_selection == null) return;

    final boxes = _textPainter.getBoxesForSelection(_selection!);
    final paint = Paint()..color = _selectionColor.withValues(alpha: 0.5);

    for (final box in boxes) {
      context.canvas.drawRect(box.shift(offset), paint);
    }
  }

  /// 从点击位置获取文本位置
  TextPosition getPositionForOffset(Offset offset) {
    _layoutTextWithConstraints(constraints);
    return _textPainter.getPositionForOffset(offset);
  }

  /// 获取整个文本的选择范围
  TextSelection getFullTextSelection() {
    return TextSelection(
      baseOffset: 0,
      extentOffset: _textPainter.plainText.length,
    );
  }

  /// 复制选中的文本到剪切板
  Future<void> copySelection() async {
    if (_selection == null || _selection!.isCollapsed) {
      return;
    }
    final plainText = _textPainter.plainText;
    final selectedText = plainText.substring(
      _selection!.start,
      _selection!.end,
    );
    await Clipboard.setData(ClipboardData(text: selectedText));
  }

  /// 获取选中的文本
  String? getSelectedText() {
    if (_selection == null || _selection!.isCollapsed) {
      return null;
    }
    final plainText = _textPainter.plainText;
    return plainText.substring(
      _selection!.start,
      _selection!.end,
    );
  }
}
