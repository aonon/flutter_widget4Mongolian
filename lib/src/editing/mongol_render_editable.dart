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

// 光标间隙（像素）
const double _kCaretGap = 1.0; // pixels
// 光标宽度偏移（像素）
const double _kCaretWidthOffset = 2.0; // pixels

/// 光标在水平方向上移动时应移动到的连续 [TextPosition] 序列
/// 当用户使用左箭头键或右箭头键导航段落时使用
///
/// 当用户按下左箭头键或右箭头键时，在许多平台（例如 macOS）上，
/// 光标会移动到上一行或下一行，同时保持其原始水平位置
/// 当遇到较短的行时，光标会移动到该行内最近的水平位置，
/// 当遇到足够长的行时，会恢复原始水平位置
///
/// 此外，如果光标已经在第一行并按下左箭头键，光标会移动到文档的开头
/// 如果接下来按下右箭头键，光标会恢复其原始水平位置并移动到第二行
/// 类似地，如果光标已经在最后一行并按下右箭头键，光标会移动到文档的末尾
///
/// 考虑一个顶部对齐的段落：
///   a  a  a
///   a     a
///  ——     a
/// 假设光标最初位于第一行的末尾。按一次右箭头键会将光标移动到第二行的末尾，
/// 按两次箭头键会移动到第三行的第二个 "a" 之后
/// 再次按右箭头键，光标会移动到第三行的末尾（文档的末尾）
/// 在这种状态下按左箭头键会导致光标移动到第二行的末尾
///
/// 当文本的布局发生变化（包括文本本身发生变化）时，或者当选择被其他输入事件或
/// 以编程方式更改时（例如，当用户按下上箭头键时），水平光标运行通常会被中断
///
/// [movePrevious] 方法将光标位置（即 [HorizontalCaretMovementRun.current]）移动到上一行，
/// 如果光标已经在第一行，则该方法不执行任何操作并返回 false
/// 类似地，[moveNext] 方法将光标移动到下一行，如果光标已经在最后一行，则返回 false
///
/// 如果基础段落的布局发生变化，[isValid] 变为 false，并且不得使用 [HorizontalCaretMovementRun]
/// 在调用 [movePrevious] 和 [moveNext] 或访问 [current] 之前，必须检查 [isValid] 属性
class HorizontalCaretMovementRun implements Iterator<TextPosition> {
  /// 私有构造函数
  HorizontalCaretMovementRun._(
    this._editable,
    this._lineMetrics,
    this._currentTextPosition,
    this._currentLine,
    this._currentOffset,
  );

  Offset _currentOffset; // 当前偏移量
  int _currentLine; // 当前行
  TextPosition _currentTextPosition; // 当前文本位置

  final List<MongolLineMetrics> _lineMetrics; // 行度量信息
  final MongolRenderEditable _editable; // 可编辑渲染对象

  bool _isValid = true; // 是否有效

  /// 此 [HorizontalCaretMovementRun] 是否可以继续
  ///
  /// 如果基础文本布局没有更改，则 [HorizontalCaretMovementRun] 运行有效
  ///
  /// 当 [isValid] 为 false 时，不得访问 [current] 值以及 [movePrevious] 和 [moveNext] 方法
  bool get isValid {
    if (!_isValid) {
      return false;
    }
    final List<MongolLineMetrics> newLineMetrics =
        _editable._textPainter.computeLineMetrics();
    // 使用 computeLineMetrics 方法的实现细节来确定当前文本布局是否已失效
    if (!identical(newLineMetrics, _lineMetrics)) {
      _isValid = false;
    }
    return _isValid;
  }

  // 缓存位置信息
  final Map<int, MapEntry<Offset, TextPosition>> _positionCache =
      <int, MapEntry<Offset, TextPosition>>{};

  /// 获取指定行的文本位置
  MapEntry<Offset, TextPosition> _getTextPositionForLine(int lineNumber) {
    assert(isValid);
    assert(lineNumber >= 0);
    final MapEntry<Offset, TextPosition>? cachedPosition =
        _positionCache[lineNumber];
    if (cachedPosition != null) {
      return cachedPosition;
    }
    assert(lineNumber != _currentLine);

    final Offset newOffset =
        Offset(_lineMetrics[lineNumber].baseline, _currentOffset.dy);
    final TextPosition closestPosition =
        _editable._textPainter.getPositionForOffset(newOffset);
    final MapEntry<Offset, TextPosition> position =
        MapEntry<Offset, TextPosition>(newOffset, closestPosition);
    _positionCache[lineNumber] = position;
    return position;
  }

  @override
  /// 获取当前文本位置
  TextPosition get current {
    assert(isValid);
    return _currentTextPosition;
  }

  @override
  /// 移动到下一行
  bool moveNext() {
    assert(isValid);
    if (_currentLine + 1 >= _lineMetrics.length) {
      return false;
    }
    final MapEntry<Offset, TextPosition> position =
        _getTextPositionForLine(_currentLine + 1);
    _currentLine += 1;
    _currentOffset = position.key;
    _currentTextPosition = position.value;
    return true;
  }

  /// 移动到上一行
  bool movePrevious() {
    assert(isValid);
    if (_currentLine <= 0) {
      return false;
    }
    final MapEntry<Offset, TextPosition> position =
        _getTextPositionForLine(_currentLine - 1);
    _currentLine -= 1;
    _currentOffset = position.key;
    _currentTextPosition = position.value;
    return true;
  }
}

