part of '../mongol_render_editable.dart';

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
