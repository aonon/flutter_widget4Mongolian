part of '../mongol_text_selection.dart';

class MongolTextSelectionGestureDetectorBuilder {
  /// 创建一个 [MongolTextSelectionGestureDetectorBuilder]。
  ///
  /// 参数：
  /// - delegate: 此构建器的委托
  MongolTextSelectionGestureDetectorBuilder({
    required this.delegate,
  });

  /// 此 [MongolTextSelectionGestureDetectorBuilder] 的委托。
  ///
  /// 委托向构建器提供有关当前可以在文本字段上执行哪些操作的信息。
  /// 基于此，构建器向手势检测器添加正确的手势处理程序。
  @protected
  final MongolTextSelectionGestureDetectorBuilderDelegate delegate;

  // 在支持的平台上在给定偏移处显示放大镜，目前仅 Android 和 iOS。
  void _showMagnifierIfSupportedByPlatform(Offset positionToShow) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        editableText.showMagnifier(positionToShow);
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
    }
  }

  // 在支持的平台上隐藏放大镜，目前仅 Android 和 iOS。
  void _hideMagnifierIfSupportedByPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        editableText.hideMagnifier();
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
    }
  }

  /// 如果 lastSecondaryTapDownPosition 在选择上，则返回 true。
  bool get _lastSecondaryTapWasOnSelection {
    assert(renderEditable.lastSecondaryTapDownPosition != null);
    if (renderEditable.selection == null) {
      return false;
    }

    final TextPosition textPosition = renderEditable.getPositionForPoint(
      renderEditable.lastSecondaryTapDownPosition!,
    );

    return renderEditable.selection!.start <= textPosition.offset &&
        renderEditable.selection!.end >= textPosition.offset;
  }

  bool _positionWasOnSelectionExclusive(TextPosition textPosition) {
    final TextSelection? selection = renderEditable.selection;
    if (selection == null) {
      return false;
    }

    return selection.start < textPosition.offset &&
        selection.end > textPosition.offset;
  }

  bool _positionWasOnSelectionInclusive(TextPosition textPosition) {
    final TextSelection? selection = renderEditable.selection;
    if (selection == null) {
      return false;
    }

    return selection.start <= textPosition.offset &&
        selection.end >= textPosition.offset;
  }

  /// 如果位置在选择上，则返回 true。
  bool _positionOnSelection(Offset position, TextSelection? targetSelection) {
    if (targetSelection == null) {
      return false;
    }

    final TextPosition textPosition =
        renderEditable.getPositionForPoint(position);

    return targetSelection.start <= textPosition.offset &&
        targetSelection.end >= textPosition.offset;
  }

  // 将选择扩展到给定的全局位置。
  //
  // 基础或范围将移动到最后点击的位置，以较近的为准。
  // 选择永远不会缩小或旋转，只会增长。
  //
  // 如果给出 fromSelection，则从该选择扩展，而不是从 renderEditable 中的当前选择。
  //
  // 另请参阅：
  //
  //   * [_extendSelection]，它类似但围绕基础旋转选择。
  void _expandSelection(Offset offset, SelectionChangedCause cause,
      [TextSelection? fromSelection]) {
    assert(renderEditable.selection?.baseOffset != null);

    final TextPosition tappedPosition =
        renderEditable.getPositionForPoint(offset);
    final TextSelection selection = fromSelection ?? renderEditable.selection!;
    final bool baseIsCloser =
        (tappedPosition.offset - selection.baseOffset).abs() <
            (tappedPosition.offset - selection.extentOffset).abs();
    final TextSelection nextSelection = selection.copyWith(
      baseOffset: baseIsCloser ? selection.extentOffset : selection.baseOffset,
      extentOffset: tappedPosition.offset,
    );

    editableText.userUpdateTextEditingValue(
      editableText.textEditingValue.copyWith(
        selection: nextSelection,
      ),
      cause,
    );
  }

  // 将选择扩展到给定的全局位置。
  //
  // 保持基础不变并移动范围。
  //
  // 另请参阅：
  //
  //   * [_expandSelection]，它类似但总是增加选择的大小。
  void _extendSelection(Offset offset, SelectionChangedCause cause) {
    assert(renderEditable.selection?.baseOffset != null);

    final TextPosition tappedPosition =
        renderEditable.getPositionForPoint(offset);
    final TextSelection selection = renderEditable.selection!;
    final TextSelection nextSelection = selection.copyWith(
      extentOffset: tappedPosition.offset,
    );

    editableText.userUpdateTextEditingValue(
      editableText.textEditingValue.copyWith(
        selection: nextSelection,
      ),
      cause,
    );
  }

  /// 是否显示选择工具栏。
  ///
  /// 它基于调用 [onTapDown] 时的信号源。如果当前 [onTapDown] 事件是由触摸或手写笔触发的，
  /// 此 getter 将返回 true。
  bool get shouldShowSelectionToolbar => _shouldShowSelectionToolbar;
  bool _shouldShowSelectionToolbar = true;

  /// [EditableText] 的 [State]，构建器将为其提供 [TextSelectionGestureDetector]。
  @protected
  MongolEditableTextState get editableText =>
      delegate.editableTextKey.currentState!;

  /// [MongolEditableText] 的 [RenderObject]，构建器将为其提供 [TextSelectionGestureDetector]。
  @protected
  MongolRenderEditable get renderEditable => editableText.renderEditable;

  /// 当最近的 [PointerDownEvent] 被 [BaseTapAndDragGestureRecognizer] 跟踪时，Shift 键是否被按下。
  bool _isShiftPressed = false;

  /// 上次拖动开始时包含 [MongolRenderEditable] 的任何 [Scrollable] 的视口偏移像素。
  double _dragStartScrollOffset = 0.0;

  /// 上次拖动开始时 [MongolRenderEditable] 的视口偏移像素。
  double _dragStartViewportOffset = 0.0;

  double get _scrollPosition {
    final ScrollableState? scrollableState =
        delegate.editableTextKey.currentContext == null
            ? null
            : Scrollable.maybeOf(delegate.editableTextKey.currentContext!);
    return scrollableState == null ? 0.0 : scrollableState.position.pixels;
  }

  // 对于 shift + tap + drag 手势，是点击点的 TextSelection。
  // Mac 使用此值在基础和偏移反转时重置为原始选择。
  TextSelection? _dragStartSelection;

  // 对于 iOS 上的 tap + drag 手势，拖动开始的位置是否在先前的 TextSelection 上。
  // iOS 使用此值来确定光标是否应在拖动更新时移动。
  //
  // 如果拖动开始于先前的选择，则光标将在拖动更新时移动。
  // 如果拖动不是开始于先前的选择，则光标不会在拖动更新时移动。
  bool? _dragBeganOnPreviousSelection;

  // 对于字段未聚焦时的 iOS 长按行为。iOS 使用此值来确定长按是否开始于未聚焦的字段。
  //
  // 如果长按开始时字段未聚焦，长按将选择单词，长按移动将逐字选择。
  // 如果字段已聚焦，光标将移动到长按位置。
  bool _longPressStartedWithoutFocus = false;

  /// [TextSelectionGestureDetector.onTapTrackStart] 的处理程序。
  ///
  /// 另请参阅：
  ///
  ///  * [TextSelectionGestureDetector.onTapTrackStart]，它触发此回调。
  @protected
  void onTapTrackStart() {
    _isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed
        .intersection(<LogicalKeyboardKey>{
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight
    }).isNotEmpty;
  }

  /// [TextSelectionGestureDetector.onTapTrackReset] 的处理程序。
  ///
  /// 另请参阅：
  ///
  ///  * [TextSelectionGestureDetector.onTapTrackReset]，它触发此回调。
  @protected
  void onTapTrackReset() {
    _isShiftPressed = false;
  }

  /// [TextSelectionGestureDetector.onTapDown] 的处理程序。
  ///
  /// 默认情况下，它将点击转发给 [MongolRenderEditable.handleTapDown]，
  /// 并在点击由手指或手写笔启动时将 [shouldShowSelectionToolbar] 设置为 true。
  ///
  /// 另请参阅：
  ///
  ///  * [TextSelectionGestureDetector.onTapDown]，它触发此回调。
  @protected
  void onTapDown(TapDragDownDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }
    renderEditable
        .handleTapDown(TapDownDetails(globalPosition: details.globalPosition));
    // 选择覆盖层应仅在用户通过触摸屏（通过手指或手写笔）交互时显示。
    // 鼠标不应触发选择覆盖层。
    // 为了向后兼容，我们将 null 类型视为与触摸相同。
    final PointerDeviceKind? kind = details.kind;
    _shouldShowSelectionToolbar = kind == null ||
        kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus;

    // 如果 renderEditable.selection 无效，则在按下 Shift 键时无法扩展选择。
    final bool isShiftPressedValid =
        _isShiftPressed && renderEditable.selection?.baseOffset != null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        // 在移动平台上，选择在点击时设置。
        editableText.hideToolbar(false);
      case TargetPlatform.iOS:
        // 在移动平台上，选择在点击时设置。
        break;
      case TargetPlatform.macOS:
        editableText.hideToolbar();
        // 在 macOS 上，shift-tapped 未聚焦字段从 0 扩展，而不是从先前的选择。
        if (isShiftPressedValid) {
          final TextSelection? fromSelection = renderEditable.hasFocus
              ? null
              : const TextSelection.collapsed(offset: 0);
          _expandSelection(
            details.globalPosition,
            SelectionChangedCause.tap,
            fromSelection,
          );
          return;
        }
        // 在 macOS 上，点击/单击将选择放置在精确位置。
        // 这与 iOS/iPadOS 不同，在 iOS/iPadOS 中，如果手势是通过触摸完成的，
        // 则选择会移动到最近的单词边缘，而不是精确位置。
        renderEditable.selectPosition(cause: SelectionChangedCause.tap);
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        editableText.hideToolbar();
        if (isShiftPressedValid) {
          _extendSelection(details.globalPosition, SelectionChangedCause.tap);
          return;
        }
        renderEditable.selectPosition(cause: SelectionChangedCause.tap);
    }
  }

  /// [TextSelectionGestureDetector.onForcePressStart] 的处理程序。
  ///
  /// 默认情况下，如果启用了选择，它会选择强制按压位置的单词。
  ///
  /// 此回调仅在启用强制按压时适用。
  ///
  /// 另请参阅：
  ///
  ///  * [TextSelectionGestureDetector.onForcePressStart]，它触发此回调。
  @protected
  void onForcePressStart(ForcePressDetails details) {
    assert(delegate.forcePressEnabled);
    _shouldShowSelectionToolbar = true;
    if (delegate.selectionEnabled) {
      renderEditable.selectWordsInRange(
        from: details.globalPosition,
        cause: SelectionChangedCause.forcePress,
      );
    }
  }

  /// [TextSelectionGestureDetector.onForcePressEnd] 的处理程序。
  ///
  /// 默认情况下，它选择 [details] 中指定的范围内的单词，并在必要时显示工具栏。
  ///
  /// 此回调仅在启用强制按压时适用。
  ///
  /// 另请参阅：
  ///
  ///  * [TextSelectionGestureDetector.onForcePressEnd]，它触发此回调。
  @protected
  void onForcePressEnd(ForcePressDetails details) {
    assert(delegate.forcePressEnabled);
    renderEditable.selectWordsInRange(
      from: details.globalPosition,
      cause: SelectionChangedCause.forcePress,
    );
    if (shouldShowSelectionToolbar) editableText.showToolbar();
  }

  /// [TextSelectionGestureDetector.onSingleTapUp] 的处理程序。
  ///
  /// 默认情况下，如果启用了选择，它会选择单词边缘。
  ///
  /// 另请参阅：
  ///
  ///  * [TextSelectionGestureDetector.onSingleTapUp]，它触发此回调。
  @protected
  void onSingleTapUp(TapDragUpDetails details) {
    if (delegate.selectionEnabled) {
      // 如果 renderEditable.selection 无效，则在按下 Shift 键时无法扩展选择。
      final bool isShiftPressedValid =
          _isShiftPressed && renderEditable.selection?.baseOffset != null;
      switch (defaultTargetPlatform) {
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          break;
        // 在桌面平台上，选择在点击时设置。
        case TargetPlatform.android:
          if (isShiftPressedValid) {
            _extendSelection(details.globalPosition, SelectionChangedCause.tap);
            return;
          }
          renderEditable.selectPosition(cause: SelectionChangedCause.tap);
          editableText.showSpellCheckSuggestionsToolbar();
        case TargetPlatform.fuchsia:
          if (isShiftPressedValid) {
            _extendSelection(details.globalPosition, SelectionChangedCause.tap);
            return;
          }
          renderEditable.selectPosition(cause: SelectionChangedCause.tap);
        case TargetPlatform.iOS:
          if (isShiftPressedValid) {
            // 在 iOS 上，shift-tapped 未聚焦字段从 0 扩展，而不是从先前的选择。
            final TextSelection? fromSelection = renderEditable.hasFocus
                ? null
                : const TextSelection.collapsed(offset: 0);
            _expandSelection(
              details.globalPosition,
              SelectionChangedCause.tap,
              fromSelection,
            );
            return;
          }
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
              // 精确设备应将光标放在精确位置（如果文本位置的单词没有拼写错误）。
              renderEditable.selectPosition(cause: SelectionChangedCause.tap);
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              // 如果点击的单词拼写错误，选择该单词并显示拼写检查建议工具栏一次。
              // 如果在拼写错误的单词上进行额外点击，则切换工具栏。
              // 如果单词没有拼写错误，默认行为如下：
              //
              // 如果 `previousSelection` 已折叠，点击在选择上，TextAffinity 保持不变，
              // 并且可编辑字段已聚焦，则切换工具栏。
              // 当光标位于换行边界时，TextAffinity 很重要，如果亲和力不同（即它是下游），
              // 选择应移动到下一行，而不是切换工具栏。
              //
              // 当点击完全在非折叠 `previousSelection` 的边界内，并且可编辑字段已聚焦时，切换工具栏。
              //
              // 当可编辑字段未聚焦时，或者如果点击既不完全也不包含在 `previousSelection` 上时，
              // 选择最接近点击的单词边缘。
              // 如果选择在选择单词边缘后保持不变，则我们切换工具栏。
              // 如果选择发生变化，则我们隐藏工具栏。
              final TextSelection previousSelection =
                  renderEditable.selection ??
                      editableText.textEditingValue.selection;
              final TextPosition textPosition =
                  renderEditable.getPositionForPoint(details.globalPosition);
              final bool isAffinityTheSame =
                  textPosition.affinity == previousSelection.affinity;
              final bool wordAtCursorIndexIsMisspelled = editableText
                      .findSuggestionSpanAtCursorIndex(textPosition.offset) !=
                  null;

              if (wordAtCursorIndexIsMisspelled) {
                renderEditable.selectWord(cause: SelectionChangedCause.tap);
                if (previousSelection !=
                    editableText.textEditingValue.selection) {
                  editableText.showSpellCheckSuggestionsToolbar();
                } else {
                  editableText.toggleToolbar(false);
                }
              } else if (((_positionWasOnSelectionExclusive(textPosition) &&
                          !previousSelection.isCollapsed) ||
                      (_positionWasOnSelectionInclusive(textPosition) &&
                          previousSelection.isCollapsed &&
                          isAffinityTheSame)) &&
                  renderEditable.hasFocus) {
                editableText.toggleToolbar(false);
              } else {
                renderEditable.selectWordEdge(cause: SelectionChangedCause.tap);
                if (previousSelection ==
                        editableText.textEditingValue.selection &&
                    renderEditable.hasFocus) {
                  editableText.toggleToolbar(false);
                } else {
                  editableText.hideToolbar(false);
                }
              }
          }
      }
    }
  }

  /// [TextSelectionGestureDetector.onSingleTapCancel] 的处理程序。
  ///
  /// 默认情况下，它作为占位符以启用子类覆盖。
  ///
  /// 另请参阅：
  ///
  ///  * [TextSelectionGestureDetector.onSingleTapCancel]，它触发此回调。
  @protected
  void onSingleTapCancel() {
    /* Subclass should override this method if needed. */
  }

  /// [TextSelectionGestureDetector.onSingleLongTapStart] 的处理程序。
  ///
  /// 默认情况下，如果启用了选择，它会选择 [details] 中指定的文本位置。
  ///
  /// 另请参阅：
  ///
  ///  * [TextSelectionGestureDetector.onSingleLongTapStart]，它触发此回调。
  @protected
  void onSingleLongTapStart(LongPressStartDetails details) {
    if (delegate.selectionEnabled) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          if (!renderEditable.hasFocus) {
            _longPressStartedWithoutFocus = true;
            renderEditable.selectWord(cause: SelectionChangedCause.longPress);
          } else {
            renderEditable.selectPositionAt(
              from: details.globalPosition,
              cause: SelectionChangedCause.longPress,
            );
          }
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          renderEditable.selectWord(cause: SelectionChangedCause.longPress);
      }

      _showMagnifierIfSupportedByPlatform(details.globalPosition);

      _dragStartViewportOffset = renderEditable.offset.pixels;
      _dragStartScrollOffset = _scrollPosition;
    }
  }

  /// [TextSelectionGestureDetector.onSingleLongTapMoveUpdate] 的处理程序。
  ///
  /// 默认情况下，如果启用了选择，它会更新 [details] 中指定的选择位置。
  ///
  /// 另请参阅：
  ///
  ///  * [TextSelectionGestureDetector.onSingleLongTapMoveUpdate]，它触发此回调。
  @protected
  void onSingleLongTapMoveUpdate(LongPressMoveUpdateDetails details) {
    if (delegate.selectionEnabled) {
      // 调整拖动开始偏移以适应可能的视口偏移变化。
      final Offset editableOffset = renderEditable.maxLines == 1
          ? Offset(renderEditable.offset.pixels - _dragStartViewportOffset, 0.0)
          : Offset(
              0.0, renderEditable.offset.pixels - _dragStartViewportOffset);
      final Offset scrollableOffset = Offset(
        0.0,
        _scrollPosition - _dragStartScrollOffset,
      );

      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          if (_longPressStartedWithoutFocus) {
            renderEditable.selectWordsInRange(
              from: details.globalPosition -
                  details.offsetFromOrigin -
                  editableOffset -
                  scrollableOffset,
              to: details.globalPosition,
              cause: SelectionChangedCause.longPress,
            );
          } else {
            renderEditable.selectPositionAt(
              from: details.globalPosition,
              cause: SelectionChangedCause.longPress,
            );
          }
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          renderEditable.selectWordsInRange(
            from: details.globalPosition -
                details.offsetFromOrigin -
                editableOffset -
                scrollableOffset,
            to: details.globalPosition,
            cause: SelectionChangedCause.longPress,
          );
      }

      _showMagnifierIfSupportedByPlatform(details.globalPosition);
    }
  }

  /// [TextSelectionGestureDetector.onSingleLongTapEnd] 的处理程序。
  ///
  /// 默认情况下，它在必要时显示工具栏。
  ///
  /// 另请参阅：
  ///
  ///  * [TextSelectionGestureDetector.onSingleLongTapEnd]，它触发此回调。
  @protected
  void onSingleLongTapEnd(LongPressEndDetails details) {
    _hideMagnifierIfSupportedByPlatform();
    if (shouldShowSelectionToolbar) {
      editableText.showToolbar();
    }
    _longPressStartedWithoutFocus = false;
    _dragStartViewportOffset = 0.0;
    _dragStartScrollOffset = 0.0;
  }

  /// [TextSelectionGestureDetector.onSecondaryTap] 的处理程序。
  ///
  /// 默认情况下，如果可能，选择单词并显示工具栏。
  @protected
  void onSecondaryTap() {
    if (!delegate.selectionEnabled) {
      return;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        if (!_lastSecondaryTapWasOnSelection || !renderEditable.hasFocus) {
          renderEditable.selectWord(cause: SelectionChangedCause.tap);
        }
        if (shouldShowSelectionToolbar) {
          editableText.hideToolbar();
          editableText.showToolbar();
        }
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        if (!renderEditable.hasFocus) {
          renderEditable.selectPosition(cause: SelectionChangedCause.tap);
        }
        editableText.toggleToolbar();
    }
  }

  /// [TextSelectionGestureDetector.onSecondaryTapDown] 的处理程序。
  ///
  /// 另请参阅：
  ///
  ///  * [TextSelectionGestureDetector.onSecondaryTapDown]，它触发此回调。
  ///  * [onSecondaryTap]，通常在此之后调用。
  @protected
  void onSecondaryTapDown(TapDownDetails details) {
    renderEditable.handleSecondaryTapDown(
        TapDownDetails(globalPosition: details.globalPosition));
    _shouldShowSelectionToolbar = true;
  }

  /// [TextSelectionGestureDetector.onDoubleTapDown] 的处理程序。
  ///
  /// 默认情况下，如果 selectionEnabled，它通过 [MongolRenderEditable.selectWord] 选择一个单词，并在必要时显示工具栏。
  ///
  /// 另请参阅：
  ///
  ///  * [TextSelectionGestureDetector.onDoubleTapDown]，它触发此回调。
  @protected
  void onDoubleTapDown(TapDragDownDetails details) {
    if (delegate.selectionEnabled) {
      renderEditable.selectWord(cause: SelectionChangedCause.doubleTap);
      if (shouldShowSelectionToolbar) {
        editableText.showToolbar();
      }
    }
  }

  // 选择文档中与给定全局位置范围相交的段落集。
  void _selectParagraphsInRange(
      {required Offset from, Offset? to, SelectionChangedCause? cause}) {
    final TextBoundary paragraphBoundary =
        ParagraphBoundary(editableText.textEditingValue.text);
    _selectTextBoundariesInRange(
        boundary: paragraphBoundary, from: from, to: to, cause: cause);
  }

  // Selects the set of lines in a document that intersect a given range of
  // global positions.
  void _selectLinesInRange(
      {required Offset from, Offset? to, SelectionChangedCause? cause}) {
    final TextBoundary lineBoundary = LineBoundary(renderEditable);
    _selectTextBoundariesInRange(
        boundary: lineBoundary, from: from, to: to, cause: cause);
  }

  // Returns the closest boundary location to `extent` but not including `extent`
  // itself.
  TextRange _moveBeyondTextBoundary(
      TextPosition extent, TextBoundary textBoundary) {
    assert(extent.offset >= 0);
    // if x is a boundary defined by `textBoundary`, most textBoundaries (except
    // LineBreaker) guarantees `x == textBoundary.getLeadingTextBoundaryAt(x)`.
    // Use x - 1 here to make sure we don't get stuck at the fixed point x.
    final int start =
        textBoundary.getLeadingTextBoundaryAt(extent.offset - 1) ?? 0;
    final int end = textBoundary.getTrailingTextBoundaryAt(extent.offset) ??
        editableText.textEditingValue.text.length;
    return TextRange(start: start, end: end);
  }

  // Selects the set of text boundaries in a document that intersect a given
  // range of global positions.
  //
  // The set of text boundaries selected are not strictly bounded by the range
  // of global positions.
  //
  // The first and last endpoints of the selection will always be at the
  // beginning and end of a text boundary respectively.
  void _selectTextBoundariesInRange(
      {required TextBoundary boundary,
      required Offset from,
      Offset? to,
      SelectionChangedCause? cause}) {
    final TextPosition fromPosition = renderEditable.getPositionForPoint(from);
    final TextRange fromRange = _moveBeyondTextBoundary(fromPosition, boundary);
    final TextPosition toPosition =
        to == null ? fromPosition : renderEditable.getPositionForPoint(to);
    final TextRange toRange = toPosition == fromPosition
        ? fromRange
        : _moveBeyondTextBoundary(toPosition, boundary);
    final bool isFromBoundaryBeforeToBoundary = fromRange.start < toRange.end;

    final TextSelection newSelection = isFromBoundaryBeforeToBoundary
        ? TextSelection(baseOffset: fromRange.start, extentOffset: toRange.end)
        : TextSelection(baseOffset: fromRange.end, extentOffset: toRange.start);

    editableText.userUpdateTextEditingValue(
      editableText.textEditingValue.copyWith(selection: newSelection),
      cause,
    );
  }

  /// Handler for [TextSelectionGestureDetector.onTripleTapDown].
  ///
  /// By default, it selects a paragraph if
  /// [TextSelectionGestureDetectorBuilderDelegate.selectionEnabled] is true
  /// and shows the toolbar if necessary.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onTripleTapDown], which triggers this
  ///    callback.
  @protected
  void onTripleTapDown(TapDragDownDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }
    if (renderEditable.maxLines == 1) {
      editableText.selectAll(SelectionChangedCause.tap);
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          _selectParagraphsInRange(
              from: details.globalPosition, cause: SelectionChangedCause.tap);
        case TargetPlatform.linux:
          _selectLinesInRange(
              from: details.globalPosition, cause: SelectionChangedCause.tap);
      }
    }
    if (shouldShowSelectionToolbar) {
      editableText.showToolbar();
    }
  }

  /// Handler for [TextSelectionGestureDetector.onDragSelectionStart].
  ///
  /// By default, it selects a text position specified in [details].
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onDragSelectionStart], which triggers
  ///    this callback.
  @protected
  void onDragSelectionStart(TapDragStartDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }
    final PointerDeviceKind? kind = details.kind;
    _shouldShowSelectionToolbar = kind == null ||
        kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus;

    _dragStartSelection = renderEditable.selection;
    _dragStartScrollOffset = _scrollPosition;
    _dragStartViewportOffset = renderEditable.offset.pixels;
    _dragBeganOnPreviousSelection =
        _positionOnSelection(details.globalPosition, _dragStartSelection);

    if (_TextSelectionGestureDetectorState._getEffectiveConsecutiveTapCount(
            details.consecutiveTapCount) >
        1) {
      // Do not set the selection on a consecutive tap and drag.
      return;
    }

    if (_isShiftPressed &&
        renderEditable.selection != null &&
        renderEditable.selection!.isValid) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          _expandSelection(details.globalPosition, SelectionChangedCause.drag);
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          _extendSelection(details.globalPosition, SelectionChangedCause.drag);
      }
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
              renderEditable.selectPositionAt(
                from: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              // For iOS platforms, a touch drag does not initiate unless the
              // editable has focus and the drag began on the previous selection.
              assert(_dragBeganOnPreviousSelection != null);
              if (renderEditable.hasFocus && _dragBeganOnPreviousSelection!) {
                renderEditable.selectPositionAt(
                  from: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
                _showMagnifierIfSupportedByPlatform(details.globalPosition);
              }
            case null:
          }
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
              renderEditable.selectPositionAt(
                from: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              // For Android, Fucshia, and iOS platforms, a touch drag
              // does not initiate unless the editable has focus.
              if (renderEditable.hasFocus) {
                renderEditable.selectPositionAt(
                  from: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
                _showMagnifierIfSupportedByPlatform(details.globalPosition);
              }
            case null:
          }
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          renderEditable.selectPositionAt(
            from: details.globalPosition,
            cause: SelectionChangedCause.drag,
          );
      }
    }
  }

  /// Handler for [TextSelectionGestureDetector.onDragSelectionUpdate].
  ///
  /// By default, it updates the selection location specified in the provided
  /// details objects.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onDragSelectionUpdate], which triggers
  ///    this callback./lib/src/material/text_field.dart
  @protected
  void onDragSelectionUpdate(TapDragUpdateDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }

    if (!_isShiftPressed) {
      // Adjust the drag start offset for possible viewport offset changes.
      final Offset editableOffset = renderEditable.maxLines == 1
          ? Offset(renderEditable.offset.pixels - _dragStartViewportOffset, 0.0)
          : Offset(
              0.0, renderEditable.offset.pixels - _dragStartViewportOffset);
      final Offset scrollableOffset = Offset(
        0.0,
        _scrollPosition - _dragStartScrollOffset,
      );
      final Offset dragStartGlobalPosition =
          details.globalPosition - details.offsetFromOrigin;

      // Select word by word.
      if (_TextSelectionGestureDetectorState._getEffectiveConsecutiveTapCount(
              details.consecutiveTapCount) ==
          2) {
        renderEditable.selectWordsInRange(
          from: dragStartGlobalPosition - editableOffset - scrollableOffset,
          to: details.globalPosition,
          cause: SelectionChangedCause.drag,
        );

        switch (details.kind) {
          case PointerDeviceKind.stylus:
          case PointerDeviceKind.invertedStylus:
          case PointerDeviceKind.touch:
          case PointerDeviceKind.unknown:
            return _showMagnifierIfSupportedByPlatform(details.globalPosition);
          case PointerDeviceKind.mouse:
          case PointerDeviceKind.trackpad:
          case null:
            return;
        }
      }

      // Select paragraph-by-paragraph.
      if (_TextSelectionGestureDetectorState._getEffectiveConsecutiveTapCount(
              details.consecutiveTapCount) ==
          3) {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.iOS:
            switch (details.kind) {
              case PointerDeviceKind.mouse:
              case PointerDeviceKind.trackpad:
                return _selectParagraphsInRange(
                  from: dragStartGlobalPosition -
                      editableOffset -
                      scrollableOffset,
                  to: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
              case PointerDeviceKind.stylus:
              case PointerDeviceKind.invertedStylus:
              case PointerDeviceKind.touch:
              case PointerDeviceKind.unknown:
              case null:
                // Triple tap to drag is not present on these platforms when using
                // non-precise pointer devices at the moment.
                break;
            }
            return;
          case TargetPlatform.linux:
            return _selectLinesInRange(
              from: dragStartGlobalPosition - editableOffset - scrollableOffset,
              to: details.globalPosition,
              cause: SelectionChangedCause.drag,
            );
          case TargetPlatform.windows:
          case TargetPlatform.macOS:
            return _selectParagraphsInRange(
              from: dragStartGlobalPosition - editableOffset - scrollableOffset,
              to: details.globalPosition,
              cause: SelectionChangedCause.drag,
            );
        }
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          // With a touch device, nothing should happen, unless there was a double tap, or
          // there was a collapsed selection, and the tap/drag position is at the collapsed selection.
          // In that case the caret should move with the drag position.
          //
          // With a mouse device, a drag should select the range from the origin of the drag
          // to the current position of the drag.
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
              return renderEditable.selectPositionAt(
                from:
                    dragStartGlobalPosition - editableOffset - scrollableOffset,
                to: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              assert(_dragBeganOnPreviousSelection != null);
              if (renderEditable.hasFocus &&
                  _dragStartSelection!.isCollapsed &&
                  _dragBeganOnPreviousSelection!) {
                renderEditable.selectPositionAt(
                  from: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
                return _showMagnifierIfSupportedByPlatform(
                    details.globalPosition);
              }
            case null:
              break;
          }
          return;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          // With a precise pointer device, such as a mouse, trackpad, or stylus,
          // the drag will select the text spanning the origin of the drag to the end of the drag.
          // With a touch device, the cursor should move with the drag.
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
              return renderEditable.selectPositionAt(
                from:
                    dragStartGlobalPosition - editableOffset - scrollableOffset,
                to: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              if (renderEditable.hasFocus) {
                renderEditable.selectPositionAt(
                  from: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
                return _showMagnifierIfSupportedByPlatform(
                    details.globalPosition);
              }
            case null:
              break;
          }
          return;
        case TargetPlatform.macOS:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          return renderEditable.selectPositionAt(
            from: dragStartGlobalPosition - editableOffset - scrollableOffset,
            to: details.globalPosition,
            cause: SelectionChangedCause.drag,
          );
      }
    }

    if (_dragStartSelection!.isCollapsed ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      return _extendSelection(
          details.globalPosition, SelectionChangedCause.drag);
    }

    // If the drag inverts the selection, Mac and iOS revert to the initial
    // selection.
    final TextSelection selection = editableText.textEditingValue.selection;
    final TextPosition nextExtent =
        renderEditable.getPositionForPoint(details.globalPosition);
    final bool isShiftTapDragSelectionForward =
        _dragStartSelection!.baseOffset < _dragStartSelection!.extentOffset;
    final bool isInverted = isShiftTapDragSelectionForward
        ? nextExtent.offset < _dragStartSelection!.baseOffset
        : nextExtent.offset > _dragStartSelection!.baseOffset;
    if (isInverted && selection.baseOffset == _dragStartSelection!.baseOffset) {
      editableText.userUpdateTextEditingValue(
        editableText.textEditingValue.copyWith(
          selection: TextSelection(
            baseOffset: _dragStartSelection!.extentOffset,
            extentOffset: nextExtent.offset,
          ),
        ),
        SelectionChangedCause.drag,
      );
    } else if (!isInverted &&
        nextExtent.offset != _dragStartSelection!.baseOffset &&
        selection.baseOffset != _dragStartSelection!.baseOffset) {
      editableText.userUpdateTextEditingValue(
        editableText.textEditingValue.copyWith(
          selection: TextSelection(
            baseOffset: _dragStartSelection!.baseOffset,
            extentOffset: nextExtent.offset,
          ),
        ),
        SelectionChangedCause.drag,
      );
    } else {
      _extendSelection(details.globalPosition, SelectionChangedCause.drag);
    }
  }

  /// Handler for [TextSelectionGestureDetector.onDragSelectionEnd].
  ///
  /// By default, it cleans up the state used for handling certain
  /// built-in behaviors.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onDragSelectionEnd], which triggers this
  ///    callback.
  @protected
  void onDragSelectionEnd(TapDragEndDetails details) {
    _dragBeganOnPreviousSelection = null;

    if (_shouldShowSelectionToolbar &&
        _TextSelectionGestureDetectorState._getEffectiveConsecutiveTapCount(
                details.consecutiveTapCount) ==
            2) {
      editableText.showToolbar();
    }

    if (_isShiftPressed) {
      _dragStartSelection = null;
    }

    _hideMagnifierIfSupportedByPlatform();
  }

  /// Returns a [TextSelectionGestureDetector] configured with the handlers
  /// provided by this builder.
  ///
  /// The [child] or its subtree should contain [EditableText].
  Widget buildGestureDetector({
    Key? key,
    HitTestBehavior? behavior,
    required Widget child,
  }) {
    return TextSelectionGestureDetector(
      key: key,
      onTapDown: onTapDown,
      onForcePressStart: delegate.forcePressEnabled ? onForcePressStart : null,
      onForcePressEnd: delegate.forcePressEnabled ? onForcePressEnd : null,
      onSecondaryTap: onSecondaryTap,
      onSecondaryTapDown: onSecondaryTapDown,
      onSingleTapUp: onSingleTapUp,
      onSingleTapCancel: onSingleTapCancel,
      onSingleLongTapStart: onSingleLongTapStart,
      onSingleLongTapMoveUpdate: onSingleLongTapMoveUpdate,
      onSingleLongTapEnd: onSingleLongTapEnd,
      onDoubleTapDown: onDoubleTapDown,
      onTripleTapDown: onTripleTapDown,
      onDragSelectionStart: onDragSelectionStart,
      onDragSelectionUpdate: onDragSelectionUpdate,
      onDragSelectionEnd: onDragSelectionEnd,
      behavior: behavior,
      child: child,
    );
  }
}

/// An object that manages a pair of selection handles and a toolbar.
///
/// The selection handles are displayed in the [Overlay] that most closely
/// encloses the given [BuildContext].