/// 在可滚动容器中显示带有可能闪烁的光标和手势识别器的文本
///
/// 这是可编辑垂直文本字段的渲染器。它不直接提供编辑文本的方法，
/// 但它处理文本选择和文本光标的操作。
///
/// [text] 被显示，通过给定的 [offset] 滚动，根据 [textAlign] 对齐
/// [maxLines] 属性控制文本是显示在一行还是多行
/// [selection] 如果不是折叠的，则以 [selectionColor] 绘制
/// 如果是折叠的，则表示光标位置
/// 当 [showCursor] 为 true 时显示光标，以 [cursorColor] 绘制
///
/// 如果在渲染对象绘制时发现光标位置已更改，则调用 [onCaretChanged]
///
/// 键盘处理、IME 处理、滚动、切换 [showCursor] 值以实际闪烁光标以及
/// 上面未提及的其他功能是更高层的责任，不由此对象处理
class MongolRenderEditable extends RenderBox
    with RelayoutWhenSystemFontsChangeMixin
    implements TextLayoutMetrics {
  /// 创建实现文本字段视觉方面的渲染对象
  ///
  /// [textAlign] 参数不能为空，默认为 [MongolTextAlign.top]
  ///
  /// 如果未指定 [showCursor]，则默认为隐藏光标
  ///
  /// [maxLines] 属性可以设置为 null 以移除对行数的限制
  /// 默认情况下，它为 1，表示这是单行文本字段
  /// 如果不为 null，则必须大于零
  ///
  /// [offset] 是必需的，不能为空
  /// 如果不需要滚动，可以使用 [ViewportOffset.zero]
  MongolRenderEditable({
    TextSpan? text,
    MongolTextAlign textAlign = MongolTextAlign.top,
    Color? cursorColor,
    ValueNotifier<bool>? showCursor,
    bool? hasFocus,
    required LayerLink startHandleLayerLink,
    required LayerLink endHandleLayerLink,
    int? maxLines = 1,
    int? minLines,
    bool expands = false,
    Color? selectionColor,
    double textScaleFactor = 1.0,
    TextSelection? selection,
    required ViewportOffset offset,
    this.ignorePointer = false,
    bool readOnly = false,
    bool forceLine = true,
    String obscuringCharacter = '•',
    bool obscureText = false,
    double? cursorWidth,
    double cursorHeight = 1.0,
    Radius? cursorRadius,
    Offset cursorOffset = Offset.zero,
    double devicePixelRatio = 1.0,
    bool? enableInteractiveSelection,
    Clip clipBehavior = Clip.hardEdge,
    required this.textSelectionDelegate,
    MongolRenderEditablePainter? painter,
    MongolRenderEditablePainter? foregroundPainter,
  })  : assert(maxLines == null || maxLines > 0),
        assert(minLines == null || minLines > 0),
        assert(
          (maxLines == null) || (minLines == null) || (maxLines >= minLines),
          "minLines can't be greater than maxLines",
        ),
        assert(
          !expands || (maxLines == null && minLines == null),
          'minLines and maxLines must be null when expands is true.',
        ),
        assert(obscuringCharacter.characters.length == 1),
        assert(cursorWidth == null || cursorWidth >= 0.0),
        assert(cursorHeight >= 0.0),
        _textPainter = MongolTextPainter(
          text: text,
          textAlign: textAlign,
          textScaleFactor: textScaleFactor,
          maxLines: maxLines == 1 ? 1 : null,
        ),
        _showCursor = showCursor ?? ValueNotifier<bool>(false),
        _maxLines = maxLines,
        _minLines = minLines,
        _expands = expands,
        _selection = selection,
        _offset = offset,
        _cursorWidth = cursorWidth,
        _cursorHeight = cursorHeight,
        _enableInteractiveSelection = enableInteractiveSelection,
        _devicePixelRatio = devicePixelRatio,
        _startHandleLayerLink = startHandleLayerLink,
        _endHandleLayerLink = endHandleLayerLink,
        _obscuringCharacter = obscuringCharacter,
        _obscureText = obscureText,
        _readOnly = readOnly,
        _forceLine = forceLine,
        _clipBehavior = clipBehavior {
    assert(!_showCursor.value || cursorColor != null);
    this.hasFocus = hasFocus ?? false;

    _selectionPainter.highlightColor = selectionColor;
    _selectionPainter.highlightedRange = selection;

    _caretPainter.caretColor = cursorColor;
    _caretPainter.cursorRadius = cursorRadius;
    _caretPainter.cursorOffset = cursorOffset;

    _updateForegroundPainter(foregroundPainter);
    _updatePainter(painter);
  }

  /// 子渲染对象
  _MongolRenderEditableCustomPaint? _foregroundRenderObject; // 前景渲染对象
  _MongolRenderEditableCustomPaint? _backgroundRenderObject; // 背景渲染对象

  @override
  /// 释放资源
  void dispose() {
    _foregroundRenderObject?.dispose();
    _foregroundRenderObject = null;
    _backgroundRenderObject?.dispose();
    _backgroundRenderObject = null;
    _clipRectLayer.layer = null;
    _cachedBuiltInForegroundPainters?.dispose();
    _cachedBuiltInPainters?.dispose();
    _selectionStartInViewport.dispose();
    _selectionEndInViewport.dispose();
    _selectionPainter.dispose();
    _caretPainter.dispose();
    _textPainter.dispose();
    super.dispose();
  }

  /// 更新前景 painter
  void _updateForegroundPainter(MongolRenderEditablePainter? newPainter) {
    final effectivePainter = (newPainter == null)
        ? _builtInForegroundPainters
        : _CompositeRenderEditablePainter(
            painters: <MongolRenderEditablePainter>[
              _builtInForegroundPainters,
              newPainter,
            ],
          );

    if (_foregroundRenderObject == null) {
      final foregroundRenderObject =
          _MongolRenderEditableCustomPaint(painter: effectivePainter);
      adoptChild(foregroundRenderObject);
      _foregroundRenderObject = foregroundRenderObject;
    } else {
      _foregroundRenderObject?.painter = effectivePainter;
    }
    _foregroundPainter = newPainter;
  }

  /// 用于在 [MongolRenderEditable] 文本内容上方绘制的 [MongolRenderEditablePainter]
  ///
  /// 新的 [MongolRenderEditablePainter] 将替换先前指定的前景 painter，
  /// 如果新 painter 的 `shouldRepaint` 方法返回 true，则安排重绘
  MongolRenderEditablePainter? get foregroundPainter => _foregroundPainter;
  MongolRenderEditablePainter? _foregroundPainter;

  set foregroundPainter(MongolRenderEditablePainter? newPainter) {
    if (newPainter == _foregroundPainter) return;
    _updateForegroundPainter(newPainter);
  }

  /// 更新背景 painter
  void _updatePainter(MongolRenderEditablePainter? newPainter) {
    final effectivePainter = (newPainter == null)
        ? _builtInPainters
        : _CompositeRenderEditablePainter(
            painters: <MongolRenderEditablePainter>[
              _builtInPainters,
              newPainter,
            ],
          );

    if (_backgroundRenderObject == null) {
      final backgroundRenderObject =
          _MongolRenderEditableCustomPaint(painter: effectivePainter);
      adoptChild(backgroundRenderObject);
      _backgroundRenderObject = backgroundRenderObject;
    } else {
      _backgroundRenderObject?.painter = effectivePainter;
    }
    _painter = newPainter;
  }

  /// 设置用于在此 [MongolRenderEditable] 文本内容下方绘制的 [MongolRenderEditablePainter]
  ///
  /// 新的 [MongolRenderEditablePainter] 将替换先前指定的 painter，
  /// 如果新 painter 的 `shouldRepaint` 方法返回 true，则安排重绘
  MongolRenderEditablePainter? get painter => _painter;
  MongolRenderEditablePainter? _painter;

  set painter(MongolRenderEditablePainter? newPainter) {
    if (newPainter == _painter) return;
    _updatePainter(newPainter);
  }

  // Caret painters:
  late final _CaretPainter _caretPainter = _CaretPainter();

  // Text Highlight painters:
  final _TextHighlightPainter _selectionPainter = _TextHighlightPainter();

  /// 获取内置的前景 painters
  ///
  /// 如果缓存不存在，则创建一个新的组合 painter，包含光标 painter
  _CompositeRenderEditablePainter get _builtInForegroundPainters =>
      _cachedBuiltInForegroundPainters ??= _createBuiltInForegroundPainters();
  _CompositeRenderEditablePainter? _cachedBuiltInForegroundPainters;

  /// 创建内置的前景 painters
  ///
  /// 返回一个包含光标 painter 的组合 painter
  _CompositeRenderEditablePainter _createBuiltInForegroundPainters() {
    return _CompositeRenderEditablePainter(
      painters: <MongolRenderEditablePainter>[
        _caretPainter,
      ],
    );
  }

  /// 获取内置的 painters
  ///
  /// 如果缓存不存在，则创建一个新的组合 painter，包含选择 painter
  _CompositeRenderEditablePainter get _builtInPainters =>
      _cachedBuiltInPainters ??= _createBuiltInPainters();
  _CompositeRenderEditablePainter? _cachedBuiltInPainters;

  /// 创建内置的 painters
  ///
  /// 返回一个包含选择 painter 的组合 painter
  _CompositeRenderEditablePainter _createBuiltInPainters() {
    return _CompositeRenderEditablePainter(
      painters: <MongolRenderEditablePainter>[
        _selectionPainter,
      ],
    );
  }

  double? _textLayoutLastMaxHeight; // 上次布局的最大高度
  double? _textLayoutLastMinHeight; // 上次布局的最小高度

  /// 断言上次布局仍然匹配当前约束
  ///
  /// 检查上次布局的高度约束是否与当前约束一致
  void debugAssertLayoutUpToDate() {
    assert(
      _textLayoutLastMaxHeight == constraints.maxHeight &&
          _textLayoutLastMinHeight == constraints.minHeight,
      'Last height ($_textLayoutLastMinHeight, $_textLayoutLastMaxHeight) not the same as max height constraint (${constraints.minHeight}, ${constraints.maxHeight}).',
    );
  }

  /// [handleEvent] 是否会将指针事件传播到选择处理程序
  ///
  /// 如果此属性为 true，[handleEvent] 假设此渲染器将通过 [handleTapDown]、
  /// [handleTap]、[handleDoubleTap] 和 [handleLongPress] 接收输入手势的通知
  ///
  /// 如果文本跨度中有任何手势识别器，[handleEvent] 仍会将指针事件传播到这些识别器
  ///
  /// 此属性的默认值为 false
  bool ignorePointer;

  /// 当前设备的像素比例
  ///
  /// 应通过查询 MediaQuery 获取 devicePixelRatio
  double get devicePixelRatio => _devicePixelRatio;
  double _devicePixelRatio;

  set devicePixelRatio(double value) {
    if (devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsTextLayout();
  }

  /// 当 [obscureText] 为 true 时用于模糊文本的字符
  ///
  /// 长度必须恰好为 1
  String get obscuringCharacter => _obscuringCharacter;
  String _obscuringCharacter;

  set obscuringCharacter(String value) {
    if (_obscuringCharacter == value) {
      return;
    }
    assert(value.characters.length == 1);
    _obscuringCharacter = value;
    markNeedsLayout();
  }

  /// 是否隐藏正在编辑的文本（例如，用于密码）
  bool get obscureText => _obscureText;
  bool _obscureText;
  set obscureText(bool value) {
    if (_obscureText == value) {
      return;
    }
    _obscureText = value;
    _cachedAttributedValue = null;
    markNeedsSemanticsUpdate();
  }

  /// 控制文本选择的对象，此渲染对象使用它来实现剪切、复制和粘贴键盘快捷键
  ///
  /// 它不能为空。它将使剪切、复制和粘贴功能与最近设置的 [TextSelectionDelegate] 一起工作
  TextSelectionDelegate textSelectionDelegate;

  /// 跟踪选中文本的开始位置是否在视口内
  ///
  /// 例如，如果文本包含 "Hello World"，用户选择 "Hello"，然后滚动以便只显示 "World"，
  /// 则此值将变为 false。如果用户滚动回来，使 "H" 再次可见，则此值将变为 true
  ///
  /// 此布尔值表示文本是否被滚动，使得句柄在文本字段视口内，而不是它是否实际在屏幕上可见
  ValueListenable<bool> get selectionStartInViewport =>
      _selectionStartInViewport;
  final ValueNotifier<bool> _selectionStartInViewport =
      ValueNotifier<bool>(true);

  /// 跟踪选中文本的结束位置是否在视口内
  ///
  /// 例如，如果文本包含 "Hello World"，用户选择 "World"，然后滚动以便只显示 "Hello"，
  /// 则此值将变为 false。如果用户滚动回来，使 "d" 再次可见，则此值将变为 true
  ///
  /// 此布尔值表示文本是否被滚动，使得句柄在文本字段视口内，而不是它是否实际在屏幕上可见
  ValueListenable<bool> get selectionEndInViewport => _selectionEndInViewport;
  final ValueNotifier<bool> _selectionEndInViewport = ValueNotifier<bool>(true);

  /// 更新选择范围的可见性
  ///
  /// 检查选中文本的开始和结束位置是否在视口内
  /// [effectiveOffset] 是文本的有效偏移量
  void _updateSelectionExtentsVisibility(Offset effectiveOffset) {
    assert(selection != null);
    final visibleRegion = Offset.zero & size; // 可见区域

    final startOffset = _textPainter.getOffsetForCaret(
      TextPosition(offset: selection!.start, affinity: selection!.affinity),
      _caretPrototype,
    );
    const visibleRegionSlop = 0.5; // 可见区域的容差
    _selectionStartInViewport.value = visibleRegion
        .inflate(visibleRegionSlop)
        .contains(startOffset + effectiveOffset);

    final endOffset = _textPainter.getOffsetForCaret(
      TextPosition(offset: selection!.end, affinity: selection!.affinity),
      _caretPrototype,
    );
    _selectionEndInViewport.value = visibleRegion
        .inflate(visibleRegionSlop)
        .contains(endOffset + effectiveOffset);
  }

  /// 设置文本编辑值
  ///
  /// [newValue] 是新的文本编辑值
  /// [cause] 是选择更改的原因
  void _setTextEditingValue(
      TextEditingValue newValue, SelectionChangedCause cause) {
    textSelectionDelegate.userUpdateTextEditingValue(newValue, cause);
  }

  /// 设置选择范围
  ///
  /// [nextSelection] 是新的选择范围
  /// [cause] 是选择更改的原因
  ///
  /// 确保选择范围有效，防止索引超出文本长度
  void _setSelection(TextSelection nextSelection, SelectionChangedCause cause) {
    if (nextSelection.isValid) {
      // nextSelection 是基于 plainText 计算的，可能与 textSelectionDelegate.textEditingValue 不同步
      // 这是因为渲染可编辑对象和可编辑文本分别处理指针事件
      // 如果可编辑文本在事件处理程序期间更改了文本，渲染可编辑对象在处理指针事件时会使用存储在 plainText 中的过时文本
      //
      // 如果发生这种情况，我们需要确保新的选择范围仍然有效
      final int textLength = textSelectionDelegate.textEditingValue.text.length;
      nextSelection = nextSelection.copyWith(
        baseOffset: math.min(nextSelection.baseOffset, textLength),
        extentOffset: math.min(nextSelection.extentOffset, textLength),
      );
    }
    _setTextEditingValue(
      textSelectionDelegate.textEditingValue.copyWith(selection: nextSelection),
      cause,
    );
  }

  /// 返回字符串中给定索引之后的下一个字符边界的索引
  ///
  /// 字符边界由 characters 包确定，因此考虑了代理对和扩展字形簇
  ///
  /// 索引必须在 0 和 string.length 之间（包括两者）。如果给定 string.length，则返回 string.length
  ///
  /// 将 includeWhitespace 设置为 false 将只返回非空格字符的索引
  @visibleForTesting
  static int nextCharacter(int index, String string,
      [bool includeWhitespace = true]) {
    assert(index >= 0 && index <= string.length);
    if (index == string.length) {
      return string.length;
    }

    var count = 0;
    final remaining = string.characters.skipWhile((String currentString) {
      if (count <= index) {
        count += currentString.length;
        return true;
      }
      if (includeWhitespace) {
        return false;
      }
      return TextLayoutMetrics.isWhitespace(currentString.codeUnitAt(0));
    });
    return string.length - remaining.toString().length;
  }

  /// 返回字符串中给定索引之前的上一个字符边界的索引
  ///
  /// 字符边界由 characters 包确定，因此考虑了代理对和扩展字形簇
  ///
  /// 索引必须在 0 和 string.length 之间（包括两者）。如果索引为 0，则返回 0
  ///
  /// 将 includeWhitespace 设置为 false 将只返回非空格字符的索引
  @visibleForTesting
  static int previousCharacter(int index, String string,
      [bool includeWhitespace = true]) {
    assert(index >= 0 && index <= string.length);
    if (index == 0) {
      return 0;
    }

    var count = 0;
    int? lastNonWhitespace;
    for (final currentString in string.characters) {
      if (!includeWhitespace &&
          !TextLayoutMetrics.isWhitespace(
              currentString.characters.first.toString().codeUnitAt(0))) {
        lastNonWhitespace = count;
      }
      if (count + currentString.length >= index) {
        return includeWhitespace ? count : lastNonWhitespace ?? 0;
      }
      count += currentString.length;
    }
    return 0;
  }

  /// 返回给定偏移量左侧或右侧的 TextPosition
  ///
  /// [position] 是当前文本位置
  /// [horizontalOffset] 是水平偏移量，正值表示向右，负值表示向左
  TextPosition _getTextPositionHorizontal(
      TextPosition position, double horizontalOffset) {
    final Offset caretOffset =
        _textPainter.getOffsetForCaret(position, _caretPrototype);
    final Offset caretOffsetTranslated =
        caretOffset.translate(horizontalOffset, 0.0);
    return _textPainter.getPositionForOffset(caretOffsetTranslated);
  }

  // 开始 TextLayoutMetrics 实现

  /// 获取包含给定偏移量的行的选择范围
  ///
  /// 如果文本被模糊处理（如密码），则将整个字符串视为一行
  @override
  TextSelection getLineAtOffset(TextPosition position) {
    debugAssertLayoutUpToDate();
    final TextRange line = _textPainter.getLineBoundary(position);
    // 如果文本被模糊处理，整个字符串应被视为一行
    if (obscureText) {
      return TextSelection(baseOffset: 0, extentOffset: plainText.length);
    }
    return TextSelection(baseOffset: line.start, extentOffset: line.end);
  }

  /// 获取包含给定位置的单词的边界
  @override
  TextRange getWordBoundary(TextPosition position) {
    return _textPainter.getWordBoundary(position);
  }

  /// 获取给定位置上方一行的文本位置
  ///
  /// 光标偏移量给出了光标左上角的位置，因此上面一行的中间位置是该点上方半行的位置
  @override
  TextPosition getTextPositionAbove(TextPosition position) {
    // 光标偏移量给出了光标左上角的位置，因此上面一行的中间位置是该点上方半行的位置
    final double preferredLineWidth = _textPainter.preferredLineWidth;
    final double horizontalOffset = -0.5 * preferredLineWidth;
    return _getTextPositionHorizontal(position, horizontalOffset);
  }

  /// 获取给定位置下方一行的文本位置
  ///
  /// 光标偏移量给出了光标左上角的位置，因此下面一行的中间位置是该点下方1.5行的位置
  @override
  TextPosition getTextPositionBelow(TextPosition position) {
    // 光标偏移量给出了光标左上角的位置，因此下面一行的中间位置是该点下方1.5行的位置
    final double preferredLineWidth = _textPainter.preferredLineWidth;
    final double horizontalOffset = 1.5 * preferredLineWidth;
    return _getTextPositionHorizontal(position, horizontalOffset);
  }

  // 结束 TextLayoutMetrics 实现

  @override
  /// 标记渲染对象需要重新绘制
  ///
  /// 同时通知前景和背景渲染对象也需要重新绘制
  void markNeedsPaint() {
    super.markNeedsPaint();
    // 告诉 painters 重新绘制，因为文本布局可能已更改
    _foregroundRenderObject?.markNeedsPaint();
    _backgroundRenderObject?.markNeedsPaint();
  }

  /// 标记渲染对象需要重新布局并重新计算其文本度量
  ///
  /// 隐含调用 [markNeedsLayout]
  @protected
  void markNeedsTextLayout() {
    _textLayoutLastMaxHeight = null;
    _textLayoutLastMinHeight = null;
    markNeedsLayout();
  }

  @override
  /// 系统字体更改时调用
  ///
  /// 重新标记文本布局为需要更新
  void systemFontsDidChange() {
    super.systemFontsDidChange();
    _textPainter.markNeedsLayout();
    _textLayoutLastMaxHeight = null;
    _textLayoutLastMinHeight = null;
  }

  /// 返回 [TextPainter] 中文本的纯文本版本
  ///
  /// 如果 [obscureText] 为 true，则返回模糊处理的文本。参见 [obscureText] 和 [obscuringCharacter]
  /// 要获取作为 [TextSpan] 树的带样式文本，请使用 [text]
  String get plainText => _textPainter.plainText;

  /// 要绘制的文本，以 [TextSpan] 树的形式
  ///
  /// 要获取纯文本表示，请使用 [plainText]
  TextSpan? get text => _textPainter.text;
  final MongolTextPainter _textPainter; // 文本绘制器
  AttributedString? _cachedAttributedValue; // 缓存的属性字符串
  List<InlineSpanSemanticsInformation>? _cachedCombinedSemanticsInfos; // 缓存的组合语义信息
  set text(TextSpan? value) {
    if (_textPainter.text == value) {
      return;
    }
    _cachedLineBreakCount = null;
    _textPainter.text = value;
    _cachedAttributedValue = null;
    _cachedCombinedSemanticsInfos = null;
    markNeedsTextLayout();
    markNeedsSemanticsUpdate();
  }

  /// 文本应该如何垂直对齐
  ///
  /// 这不能为空
  MongolTextAlign get textAlign => _textPainter.textAlign;

  set textAlign(MongolTextAlign value) {
    if (_textPainter.textAlign == value) return;
    _textPainter.textAlign = value;
    markNeedsTextLayout();
  }

  /// 绘制光标时使用的颜色
  Color? get cursorColor => _caretPainter.caretColor;

  set cursorColor(Color? value) {
    _caretPainter.caretColor = value;
  }

  /// 是否绘制光标
  ValueNotifier<bool> get showCursor => _showCursor;
  ValueNotifier<bool> _showCursor;

  set showCursor(ValueNotifier<bool> value) {
    if (_showCursor == value) return;
    if (attached) _showCursor.removeListener(_showHideCursor);
    _showCursor = value;
    if (attached) {
      _showHideCursor();
      _showCursor.addListener(_showHideCursor);
    }
  }

  /// 显示或隐藏光标
  void _showHideCursor() {
    _caretPainter.shouldPaint = showCursor.value;
  }

  /// 可编辑对象当前是否获得焦点
  bool get hasFocus => _hasFocus;
  bool _hasFocus = false;

  // bool _listenerAttached = false;
  set hasFocus(bool value) {
    if (_hasFocus == value) return;
    _hasFocus = value;
    markNeedsSemanticsUpdate();
  }

  /// 此渲染对象是否会占据一整行，无论文本高度如何
  bool get forceLine => _forceLine;
  bool _forceLine = false;

  set forceLine(bool value) {
    if (_forceLine == value) return;
    _forceLine = value;
    markNeedsLayout();
  }

  /// 此渲染对象是否为只读
  bool get readOnly => _readOnly;
  bool _readOnly = false;

  set readOnly(bool value) {
    if (_readOnly == value) return;
    _readOnly = value;
    markNeedsSemanticsUpdate();
  }

  /// 文本可以跨越的最大行数，必要时会换行
  ///
  /// 如果为 1（默认值），文本不会换行，而是会无限延伸
  ///
  /// 如果为 null，则对行数没有限制
  ///
  /// 当不为 null 时，渲染对象的内在宽度是一行文本的宽度乘以该值
  /// 换句话说，这也控制了实际编辑小部件的宽度
  int? get maxLines => _maxLines;
  int? _maxLines;

  /// 值可以为 null。如果不为 null，则必须大于零
  set maxLines(int? value) {
    assert(value == null || value > 0);
    if (maxLines == value) {
      return;
    }
    _maxLines = value;

    // 特殊处理 maxLines == 1 的情况，只保留第一行，以便在文本中有硬换行时获取第一行的宽度
    // 参见 `_preferredWidth` 方法
    _textPainter.maxLines = value == 1 ? 1 : null;
    markNeedsTextLayout();
  }

  /// 当内容跨越较少行时要占据的最小行数
  ///
  /// 如果为 null（默认值），文本容器开始时具有足够的水平空间
  /// 用于一行，并随着输入的增加而增长以容纳更多行
  ///
  /// 这可以与 [maxLines] 结合使用，以实现各种不同的行为
  ///
  /// 如果设置了值，它必须大于零。如果值大于 1，[maxLines] 也应该
  /// 设置为 null 或大于此值
  ///
  /// 当同时设置 [maxLines] 时，宽度将在指定的行数范围内增长
  /// 当 [maxLines] 为 null 时，它将根据需要增长，从 [minLines] 开始
  ///
  /// 以下是 [minLines] 和 [maxLines] 可能实现的一些行为示例
  /// 这些同样适用于 `MongolTextField`、`MongolTextFormField` 和 `MongolEditableText`
  ///
  /// 始终至少占据 2 行且最大行数无限的输入
  /// 根据需要水平扩展
  /// ```dart
  /// MongolTextField(minLines: 2)
  /// ```
  ///
  /// 宽度从 2 行开始，最多增长到 4 行，此时达到宽度限制
  /// 如果输入更多行，它将水平滚动
  /// ```dart
  /// TextField(minLines:2, maxLines: 4)
  /// ```
  ///
  /// 有关 [maxLines] 和 [minLines] 如何相互作用以产生各种行为的完整情况，
  /// 请参见 [maxLines] 中的示例
  ///
  /// 默认值为 null
  int? get minLines => _minLines;
  int? _minLines;

  /// 值可以为 null。如果不为 null，则必须大于零
  set minLines(int? value) {
    assert(value == null || value > 0);
    if (minLines == value) return;
    _minLines = value;
    markNeedsTextLayout();
  }

  /// 此小部件的宽度是否会调整为填充其父级
  ///
  /// 如果设置为 true 并包装在像 [Expanded] 或 [SizedBox] 这样的父小部件中，
  /// 输入将扩展以填充父级
  ///
  /// 当设置为 true 时，[maxLines] 和 [minLines] 都必须为 null，
  /// 否则会抛出错误
  ///
  /// 默认值为 false
  ///
  /// 有关 [maxLines]、[minLines] 和 [expands] 如何相互作用以产生各种行为的完整情况，
  /// 请参见 [maxLines] 中的示例
  ///
  /// 与父级宽度匹配的输入：
  /// ```dart
  /// Expanded(
  ///   child: TextField(maxLines: null, expands: true),
  /// )
  /// ```
  bool get expands => _expands;
  bool _expands;
  set expands(bool value) {
    if (expands == value) {
      return;
    }
    _expands = value;
    markNeedsTextLayout();
  }

  /// 绘制选择时使用的颜色
  Color? get selectionColor => _selectionPainter.highlightColor;

  set selectionColor(Color? value) {
    _selectionPainter.highlightColor = value;
  }

  /// 每个逻辑像素的字体像素数
  ///
  /// 例如，如果文本比例因子为 1.5，文本将比指定的字体大小大 50%
  double get textScaleFactor => _textPainter.textScaleFactor;

  set textScaleFactor(double value) {
    if (_textPainter.textScaleFactor == value) return;
    _textPainter.textScaleFactor = value;
    markNeedsTextLayout();
  }

  /// 选定的文本区域（如果有）
  ///
  /// 光标位置由折叠的选择表示
  ///
  /// 如果 [selection] 为 null，则没有选择，尝试
  /// 操作选择将抛出异常
  TextSelection? get selection => _selection;
  TextSelection? _selection;

  set selection(TextSelection? value) {
    if (_selection == value) return;
    _selection = value;
    _selectionPainter.highlightedRange = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  /// 文本应该绘制的偏移量
  ///
  /// 如果文本内容大于可编辑行本身，可编辑
  /// 行将裁剪文本。此属性通过在裁剪前将文本移动给定的偏移量来控制文本的可见部分
  ViewportOffset get offset => _offset;
  ViewportOffset _offset;

  set offset(ViewportOffset value) {
    if (_offset == value) return;
    if (attached) _offset.removeListener(markNeedsPaint);
    _offset = value;
    if (attached) _offset.addListener(markNeedsPaint);
    markNeedsLayout();
  }

  /// 光标会有多宽
  ///
  /// 这可以为 null，在这种情况下，getter 实际上会返回 [preferredLineWidth]
  ///
  /// 将其设置为自身会将值固定为当前的 [preferredLineWidth]。设置
  /// 为 null 会返回延迟到 [preferredLineWidth] 的行为
  double get cursorWidth => _cursorWidth ?? preferredLineWidth;
  double? _cursorWidth;

  set cursorWidth(double? value) {
    if (_cursorWidth == value) return;
    _cursorWidth = value;
    markNeedsLayout();
  }

  /// 光标会有多厚
  ///
  /// 光标将绘制在文本上方。光标高度将延伸
  /// 到字符边界之间。这对应于相对于所选位置向下游延伸
  /// 可以使用负值来反转此行为
  double get cursorHeight => _cursorHeight;
  double _cursorHeight = 1.0;

  set cursorHeight(double value) {
    if (_cursorHeight == value) {
      return;
    }
    _cursorHeight = value;
    markNeedsLayout();
  }

  /// 在屏幕上绘制光标时使用的偏移量（以像素为单位）
  ///
  /// 默认情况下，在 iOS 平台上，光标位置应设置为 (0.0, -[cursorHeight] * 0.5) 的偏移量，
  /// 在 Android 平台上设置为 (0, 0)。应用偏移量的原点是默认情况下光标最终被渲染的任意位置
  Offset get cursorOffset => _caretPainter.cursorOffset;

  set cursorOffset(Offset value) {
    _caretPainter.cursorOffset = value;
  }

  /// 光标的角应该有多圆
  ///
  /// null 值与 [Radius.zero] 相同
  Radius? get cursorRadius => _caretPainter.cursorRadius;

  set cursorRadius(Radius? value) {
    _caretPainter.cursorRadius = value;
  }

  /// 开始选择句柄的 [LayerLink]
  ///
  /// [MongolRenderEditable] 负责计算此 [LayerLink] 的 [Offset]，
  /// 该偏移量将用作开始句柄的 [CompositedTransformTarget]
  LayerLink get startHandleLayerLink => _startHandleLayerLink;
  LayerLink _startHandleLayerLink;

  set startHandleLayerLink(LayerLink value) {
    if (_startHandleLayerLink == value) return;
    _startHandleLayerLink = value;
    markNeedsPaint();
  }

  /// 结束选择句柄的 [LayerLink]
  ///
  /// [MongolRenderEditable] 负责计算此 [LayerLink] 的 [Offset]，
  /// 该偏移量将用作结束句柄的 [CompositedTransformTarget]
  LayerLink get endHandleLayerLink => _endHandleLayerLink;
  LayerLink _endHandleLayerLink;

  set endHandleLayerLink(LayerLink value) {
    if (_endHandleLayerLink == value) return;
    _endHandleLayerLink = value;
    markNeedsPaint();
  }

  /// 是否允许用户更改选择
  ///
  /// 由于 [MongolRenderEditable] 本身不处理选择操作，
  /// 这实际上只影响提供给系统的辅助功能提示（通过
  /// [describeSemanticsConfiguration]）是否会启用选择操作
  /// 提供选择操作功能是此对象所有者的责任
  ///
  /// 此字段由 [selectionEnabled] 使用（然后控制上述辅助功能提示）
  /// 当为 null 时，[obscureText] 用于确定 [selectionEnabled] 的值
  bool? get enableInteractiveSelection => _enableInteractiveSelection;
  bool? _enableInteractiveSelection;

  set enableInteractiveSelection(bool? value) {
    if (_enableInteractiveSelection == value) return;
    _enableInteractiveSelection = value;
    markNeedsTextLayout();
    markNeedsSemanticsUpdate();
  }

  /// 是否基于 [enableInteractiveSelection] 和 [obscureText] 的值启用交互式选择
  ///
  /// 由于 [MongolRenderEditable] 本身不处理选择操作，
  /// 这实际上只影响提供给系统的辅助功能提示（通过
  /// [describeSemanticsConfiguration]）是否会启用选择操作
  /// 提供选择操作功能是此对象所有者的责任
  ///
  /// 默认情况下，[enableInteractiveSelection] 为 null，[obscureText] 为 false，
  /// 此 getter 返回 true
  ///
  /// 如果 [enableInteractiveSelection] 为 null 且 [obscureText] 为 true，
  /// 则此 getter 返回 false。这是密码字段的常见情况
  ///
  /// 如果 [enableInteractiveSelection] 非 null，则返回其值
  /// 应用程序可能会将 [enableInteractiveSelection] 设置为 true 以启用密码字段的交互式选择，
  /// 或设置为 false 以无条件禁用交互式选择
  bool get selectionEnabled {
    return enableInteractiveSelection ?? !obscureText;
  }

  /// 文本允许滚动的最大量
  ///
  /// 此值仅在布局后有效，并且可以随着文本的添加或删除而更改，
  /// 以便在 [expands] 设置为 true 时适应扩展
  double get maxScrollExtent => _maxScrollExtent;
  double _maxScrollExtent = 0;

  /// 光标边距
  double get _caretMargin => _kCaretGap + cursorHeight;

  /// 裁剪行为，默认为 [Clip.hardEdge]，不能为空
  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior = Clip.hardEdge;

  set clipBehavior(Clip value) {
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  /// 在 [describeSemanticsConfiguration] 期间收集，由 [assembleSemanticsNode] 和 [_combineSemanticsInfo] 使用
  List<InlineSpanSemanticsInformation>? _semanticsInfo;

  // 缓存在 [assembleSemanticsNode] 期间创建的 [SemanticsNode]，以便在再次调用 [assembleSemanticsNode] 时重用
  // 这确保了 [TextSpan] 的 [SemanticsNode] 在 [assembleSemanticsNode] 调用之间具有稳定的 ID
  LinkedHashMap<Key, SemanticsNode>? _cachedChildNodes;

  /// 返回限定给定选择范围的矩形列表
  ///
  /// 有关更多详细信息，请参见 [MongolTextPainter.getBoxesForSelection]
  List<Rect> getBoxesForSelection(TextSelection selection) {
    _computeTextMetricsIfNeeded();
    return _textPainter
        .getBoxesForSelection(selection)
        .map((rect) => rect.shift(_paintOffset))
        .toList();
  }

  @override
  /// 描述此渲染对象的语义配置
  ///
  /// 为辅助功能系统提供关于此对象的信息
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    _semanticsInfo = _textPainter.text!.getSemanticsInformation();
    if (_semanticsInfo!.any(
            (InlineSpanSemanticsInformation info) => info.recognizer != null) &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      assert(readOnly && !obscureText);
      // 对于带有识别器的可选择富文本，我们需要为每个文本片段创建一个语义节点
      config
        ..isSemanticBoundary = true
        ..explicitChildNodes = true;
      return;
    }
    if (_cachedAttributedValue == null) {
      if (obscureText) {
        _cachedAttributedValue =
            AttributedString(obscuringCharacter * plainText.length);
      } else {
        final StringBuffer buffer = StringBuffer();
        int offset = 0;
        final List<StringAttribute> attributes = <StringAttribute>[];
        for (final InlineSpanSemanticsInformation info in _semanticsInfo!) {
          final String label = info.semanticsLabel ?? info.text;
          for (final StringAttribute infoAttribute in info.stringAttributes) {
            final TextRange originalRange = infoAttribute.range;
            attributes.add(
              infoAttribute.copy(
                range: TextRange(
                    start: offset + originalRange.start,
                    end: offset + originalRange.end),
              ),
            );
          }
          buffer.write(label);
          offset += label.length;
        }
        _cachedAttributedValue =
            AttributedString(buffer.toString(), attributes: attributes);
      }
    }
    config
      ..attributedValue = _cachedAttributedValue!
      ..isObscured = obscureText
      ..isMultiline = _isMultiline
      ..textDirection = TextDirection.ltr
      ..isFocused = hasFocus
      ..isTextField = true
      ..isReadOnly = readOnly;

    if (hasFocus && selectionEnabled) {
      config.onSetSelection = _handleSetSelection;
    }

    if (hasFocus && !readOnly) {
      config.onSetText = _handleSetText;
    }

    if (selectionEnabled && (selection?.isValid ?? false)) {
      config.textSelection = selection;
      if (_textPainter.getOffsetBefore(selection!.extentOffset) != null) {
        config
          ..onMoveCursorBackwardByWord = _handleMoveCursorBackwardByWord
          ..onMoveCursorBackwardByCharacter =
              _handleMoveCursorBackwardByCharacter;
      }
      if (_textPainter.getOffsetAfter(selection!.extentOffset) != null) {
        config
          ..onMoveCursorForwardByWord = _handleMoveCursorForwardByWord
          ..onMoveCursorForwardByCharacter =
              _handleMoveCursorForwardByCharacter;
      }
    }
  }

  /// 处理设置文本的操作
  ///
  /// [text] 是要设置的新文本
  void _handleSetText(String text) {
    textSelectionDelegate.userUpdateTextEditingValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
      SelectionChangedCause.keyboard,
    );
  }

  @override
  /// 组装语义节点
  ///
  /// 为文本的每个片段创建语义节点，以便辅助功能系统能够识别和交互
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config,
      Iterable<SemanticsNode> children) {
    assert(_semanticsInfo != null && _semanticsInfo!.isNotEmpty);
    final newChildren = <SemanticsNode>[];
    Rect currentRect;
    var ordinal = 0.0;
    var start = 0;
    final LinkedHashMap<Key, SemanticsNode> newChildCache =
        LinkedHashMap<Key, SemanticsNode>();
    _cachedCombinedSemanticsInfos ??= combineSemanticsInfo(_semanticsInfo!);
    for (final info in _cachedCombinedSemanticsInfos!) {
      final TextSelection selection = TextSelection(
        baseOffset: start,
        extentOffset: start + info.text.length,
      );
      start += info.text.length;

      final rects = _textPainter.getBoxesForSelection(selection);
      if (rects.isEmpty) {
        continue;
      }
      var rect = rects.first;
      for (final textBox in rects.skip(1)) {
        rect = rect.expandToInclude(textBox);
      }
      // Any of the text boxes may have had infinite dimensions.
      // We shouldn't pass infinite dimensions up to the bridges.
      rect = Rect.fromLTWH(
        math.max(0.0, rect.left),
        math.max(0.0, rect.top),
        math.min(rect.width, constraints.maxWidth),
        math.min(rect.height, constraints.maxHeight),
      );
      // Round the current rectangle to make this API testable and add some
      // padding so that the accessibility rects do not overlap with the text.
      currentRect = Rect.fromLTRB(
        rect.left.floorToDouble() - 4.0,
        rect.top.floorToDouble() - 4.0,
        rect.right.ceilToDouble() + 4.0,
        rect.bottom.ceilToDouble() + 4.0,
      );
      final configuration = SemanticsConfiguration()
        ..sortKey = OrdinalSortKey(ordinal++)
        ..textDirection = TextDirection.ltr
        ..attributedLabel = AttributedString(info.semanticsLabel ?? info.text,
            attributes: info.stringAttributes);
      final GestureRecognizer? recognizer = info.recognizer;
      if (recognizer != null) {
        if (recognizer is TapGestureRecognizer) {
          if (recognizer.onTap != null) {
            configuration.onTap = recognizer.onTap;
            configuration.isLink = true;
          }
        } else if (recognizer is DoubleTapGestureRecognizer) {
          if (recognizer.onDoubleTap != null) {
            configuration.onTap = recognizer.onDoubleTap;
            configuration.isLink = true;
          }
        } else if (recognizer is LongPressGestureRecognizer) {
          if (recognizer.onLongPress != null) {
            configuration.onLongPress = recognizer.onLongPress;
          }
        } else {
          assert(false, '${recognizer.runtimeType} is not supported.');
        }
      }
      if (node.parentPaintClipRect != null) {
        final Rect paintRect = node.parentPaintClipRect!.intersect(currentRect);
        configuration.isHidden = paintRect.isEmpty && !currentRect.isEmpty;
      }
      late final SemanticsNode newChild;
      if (_cachedChildNodes?.isNotEmpty ?? false) {
        newChild = _cachedChildNodes!.remove(_cachedChildNodes!.keys.first)!;
      } else {
        final UniqueKey key = UniqueKey();
        newChild = SemanticsNode(
          key: key,
          showOnScreen: _createShowOnScreenFor(key),
        );
      }
      newChild
        ..updateWith(config: configuration)
        ..rect = currentRect;
      newChildCache[newChild.key!] = newChild;
      newChildren.add(newChild);
    }
    _cachedChildNodes = newChildCache;
    node.updateWith(config: config, childrenInInversePaintOrder: newChildren);
  }

  /// 创建一个显示屏幕的回调函数
  ///
  /// [key] 是语义节点的键
  /// 返回一个回调函数，当调用时会将指定的语义节点显示在屏幕上
  VoidCallback? _createShowOnScreenFor(Key key) {
    return () {
      final SemanticsNode node = _cachedChildNodes![key]!;
      showOnScreen(descendant: this, rect: node.rect);
    };
  }

  /// 处理设置选择范围的操作
  ///
  /// [selection] 是新的选择范围
  void _handleSetSelection(TextSelection selection) {
    _setSelection(selection, SelectionChangedCause.keyboard);
  }

  /// 处理向前移动光标一个字符的操作
  ///
  /// [extendSelection] 表示是否扩展选择范围
  void _handleMoveCursorForwardByCharacter(bool extendSelection) {
    assert(selection != null);
    final extentOffset = _textPainter.getOffsetAfter(selection!.extentOffset);
    if (extentOffset == null) {
      return;
    }
    final baseOffset = !extendSelection ? extentOffset : selection!.baseOffset;
    _setSelection(
      TextSelection(baseOffset: baseOffset, extentOffset: extentOffset),
      SelectionChangedCause.keyboard,
    );
  }

  /// 处理向后移动光标一个字符的操作
  ///
  /// [extendSelection] 表示是否扩展选择范围
  void _handleMoveCursorBackwardByCharacter(bool extendSelection) {
    assert(selection != null);
    final extentOffset = _textPainter.getOffsetBefore(selection!.extentOffset);
    if (extentOffset == null) {
      return;
    }
    final baseOffset = !extendSelection ? extentOffset : selection!.baseOffset;
    _setSelection(
      TextSelection(baseOffset: baseOffset, extentOffset: extentOffset),
      SelectionChangedCause.keyboard,
    );
  }

  /// 处理向前移动光标一个单词的操作
  ///
  /// [extendSelection] 表示是否扩展选择范围
  void _handleMoveCursorForwardByWord(bool extendSelection) {
    assert(selection != null);
    final currentWord = _textPainter.getWordBoundary(selection!.extent);
    final nextWord = _getNextWord(currentWord.end);
    if (nextWord == null) {
      return;
    }
    final baseOffset = extendSelection ? selection!.baseOffset : nextWord.start;
    _setSelection(
      TextSelection(
        baseOffset: baseOffset,
        extentOffset: nextWord.start,
      ),
      SelectionChangedCause.keyboard,
    );
  }

  /// 处理向后移动光标一个单词的操作
  ///
  /// [extendSelection] 表示是否扩展选择范围
  void _handleMoveCursorBackwardByWord(bool extendSelection) {
    assert(selection != null);
    final currentWord = _textPainter.getWordBoundary(selection!.extent);
    final previousWord = _getPreviousWord(currentWord.start - 1);
    if (previousWord == null) {
      return;
    }
    final baseOffset =
        extendSelection ? selection!.baseOffset : previousWord.start;
    _setSelection(
      TextSelection(
        baseOffset: baseOffset,
        extentOffset: previousWord.start,
      ),
      SelectionChangedCause.keyboard,
    );
  }

  /// 获取下一个单词的文本范围
  ///
  /// [offset] 是起始偏移量
  /// 跳过空白字符，返回下一个非空白单词的范围
  TextRange? _getNextWord(int offset) {
    while (true) {
      final range = _textPainter.getWordBoundary(TextPosition(offset: offset));
      if (!range.isValid || range.isCollapsed) return null;
      if (!_onlyWhitespace(range)) return range;
      offset = range.end;
    }
  }

  /// 获取上一个单词的文本范围
  ///
  /// [offset] 是起始偏移量
  /// 向前搜索，跳过空白字符，返回上一个非空白单词的范围
  TextRange? _getPreviousWord(int offset) {
    while (offset >= 0) {
      final range = _textPainter.getWordBoundary(TextPosition(offset: offset));
      if (!range.isValid || range.isCollapsed) return null;
      if (!_onlyWhitespace(range)) return range;
      offset = range.start - 1;
    }
    return null;
  }

  /// 检查给定的文本范围是否只包含空白字符或分隔符
  ///
  /// 包括 ASCII 中的换行符和 [unicode 分隔符类别](https://www.compart.com/en/unicode/category/Zs) 中的分隔符
  bool _onlyWhitespace(TextRange range) {
    for (var i = range.start; i < range.end; i++) {
      final codeUnit = text!.codeUnitAt(i)!;
      if (!TextLayoutMetrics.isWhitespace(codeUnit)) {
        return false;
      }
    }
    return true;
  }

  @override
  /// 附加到管道所有者
  ///
  /// 当渲染对象被添加到渲染树时调用
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _foregroundRenderObject?.attach(owner);
    _backgroundRenderObject?.attach(owner);

    _tap = TapGestureRecognizer(debugOwner: this)
      ..onTapDown = _handleTapDown
      ..onTap = _handleTap;
    _longPress = LongPressGestureRecognizer(debugOwner: this)
      ..onLongPress = _handleLongPress;
    _offset.addListener(markNeedsPaint);
    _showHideCursor();
    _showCursor.addListener(_showHideCursor);
    // assert(!_listenerAttached);
    // if (_hasFocus) {
    //   RawKeyboard.instance.addListener(_handleKeyEvent);
    //   _listenerAttached = true;
    // }
  }

  @override
  /// 从管道所有者分离
  ///
  /// 当渲染对象从渲染树中移除时调用
  void detach() {
    _tap.dispose();
    _longPress.dispose();
    _offset.removeListener(markNeedsPaint);
    _showCursor.removeListener(_showHideCursor);
    super.detach();
    _foregroundRenderObject?.detach();
    _backgroundRenderObject?.detach();
  }

  @override
  /// 重新深度排序子节点
  ///
  /// 当子节点的深度需要更新时调用
  void redepthChildren() {
    final RenderObject? foregroundChild = _foregroundRenderObject;
    final RenderObject? backgroundChild = _backgroundRenderObject;
    if (foregroundChild != null) redepthChild(foregroundChild);
    if (backgroundChild != null) redepthChild(backgroundChild);
  }

  @override
  /// 访问所有子渲染对象
  ///
  /// 用于遍历和处理此渲染对象的所有子节点
  void visitChildren(RenderObjectVisitor visitor) {
    final RenderObject? foregroundChild = _foregroundRenderObject;
    final RenderObject? backgroundChild = _backgroundRenderObject;
    if (foregroundChild != null) visitor(foregroundChild);
    if (backgroundChild != null) visitor(backgroundChild);
  }

  /// 是否为多行文本
  bool get _isMultiline => maxLines != 1;

  /// 视口轴方向
  ///
  /// 多行时为水平轴，单行时为垂直轴
  Axis get _viewportAxis => _isMultiline ? Axis.horizontal : Axis.vertical;

  /// 绘制偏移量
  ///
  /// 根据视口轴方向计算文本的绘制位置
  Offset get _paintOffset {
    switch (_viewportAxis) {
      case Axis.horizontal:
        return Offset(-offset.pixels, 0.0);
      case Axis.vertical:
        return Offset(0.0, -offset.pixels);
    }
  }

  /// 视口范围
  ///
  /// 根据视口轴方向返回视口的宽度或高度
  double get _viewportExtent {
    assert(hasSize);
    switch (_viewportAxis) {
      case Axis.horizontal:
        return size.width;
      case Axis.vertical:
        return size.height;
    }
  }

  /// 获取最大滚动范围
  ///
  /// [contentSize] 是内容的大小
  /// 根据视口轴方向计算最大滚动距离
  double _getMaxScrollExtent(Size contentSize) {
    assert(hasSize);
    switch (_viewportAxis) {
      case Axis.horizontal:
        return math.max(0.0, contentSize.width - size.width);
      case Axis.vertical:
        return math.max(0.0, contentSize.height - size.height);
    }
  }

  /// 是否有视觉溢出
  ///
  /// 我们需要在这里检查绘制偏移量，因为在动画期间，即使文本适合，文本的开始部分也可能位于可见区域之外
  bool get _hasVisualOverflow =>
      _maxScrollExtent > 0 || _paintOffset != Offset.zero;

  /// 返回给定选择范围端点的本地坐标
  ///
  /// 如果选择是折叠的（因此占据单个点），返回的列表长度为一
  /// 否则，选择未折叠，返回的列表长度为二
  ///
  /// 另请参见：
  ///
  ///  * [getLocalRectForCaret]，它是等效的，但用于 [TextPosition] 而不是 [TextSelection]
  List<TextSelectionPoint> getEndpointsForSelection(TextSelection selection) {
    _computeTextMetricsIfNeeded();

    final paintOffset = _paintOffset;

    final boxes = selection.isCollapsed
        ? <Rect>[]
        : _textPainter.getBoxesForSelection(selection);
    if (boxes.isEmpty) {
      final caretOffset =
          _textPainter.getOffsetForCaret(selection.extent, _caretPrototype);
      final start = Offset(preferredLineWidth, 0.0) + caretOffset + paintOffset;
      return <TextSelectionPoint>[TextSelectionPoint(start, TextDirection.ltr)];
    } else {
      final start = Offset(boxes.first.left, boxes.first.top) + paintOffset;
      final end = Offset(boxes.last.right, boxes.last.bottom) + paintOffset;
      return <TextSelectionPoint>[
        TextSelectionPoint(start, TextDirection.ltr),
        TextSelectionPoint(end, TextDirection.ltr),
      ];
    }
  }

  /// Returns the smallest [Rect], in the local coordinate system, that covers
  /// the text within the [TextRange] specified.
  ///
  /// This method is used to calculate the approximate position of the IME bar
  /// on iOS.
  ///
  /// Returns null if [TextRange.isValid] is false for the given `range`, or the
  /// given `range` is collapsed.
  Rect? getRectForComposingRange(TextRange range) {
    if (!range.isValid || range.isCollapsed) {
      return null;
    }
    _computeTextMetricsIfNeeded();

    final boxes = _textPainter.getBoxesForSelection(
      TextSelection(baseOffset: range.start, extentOffset: range.end),
    );

    return boxes
        .fold(
          null,
          (Rect? accum, Rect incoming) =>
              accum?.expandToInclude(incoming) ?? incoming,
        )
        ?.shift(_paintOffset);
  }

  /// Returns the position in the text for the given global coordinate.
  ///
  /// See also:
  ///
  ///  * [getLocalRectForCaret], which is the reverse operation, taking
  ///    a [TextPosition] and returning a [Rect].
  ///  * [MongolTextPainter.getPositionForOffset], which is the equivalent method
  ///    for a [MongolTextPainter] object.
  TextPosition getPositionForPoint(Offset globalPosition) {
    _computeTextMetricsIfNeeded();
    globalPosition += -_paintOffset;
    return _textPainter.getPositionForOffset(globalToLocal(globalPosition));
  }

  /// Returns the [Rect] in local coordinates for the caret at the given text
  /// position.
  ///
  /// See also:
  ///
  ///  * [getPositionForPoint], which is the reverse operation, taking
  ///    an [Offset] in global coordinates and returning a [TextPosition].
  ///  * [getEndpointsForSelection], which is the equivalent but for
  ///    a selection rather than a particular text position.
  ///  * [MongolTextPainter.getOffsetForCaret], the equivalent method for a
  ///    [MongolTextPainter] object.
  Rect getLocalRectForCaret(TextPosition caretPosition) {
    _computeTextMetricsIfNeeded();
    final caretOffset =
        _textPainter.getOffsetForCaret(caretPosition, _caretPrototype);
    // This rect is the same as _caretPrototype but without the horizontal padding.
    final rect = Rect.fromLTWH(0.0, 0.0, cursorWidth, cursorHeight)
        .shift(caretOffset + _paintOffset + cursorOffset);
    // Add additional cursor offset (generally only if on iOS).
    return rect.shift(_snapToPhysicalPixel(rect.topLeft));
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _layoutText(maxHeight: double.infinity);
    return _textPainter.minIntrinsicHeight;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    _layoutText(maxHeight: double.infinity);
    return _textPainter.maxIntrinsicHeight + cursorHeight;
  }

  /// An estimate of the width of a line in the text. See [TextPainter.preferredLineWidth].
  /// This does not require the layout to be updated.
  double get preferredLineWidth => _textPainter.preferredLineWidth;

  int? _cachedLineBreakCount;
  int _countHardLineBreaks(String text) {
    final int? cachedValue = _cachedLineBreakCount;
    if (cachedValue != null) {
      return cachedValue;
    }
    int count = 0;
    for (int index = 0; index < text.length; index += 1) {
      switch (text.codeUnitAt(index)) {
        case 0x000A: // LF
        case 0x0085: // NEL
        case 0x000B: // VT
        case 0x000C: // FF, treating it as a regular line separator
        case 0x2028: // LS
        case 0x2029: // PS
          count += 1;
      }
    }
    return _cachedLineBreakCount = count;
  }

  /// 计算首选宽度
  ///
  /// [height] 是可用高度
  /// 根据文本内容、最大行数和最小行数计算控件的首选宽度
  double _preferredWidth(double height) {
    final String plain = plainText;

    // 空段落必须保留一列
    if (plain.isEmpty) {
      return preferredLineWidth;
    }

    final int? maxLines = this.maxLines;
    final int? minLines = this.minLines ?? maxLines;
    final double minWidth = preferredLineWidth * (minLines ?? 0);

    if (maxLines == null) {
      final double estimatedWidth;
      if (height == double.infinity) {
        estimatedWidth =
            preferredLineWidth * (_countHardLineBreaks(plainText) + 1);
      } else {
        _layoutText(maxHeight: height);
        estimatedWidth = _textPainter.width;
      }
      return math.max(estimatedWidth, minWidth);
    }

    final bool usePreferredLineHeightHack =
        maxLines == 1 && text?.codeUnitAt(0) == null;

    // 特殊处理 maxLines == 1 的情况，因为它强制滚动方向为水平
    // 报告实际高度以防止文本被裁剪
    if (maxLines == 1 && !usePreferredLineHeightHack) {
      // 当 maxLines == 1 时，_layoutText 调用使用无限高度布局段落
      // 此外，_textPainter.maxLines 将被设置为 1，因此如果有任何换行符，只会显示第一行
      assert(_textPainter.maxLines == 1);
      _layoutText(maxHeight: height);
      return _textPainter.width;
    }
    if (minLines == maxLines) {
      return minWidth;
    }
    _layoutText(maxHeight: height);
    final double maxWidth = preferredLineWidth * maxLines;
    return clampDouble(_textPainter.width, minWidth, maxWidth);
  }

  @override
  /// 计算最小内在宽度
  ///
  /// [height] 是可用高度
  /// 返回控件的最小内在宽度
  double computeMinIntrinsicWidth(double height) {
    return _preferredWidth(height);
  }

  @override
  /// 计算最大内在宽度
  ///
  /// [height] 是可用高度
  /// 返回控件的最大内在宽度
  double computeMaxIntrinsicWidth(double height) {
    return _preferredWidth(height);
  }

  @override
  /// 计算到实际基线的距离
  ///
  /// [baseline] 是基线类型
  /// 返回到指定基线的距离
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    _computeTextMetricsIfNeeded();
    return _textPainter.computeDistanceToActualBaseline(baseline);
  }

  @override
  /// 测试点是否命中此渲染对象
  ///
  /// 始终返回 true，表示此渲染对象会响应所有点击事件
  bool hitTestSelf(Offset position) => true;

  late TapGestureRecognizer _tap;
  late LongPressGestureRecognizer _longPress;

  @override
  /// 处理指针事件
  ///
  /// [event] 是指针事件
  /// [entry] 是命中测试条目
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    if (event is PointerDownEvent) {
      assert(!debugNeedsLayout);

      if (!ignorePointer) {
        // 将指针事件传播到选择处理程序
        _tap.addPointer(event);
        _longPress.addPointer(event);
      }
    }
  }

  Offset? _lastTapDownPosition;
  Offset? _lastSecondaryTapDownPosition;

  /// 最近在此文本输入上发生的辅助点击事件的位置
  Offset? get lastSecondaryTapDownPosition => _lastSecondaryTapDownPosition;

  /// 跟踪辅助点击事件的位置
  ///
  /// 在尝试基于辅助点击的位置更改选择之前应该调用此方法
  void handleSecondaryTapDown(TapDownDetails details) {
    _lastTapDownPosition = details.globalPosition;
    _lastSecondaryTapDownPosition = details.globalPosition;
  }

  /// 如果 [ignorePointer] 为 false（默认值），则此方法由内部手势识别器的 [TapGestureRecognizer.onTapDown] 回调调用
  ///
  /// 当 [ignorePointer] 为 true 时，祖先小部件必须通过调用此方法来响应点击事件
  void handleTapDown(TapDownDetails details) {
    _lastTapDownPosition = details.globalPosition;
  }

  /// 处理点击按下事件
  void _handleTapDown(TapDownDetails details) {
    assert(!ignorePointer);
    handleTapDown(details);
  }

  /// 如果 [ignorePointer] 为 false（默认值），则此方法由内部手势识别器的 [TapGestureRecognizer.onTap] 回调调用
  ///
  /// 当 [ignorePointer] 为 true 时，祖先小部件必须通过调用此方法来响应点击事件
  void handleTap() {
    selectPosition(cause: SelectionChangedCause.tap);
  }

  /// 处理点击事件
  void _handleTap() {
    assert(!ignorePointer);
    handleTap();
  }

  /// 如果 [ignorePointer] 为 false（默认值），则此方法由内部手势识别器的 [DoubleTapGestureRecognizer.onDoubleTap] 回调调用
  ///
  /// 当 [ignorePointer] 为 true 时，祖先小部件必须通过调用此方法来响应双击事件
  void handleDoubleTap() {
    selectWord(cause: SelectionChangedCause.doubleTap);
  }

  /// 如果 [ignorePointer] 为 false（默认值），则此方法由内部手势识别器的 [LongPressGestureRecognizer.onLongPress] 回调调用
  ///
  /// 当 [ignorePointer] 为 true 时，祖先小部件必须通过调用此方法来响应长按事件
  void handleLongPress() {
    selectWord(cause: SelectionChangedCause.longPress);
  }

  /// 处理长按事件
  void _handleLongPress() {
    assert(!ignorePointer);
    handleLongPress();
  }

  /// 将选择移动到最后一次点击的位置
  ///
  /// 此方法主要用于将全局位置的用户输入转换为 [TextSelection]
  /// 当与 [MongolEditableText] 结合使用时，选择更改会反馈到 [TextEditingController.selection]
  ///
  /// 如果您有 [TextEditingController]，通常更容易直接以编程方式操作其 `value` 或 `selection`
  void selectPosition({required SelectionChangedCause cause}) {
    selectPositionAt(from: _lastTapDownPosition!, cause: cause);
  }

  /// 在全局位置 [from] 和 [to] 之间选择文本
  ///
  /// [from] 对应于 [TextSelection.baseOffset]，[to] 对应于 [TextSelection.extentOffset]
  void selectPositionAt(
      {required Offset from,
      Offset? to,
      required SelectionChangedCause cause}) {
    _layoutText(
        minHeight: constraints.minHeight, maxHeight: constraints.maxHeight);
    final fromPosition =
        _textPainter.getPositionForOffset(globalToLocal(from - _paintOffset));
    final toPosition = (to == null)
        ? null
        : _textPainter.getPositionForOffset(globalToLocal(to - _paintOffset));

    final baseOffset = fromPosition.offset;
    final extentOffset = toPosition?.offset ?? fromPosition.offset;

    final newSelection = TextSelection(
      baseOffset: baseOffset,
      extentOffset: extentOffset,
      affinity: fromPosition.affinity,
    );
    _setSelection(newSelection, cause);
  }

  /// 选择最后一次点击位置周围的单词
  void selectWord({required SelectionChangedCause cause}) {
    selectWordsInRange(from: _lastTapDownPosition!, cause: cause);
  }

  /// 在给定的全局位置范围内选择段落中的单词集合
  ///
  /// 选择的第一个和最后一个端点将始终分别位于单词的开头和结尾
  /// [from] 是选择的起始位置
  /// [to] 是选择的结束位置，可为 null
  /// [cause] 是选择更改的原因
  void selectWordsInRange(
      {required Offset from,
      Offset? to,
      required SelectionChangedCause cause}) {
    _computeTextMetricsIfNeeded();
    final TextPosition fromPosition =
        _textPainter.getPositionForOffset(globalToLocal(from - _paintOffset));
    final TextSelection fromWord = _getWordAtOffset(fromPosition);
    final TextPosition toPosition = to == null
        ? fromPosition
        : _textPainter.getPositionForOffset(globalToLocal(to - _paintOffset));
    final TextSelection toWord =
        toPosition == fromPosition ? fromWord : _getWordAtOffset(toPosition);
    final bool isFromWordBeforeToWord = fromWord.start < toWord.end;

    _setSelection(
      TextSelection(
        baseOffset: isFromWordBeforeToWord
            ? fromWord.base.offset
            : fromWord.extent.offset,
        extentOffset:
            isFromWordBeforeToWord ? toWord.extent.offset : toWord.base.offset,
        affinity: fromWord.affinity,
      ),
      cause,
    );
  }

  /// 将选择移动到单词的开头或结尾
  ///
  /// [cause] 是选择更改的原因
  void selectWordEdge({required SelectionChangedCause cause}) {
    _computeTextMetricsIfNeeded();
    assert(_lastTapDownPosition != null);
    final TextPosition position = _textPainter.getPositionForOffset(
        globalToLocal(_lastTapDownPosition! - _paintOffset));
    final TextRange word = _textPainter.getWordBoundary(position);
    late TextSelection newSelection;
    if (position.offset <= word.start) {
      newSelection = TextSelection.collapsed(offset: word.start);
    } else {
      newSelection = TextSelection.collapsed(
          offset: word.end, affinity: TextAffinity.upstream);
    }
    _setSelection(newSelection, cause);
  }

  /// 获取指定文本位置处的单词
  ///
  /// [position] 是文本位置
  /// 返回包含该位置单词的选择范围
  TextSelection _getWordAtOffset(TextPosition position) {
    debugAssertLayoutUpToDate();
    // When long-pressing past the end of the text, we want a collapsed cursor.
    if (position.offset >= plainText.length) {
      return TextSelection.fromPosition(TextPosition(
          offset: plainText.length, affinity: TextAffinity.upstream));
    }
    // If text is obscured, the entire sentence should be treated as one word.
    if (obscureText) {
      return TextSelection(baseOffset: 0, extentOffset: plainText.length);
    }
    final TextRange word = _textPainter.getWordBoundary(position);
    final int effectiveOffset;
    switch (position.affinity) {
      case TextAffinity.upstream:
        // upstream affinity is effectively -1 in text position.
        effectiveOffset = position.offset - 1;
        break;
      case TextAffinity.downstream:
        effectiveOffset = position.offset;
        break;
    }

    // On iOS, select the previous word if there is a previous word, or select
    // to the end of the next word if there is a next word. Select nothing if
    // there is neither a previous word nor a next word.
    //
    // If the platform is Android and the text is read only, try to select the
    // previous word if there is one; otherwise, select the single whitespace at
    // the position.
    if (TextLayoutMetrics.isWhitespace(plainText.codeUnitAt(effectiveOffset)) &&
        effectiveOffset > 0) {
      final TextRange? previousWord = _getPreviousWord(word.start);
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          if (previousWord == null) {
            final TextRange? nextWord = _getNextWord(word.start);
            if (nextWord == null) {
              return TextSelection.collapsed(offset: position.offset);
            }
            return TextSelection(
              baseOffset: position.offset,
              extentOffset: nextWord.end,
            );
          }
          return TextSelection(
            baseOffset: previousWord.start,
            extentOffset: position.offset,
          );
        case TargetPlatform.android:
          if (readOnly) {
            if (previousWord == null) {
              return TextSelection(
                baseOffset: position.offset,
                extentOffset: position.offset + 1,
              );
            }
            return TextSelection(
              baseOffset: previousWord.start,
              extentOffset: position.offset,
            );
          }
          break;
        case TargetPlatform.fuchsia:
        case TargetPlatform.macOS:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          break;
      }
    }

    return TextSelection(baseOffset: word.start, extentOffset: word.end);
  }

  /// 布局文本
  ///
  /// [minHeight] 是最小高度，默认为 0.0
  /// [maxHeight] 是最大高度，默认为无限大
  /// 根据给定的高度约束计算文本的布局
  void _layoutText(
      {double minHeight = 0.0, double maxHeight = double.infinity}) {
    if (_textLayoutLastMaxHeight == maxHeight &&
        _textLayoutLastMinHeight == minHeight) {
      return;
    }
    final availableMaxHeight = math.max(0.0, maxHeight - _caretMargin);
    final availableMinHeight = math.min(minHeight, availableMaxHeight);
    final textMaxHeight = _isMultiline ? availableMaxHeight : double.infinity;
    final textMinHeight = forceLine ? availableMaxHeight : availableMinHeight;
    _textPainter.layout(
      minHeight: textMinHeight,
      maxHeight: textMaxHeight,
    );
    _textLayoutLastMinHeight = minHeight;
    _textLayoutLastMaxHeight = maxHeight;
  }

  // Computes the text metrics if `_textPainter`'s layout information was marked
  // as dirty.
  //
  // This method must be called in `RenderEditable`'s public methods that expose
  // `_textPainter`'s metrics. For instance, `systemFontsDidChange` sets
  // _textPainter._paragraph to null, so accessing _textPainter's metrics
  // immediately after `systemFontsDidChange` without first calling this method
  // may crash.
  //
  // This method is also called in various paint methods (`RenderEditable.paint`
  // as well as its foreground/background painters' `paint`). It's needed
  // because invisible render objects kept in the tree by `KeepAlive` may not
  /// 在需要时计算文本度量
  ///
  /// 此方法只有在底层 `_textPainter` 的布局缓存被失效（通过调用 `TextPainter.markNeedsLayout`）时，
  /// 或用于布局 `_textPainter` 的约束不同时才会重新计算布局
  /// 这样可以确保文本在布局无效时重新布局，同时在布局有效时保持性能
  void _computeTextMetricsIfNeeded() {
    _layoutText(
        minHeight: constraints.minHeight, maxHeight: constraints.maxHeight);
  }

  late Rect _caretPrototype; // 光标原型

  /// 计算光标原型
  ///
  /// 根据不同的平台计算光标的形状和大小
  void _computeCaretPrototype() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        _caretPrototype =
            Rect.fromLTWH(0.0, 0.0, cursorWidth + 2, cursorHeight);
        break;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        _caretPrototype = Rect.fromLTWH(_kCaretWidthOffset, 0.0,
            cursorWidth - 2.0 * _kCaretWidthOffset, cursorHeight);
        break;
    }
  }

  /// 计算应用于给定 [sourceOffset] 的偏移量，使其完美对齐到物理像素
  ///
  /// 确保渲染的元素在不同设备像素密度下都能清晰显示
  Offset _snapToPhysicalPixel(Offset sourceOffset) {
    final globalOffset = localToGlobal(sourceOffset);
    final pixelMultiple = 1.0 / _devicePixelRatio;
    return Offset(
      globalOffset.dx.isFinite
          ? (globalOffset.dx / pixelMultiple).round() * pixelMultiple -
              globalOffset.dx
          : 0,
      globalOffset.dy.isFinite
          ? (globalOffset.dy / pixelMultiple).round() * pixelMultiple -
              globalOffset.dy
          : 0,
    );
  }

  @override
  /// 计算干布局尺寸
  ///
  /// 在不实际执行布局的情况下，计算渲染对象在给定约束下的尺寸
  /// [constraints] 是布局约束
  Size computeDryLayout(BoxConstraints constraints) {
    _layoutText(
        minHeight: constraints.minHeight, maxHeight: constraints.maxHeight);
    final height = forceLine
        ? constraints.maxHeight
        : constraints.constrainHeight(_textPainter.size.height + _caretMargin);
    return Size(
        constraints.constrainWidth(_preferredWidth(constraints.maxHeight)),
        height);
  }

  @override
  /// 执行布局
  ///
  /// 计算渲染对象的实际尺寸和位置
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    _computeTextMetricsIfNeeded();
    _computeCaretPrototype();
    // 我们在这里获取 _textPainter.size，因为下一行分配给 `size` 会触发我们验证内在尺寸，
    // 这会改变 _textPainter 的布局，因为内在尺寸计算是破坏性的，
    // 这意味着如果我们稍后在这个方法中使用 _textPainter 的属性，我们会得到不同的结果
    // 其他 _textPainter 状态如 didExceedMaxLines 也会受到影响，尽管我们目前不在这里使用它们
    // 另请参见 MongolRenderParagraph，它有类似的问题
    final Size textPainterSize = _textPainter.size;
    final double height = forceLine
        ? constraints.maxHeight
        : constraints.constrainWidth(_textPainter.size.height + _caretMargin);
    final double preferredWidth = _preferredWidth(constraints.maxHeight);
    size = Size(constraints.constrainWidth(preferredWidth), height);
    final Size contentSize = Size(
      textPainterSize.width,
      textPainterSize.height + _caretMargin,
    );

    final BoxConstraints painterConstraints = BoxConstraints.tight(contentSize);

    _foregroundRenderObject?.layout(painterConstraints);
    _backgroundRenderObject?.layout(painterConstraints);

    _maxScrollExtent = _getMaxScrollExtent(contentSize);
    offset.applyViewportDimension(_viewportExtent);
    offset.applyContentDimensions(0.0, _maxScrollExtent);
  }

  /// 获取指定文本位置所在的行号和偏移量
  ///
  /// [startPosition] 是文本位置
  /// [metrics] 是行度量信息列表
  /// 返回包含行号和偏移量的 MapEntry
  MapEntry<int, Offset> _lineNumberFor(
    TextPosition startPosition,
    List<MongolLineMetrics> metrics,
  ) {
    final offset = _textPainter.getOffsetForCaret(startPosition, Rect.zero);
    for (final MongolLineMetrics lineMetrics in metrics) {
      if (lineMetrics.baseline > offset.dx) {
        return MapEntry<int, Offset>(
          lineMetrics.lineNumber,
          Offset(lineMetrics.baseline, offset.dy),
        );
      }
    }
    assert(
      startPosition.offset == 0,
      'unable to find the line for $startPosition',
    );
    return MapEntry<int, Offset>(
      math.max(0, metrics.length - 1),
      Offset(
          metrics.isNotEmpty
              ? metrics.last.baseline + metrics.last.ascent
              : 0.0,
          offset.dy),
    );
  }

  /// Starts a [HorizontalCaretMovementRun] at the given location in the text, for
  /// handling consecutive horizontal caret movements.
  ///
  /// This can be used to handle consecutive left/right arrow key movements
  /// in an input field.
  ///
  /// The [HorizontalCaretMovementRun.isValid] property indicates whether the text
  /// layout has changed and the horizontal caret run is invalidated.
  ///
  /// The caller should typically discard a [HorizontalCaretMovementRun] when
  /// its [HorizontalCaretMovementRun.isValid] becomes false, or on other
  /// occasions where the horizontal caret run should be interrupted.
  HorizontalCaretMovementRun startHorizontalCaretMovement(
      TextPosition startPosition) {
    final List<MongolLineMetrics> metrics = _textPainter.computeLineMetrics();
    final MapEntry<int, Offset> currentLine =
        _lineNumberFor(startPosition, metrics);
    return HorizontalCaretMovementRun._(
      this,
      metrics,
      startPosition,
      currentLine.key,
      currentLine.value,
    );
  }

  /// 绘制内容
  ///
  /// [context] 是绘制上下文
  /// [offset] 是绘制偏移量
  void _paintContents(PaintingContext context, Offset offset) {
    debugAssertLayoutUpToDate();
    final effectiveOffset = offset + _paintOffset;

    if (selection != null) {
      _updateSelectionExtentsVisibility(effectiveOffset);
    }

    final RenderBox? foregroundChild = _foregroundRenderObject;
    final RenderBox? backgroundChild = _backgroundRenderObject;

    // 绘制器在视口的坐标空间中绘制，因为高级小部件不知道 textPainter 的坐标空间
    if (backgroundChild != null) context.paintChild(backgroundChild, offset);

    _textPainter.paint(context.canvas, effectiveOffset);

    if (foregroundChild != null) context.paintChild(foregroundChild, offset);
  }

  /// 绘制选择句柄图层
  ///
  /// [context] 是绘制上下文
  /// [endpoints] 是选择端点列表
  /// [offset] 是绘制偏移量
  void _paintHandleLayers(
    PaintingContext context,
    List<TextSelectionPoint> endpoints,
    Offset offset,
  ) {
    var startPoint = endpoints[0].point;
    startPoint = Offset(
      startPoint.dx.clamp(0.0, size.width),
      startPoint.dy.clamp(0.0, size.height),
    );
    context.pushLayer(
      LeaderLayer(link: startHandleLayerLink, offset: startPoint + offset),
      super.paint,
      Offset.zero,
    );
    if (endpoints.length == 2) {
      var endPoint = endpoints[1].point;
      endPoint = Offset(
        endPoint.dx.clamp(0.0, size.width),
        endPoint.dy.clamp(0.0, size.height),
      );
      context.pushLayer(
        LeaderLayer(link: endHandleLayerLink, offset: endPoint + offset),
        super.paint,
        Offset.zero,
      );
    }
  }

  @override
  /// 绘制渲染对象
  ///
  /// [context] 是绘制上下文
  /// [offset] 是绘制偏移量
  void paint(PaintingContext context, Offset offset) {
    _computeTextMetricsIfNeeded();
    if (_hasVisualOverflow && clipBehavior != Clip.none) {
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        _paintContents,
        clipBehavior: clipBehavior,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      _clipRectLayer.layer = null;
      _paintContents(context, offset);
    }
    final TextSelection? selection = this.selection;
    if (selection != null && selection.isValid) {
      _paintHandleLayers(context, getEndpointsForSelection(selection), offset);
    }
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer =
      LayerHandle<ClipRectLayer>();

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _hasVisualOverflow ? Offset.zero & size : null;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('cursorColor', cursorColor));
    properties.add(
        DiagnosticsProperty<ValueNotifier<bool>>('showCursor', showCursor));
    properties.add(IntProperty('maxLines', maxLines));
    properties.add(IntProperty('minLines', minLines));
    properties.add(
        DiagnosticsProperty<bool>('expands', expands, defaultValue: false));
    properties.add(ColorProperty('selectionColor', selectionColor));
    properties.add(DoubleProperty('textScaleFactor', textScaleFactor));
    properties.add(DiagnosticsProperty<TextSelection>('selection', selection));
    properties.add(DiagnosticsProperty<ViewportOffset>('offset', offset));
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return <DiagnosticsNode>[
      if (text != null)
        text!.toDiagnosticsNode(
          name: 'text',
          style: DiagnosticsTreeStyle.transition,
        ),
    ];
  }
}

class _MongolRenderEditableCustomPaint extends RenderBox {
  _MongolRenderEditableCustomPaint({
    MongolRenderEditablePainter? painter,
  })  : _painter = painter,
        super();

  @override
  MongolRenderEditable? get parent => super.parent as MongolRenderEditable?;

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  MongolRenderEditablePainter? get painter => _painter;
  MongolRenderEditablePainter? _painter;

  set painter(MongolRenderEditablePainter? newValue) {
    if (newValue == painter) return;

    final oldPainter = painter;
    _painter = newValue;

    if (newValue?.shouldRepaint(oldPainter) ?? true) markNeedsPaint();

    if (attached) {
      oldPainter?.removeListener(markNeedsPaint);
      newValue?.addListener(markNeedsPaint);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final parent = this.parent;
    assert(parent != null);
    final painter = this.painter;
    if (painter != null && parent != null) {
      parent._computeTextMetricsIfNeeded();
      painter.paint(context.canvas, size, parent);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _painter?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _painter?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;
}

/// An interface that paints within a [MongolRenderEditable]'s bounds, above or
/// beneath its text content.
///
/// This painter is typically used for painting auxiliary content that depends
/// on text layout metrics (for instance, for painting carets and text highlight
/// blocks). It can paint independently from its [MongolRenderEditable],
/// allowing it to repaint without triggering a repaint on the entire
/// [MongolRenderEditable] stack when only auxiliary content changes (e.g. a
/// blinking cursor) are present. It will be scheduled to repaint when:
///
///  * It's assigned to a new [MongolRenderEditable] and the [shouldRepaint]
///    method returns true.
///  * Any of the [MongolRenderEditable]s it is attached to repaints.
///  * The [notifyListeners] method is called, which typically happens when the
///    painter's attributes change.
///
/// See also:
///
///  * [MongolRenderEditable.foregroundPainter], which takes a
///    [MongolRenderEditablePainter] and sets it as the foreground painter of
///    the [MongolRenderEditable].
///  * [MongolRenderEditable.painter], which takes a [MongolRenderEditablePainter]
///    and sets it as the background painter of the [MongolRenderEditable].
///  * [CustomPainter] a similar class which paints within a [RenderCustomPaint].
abstract class MongolRenderEditablePainter extends ChangeNotifier {
  /// Determines whether repaint is needed when a new
  /// [MongolRenderEditablePainter] is provided to a [MongolRenderEditable].
  ///
  /// If the new instance represents different information than the old
  /// instance, then the method should return true, otherwise it should return
  /// false. When [oldDelegate] is null, this method should always return true
  /// unless the new painter initially does not paint anything.
  ///
  /// If the method returns false, then the [paint] call might be optimized
  /// away. However, the [paint] method will get called whenever the
  /// [MongolRenderEditable]s it attaches to repaint, even if [shouldRepaint]
  /// returns false.
  bool shouldRepaint(MongolRenderEditablePainter? oldDelegate);

  /// Paints within the bounds of a [MongolRenderEditable].
  ///
  /// The given [Canvas] has the same coordinate space as the
  /// [MongolRenderEditable], which may be different from the coordinate space
  /// the [MongolRenderEditable]'s [MongolTextPainter] uses, when the text moves
  /// inside the [MongolRenderEditable].
  ///
  /// Paint operations performed outside of the region defined by the [canvas]'s
  /// origin and the [size] parameter may get clipped, when
  /// [MongolRenderEditable]'s [MongolRenderEditable.clipBehavior] is not
  /// [Clip.none].
  void paint(Canvas canvas, Size size, MongolRenderEditable renderEditable);
}

class _TextHighlightPainter extends MongolRenderEditablePainter {
  _TextHighlightPainter({TextRange? highlightedRange, Color? highlightColor})
      : _highlightedRange = highlightedRange,
        _highlightColor = highlightColor;

  final Paint highlightPaint = Paint();

  Color? get highlightColor => _highlightColor;
  Color? _highlightColor;

  set highlightColor(Color? newValue) {
    if (newValue == _highlightColor) return;
    _highlightColor = newValue;
    notifyListeners();
  }

  TextRange? get highlightedRange => _highlightedRange;
  TextRange? _highlightedRange;

  set highlightedRange(TextRange? newValue) {
    if (newValue == _highlightedRange) return;
    _highlightedRange = newValue;
    notifyListeners();
  }

  @override
  void paint(Canvas canvas, Size size, MongolRenderEditable renderEditable) {
    final range = highlightedRange;
    final color = highlightColor;
    if (range == null || color == null || range.isCollapsed) {
      return;
    }

    highlightPaint.color = color;
    final boxes = renderEditable._textPainter.getBoxesForSelection(
      TextSelection(baseOffset: range.start, extentOffset: range.end),
    );

    for (final box in boxes) {
      canvas.drawRect(box.shift(renderEditable._paintOffset), highlightPaint);
    }
  }

  @override
  bool shouldRepaint(MongolRenderEditablePainter? oldDelegate) {
    if (identical(oldDelegate, this)) {
      return false;
    }
    if (oldDelegate == null) {
      return highlightColor != null && highlightedRange != null;
    }
    return oldDelegate is! _TextHighlightPainter ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.highlightedRange != highlightedRange;
  }
}

class _CaretPainter extends MongolRenderEditablePainter {
  _CaretPainter();

  bool get shouldPaint => _shouldPaint;
  bool _shouldPaint = true;

  set shouldPaint(bool value) {
    if (shouldPaint == value) return;
    _shouldPaint = value;
    notifyListeners();
  }

  bool showRegularCaret = false;

  final Paint caretPaint = Paint();
  late final Paint floatingCursorPaint = Paint();

  Color? get caretColor => _caretColor;
  Color? _caretColor;

  set caretColor(Color? value) {
    if (caretColor == value) return;

    _caretColor = value;
    notifyListeners();
  }

  Radius? get cursorRadius => _cursorRadius;
  Radius? _cursorRadius;

  set cursorRadius(Radius? value) {
    if (_cursorRadius == value) return;
    _cursorRadius = value;
    notifyListeners();
  }

  Offset get cursorOffset => _cursorOffset;
  Offset _cursorOffset = Offset.zero;

  set cursorOffset(Offset value) {
    if (_cursorOffset == value) return;
    _cursorOffset = value;
    notifyListeners();
  }

  void paintRegularCursor(
    Canvas canvas,
    MongolRenderEditable renderEditable,
    Color caretColor,
    TextPosition textPosition,
  ) {
    final integralRect = renderEditable.getLocalRectForCaret(textPosition);
    if (shouldPaint) {
      final radius = cursorRadius;
      caretPaint.color = caretColor;
      if (radius == null) {
        canvas.drawRect(integralRect, caretPaint);
      } else {
        final caretRRect = RRect.fromRectAndRadius(integralRect, radius);
        canvas.drawRRect(caretRRect, caretPaint);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size, MongolRenderEditable renderEditable) {
    // Compute the caret location even when `shouldPaint` is false.

    final selection = renderEditable.selection;

    if (selection == null || !selection.isCollapsed) {
      return;
    }

    final caretColor = this.caretColor;
    final caretTextPosition = selection.extent;

    if (caretColor != null) {
      paintRegularCursor(canvas, renderEditable, caretColor, caretTextPosition);
    }
  }

  @override
  bool shouldRepaint(MongolRenderEditablePainter? oldDelegate) {
    if (identical(this, oldDelegate)) return false;

    if (oldDelegate == null) return shouldPaint;
    return oldDelegate is! _CaretPainter ||
        oldDelegate.shouldPaint != shouldPaint ||
        oldDelegate.caretColor != caretColor ||
        oldDelegate.cursorRadius != cursorRadius ||
        oldDelegate.cursorOffset != cursorOffset;
  }
}

class _CompositeRenderEditablePainter extends MongolRenderEditablePainter {
  _CompositeRenderEditablePainter({required this.painters});

  final List<MongolRenderEditablePainter> painters;

  @override
  void addListener(VoidCallback listener) {
    for (final painter in painters) {
      painter.addListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    for (final painter in painters) {
      painter.removeListener(listener);
    }
  }

  @override
  void paint(Canvas canvas, Size size, MongolRenderEditable renderEditable) {
    for (final painter in painters) {
      painter.paint(canvas, size, renderEditable);
    }
  }

  @override
  bool shouldRepaint(MongolRenderEditablePainter? oldDelegate) {
    if (identical(oldDelegate, this)) return false;
    if (oldDelegate is! _CompositeRenderEditablePainter ||
        oldDelegate.painters.length != painters.length) {
      return true;
    }

    final oldPainters = oldDelegate.painters.iterator;
    final newPainters = painters.iterator;
    while (oldPainters.moveNext() && newPainters.moveNext()) {
      if (newPainters.current.shouldRepaint(oldPainters.current)) return true;
    }

    return false;
  }
}
