part of '../mongol_text_selection.dart';

class MongolTextSelectionOverlay {
  /// 创建一个管理选择手柄覆盖项的对象。
  ///
  /// [context] 不能为空，并且必须有一个 [Overlay] 作为祖先。
  ///
  /// 参数：
  /// - value: 文本编辑值
  /// - context: 构建上下文
  /// - debugRequiredFor: 调试所需的小部件
  /// - toolbarLayerLink: 工具栏层链接
  /// - startHandleLayerLink: 开始手柄层链接
  /// - endHandleLayerLink: 结束手柄层链接
  /// - renderObject: 渲染对象
  /// - selectionControls: 选择控件
  /// - handlesVisible: 手柄是否可见，默认为 false
  /// - selectionDelegate: 选择委托
  /// - dragStartBehavior: 拖动开始行为，默认为 DragStartBehavior.start
  /// - onSelectionHandleTapped: 选择手柄点击回调
  /// - clipboardStatus: 剪贴板状态通知器
  /// - contextMenuBuilder: 上下文菜单构建器
  /// - magnifierConfiguration: 放大镜配置
  MongolTextSelectionOverlay({
    required TextEditingValue value,
    required this.context,
    Widget? debugRequiredFor,
    required LayerLink toolbarLayerLink,
    required LayerLink startHandleLayerLink,
    required LayerLink endHandleLayerLink,
    required this.renderObject,
    this.selectionControls,
    bool handlesVisible = false,
    required this.selectionDelegate,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    VoidCallback? onSelectionHandleTapped,
    ClipboardStatusNotifier? clipboardStatus,
    this.contextMenuBuilder,
    required TextMagnifierConfiguration magnifierConfiguration,
  })  : _handlesVisible = handlesVisible,
        _value = value {
    renderObject.selectionStartInViewport
        .addListener(_updateTextSelectionOverlayVisibilities);
    renderObject.selectionEndInViewport
        .addListener(_updateTextSelectionOverlayVisibilities);
    _updateTextSelectionOverlayVisibilities();
    _selectionOverlay = MongolSelectionOverlay(
      magnifierConfiguration: magnifierConfiguration,
      context: context,
      debugRequiredFor: debugRequiredFor,
      // 指标将在显示手柄时设置
      startHandleType: TextSelectionHandleType.collapsed,
      startHandlesVisible: _effectiveStartHandleVisibility,
      lineWidthAtStart: 0.0,
      onStartHandleDragStart: _handleSelectionStartHandleDragStart,
      onStartHandleDragUpdate: _handleSelectionStartHandleDragUpdate,
      onEndHandleDragEnd: _handleAnyDragEnd,
      endHandleType: TextSelectionHandleType.collapsed,
      endHandlesVisible: _effectiveEndHandleVisibility,
      lineWidthAtEnd: 0.0,
      onEndHandleDragStart: _handleSelectionEndHandleDragStart,
      onEndHandleDragUpdate: _handleSelectionEndHandleDragUpdate,
      onStartHandleDragEnd: _handleAnyDragEnd,
      toolbarVisible: _effectiveToolbarVisibility,
      selectionEndpoints: const <TextSelectionPoint>[],
      selectionControls: selectionControls,
      selectionDelegate: selectionDelegate,
      clipboardStatus: clipboardStatus,
      startHandleLayerLink: startHandleLayerLink,
      endHandleLayerLink: endHandleLayerLink,
      toolbarLayerLink: toolbarLayerLink,
      onSelectionHandleTapped: onSelectionHandleTapped,
      dragStartBehavior: dragStartBehavior,
      toolbarLocation: renderObject.lastSecondaryTapDownPosition,
    );
  }

  /// 选择手柄应该出现的上下文。
  ///
  /// 此上下文必须有一个 [Overlay] 作为祖先，因为此对象
  /// 将在该 [Overlay] 中显示文本选择手柄。
  final BuildContext context;

  /// 控制工具栏和手柄的淡入淡出动画。
  @Deprecated('Use `SelectionOverlay.fadeDuration` instead. '
      'This feature was deprecated after v2.12.0-4.1.pre.')
  static const Duration fadeDuration = SelectionOverlay.fadeDuration;

  /// 显示所选文本的可编辑行。
  final MongolRenderEditable renderObject;

  /// 构建文本选择手柄和工具栏。
  final TextSelectionControls? selectionControls;

  /// 用于操作所属文本字段中当前选择的委托。
  final TextSelectionDelegate selectionDelegate;

  late final MongolSelectionOverlay _selectionOverlay;

  /// 在用户请求时构建文本选择工具栏。
  ///
  /// `primaryAnchor` 是上下文菜单的期望锚点位置，而
  /// `secondaryAnchor` 是如果菜单不适合时的回退位置。
  ///
  /// `buttonItems` 表示默认为此小部件构建的按钮。
  ///
  /// 如果未提供，则不会构建上下文菜单。
  final WidgetBuilder? contextMenuBuilder;

  /// 获取当前值。
  @visibleForTesting
  TextEditingValue get value => _value;

  TextEditingValue _value;

  TextSelection get _selection => _value.selection;

  final ValueNotifier<bool> _effectiveStartHandleVisibility =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> _effectiveEndHandleVisibility =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> _effectiveToolbarVisibility =
      ValueNotifier<bool>(false);

  void _updateTextSelectionOverlayVisibilities() {
    _effectiveStartHandleVisibility.value =
        _handlesVisible && renderObject.selectionStartInViewport.value;
    _effectiveEndHandleVisibility.value =
        _handlesVisible && renderObject.selectionEndInViewport.value;
    _effectiveToolbarVisibility.value =
        renderObject.selectionStartInViewport.value ||
            renderObject.selectionEndInViewport.value;
  }

  /// 选择手柄是否可见。
  ///
  /// 如果要隐藏手柄，设置为 false。使用此属性显示或
  /// 隐藏手柄而无需重建它们。
  ///
  /// 默认为 false。
  bool get handlesVisible => _handlesVisible;
  bool _handlesVisible = false;
  set handlesVisible(bool visible) {
    if (_handlesVisible == visible) {
      return;
    }
    _handlesVisible = visible;
    _updateTextSelectionOverlayVisibilities();
  }

  /// 通过将手柄插入到 [context] 的覆盖层中来构建手柄。
  void showHandles() {
    _updateSelectionOverlay();
    _selectionOverlay.showHandles();
  }

  /// 通过从覆盖层中删除手柄来销毁手柄。
  void hideHandles() => _selectionOverlay.hideHandles();

  /// 通过将工具栏插入到 [context] 的覆盖层中来显示工具栏。
  void showToolbar() {
    _updateSelectionOverlay();

    if (selectionControls is! TextSelectionHandleControls) {
      _selectionOverlay.showToolbar();
      return;
    }

    if (contextMenuBuilder == null) {
      return;
    }

    assert(context.mounted);
    _selectionOverlay.showToolbar(
      context: context,
      contextMenuBuilder: contextMenuBuilder,
    );
    return;
  }

  /// 显示放大镜，如果调用 [showMagnifier] 时工具栏正在显示，则隐藏工具栏。
  /// 这在非移动平台上调用是安全的，
  /// 因为不会提供 magnifierBuilder，或者 magnifierBuilder
  /// 在非移动平台上会返回 null。
  ///
  /// 这不是放大镜是否打开的真实来源，
  /// 因为放大镜可能会自行隐藏。如果需要此信息，请检查
  /// [MagnifierController.shown]。
  void showMagnifier(Offset positionToShow) {
    final TextPosition position =
        renderObject.getPositionForPoint(positionToShow);
    _updateSelectionOverlay();
    _selectionOverlay.showMagnifier(
      _buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: positionToShow,
        renderEditable: renderObject,
      ),
    );
  }

  /// 用新的选择数据更新当前放大镜，以便放大镜
  /// 可以相应地响应。
  ///
  /// 如果放大镜未显示，这仍会更新放大镜位置
  /// 因为放大镜可能已自行隐藏并正在寻找提示以
  /// 重新显示自己。
  ///
  /// 如果覆盖层中没有放大镜，这将不执行任何操作。
  void updateMagnifier(Offset positionToShow) {
    final TextPosition position =
        renderObject.getPositionForPoint(positionToShow);
    _updateSelectionOverlay();
    _selectionOverlay.updateMagnifier(
      _buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: positionToShow,
        renderEditable: renderObject,
      ),
    );
  }

  /// 隐藏当前放大镜。
  ///
  /// 如果没有放大镜，这将不执行任何操作。
  void hideMagnifier() {
    _selectionOverlay.hideMagnifier();
  }

  /// 在选择更改后更新覆盖层。
  ///
  /// 如果在 [SchedulerBinding.schedulerPhase] 为
  /// [SchedulerPhase.persistentCallbacks] 时调用此方法，即
  /// 在构建、布局或绘制阶段（请参阅 [WidgetsBinding.drawFrame]），
  /// 则更新会延迟到帧后回调阶段。否则，更新会同步完成。
  /// 这意味着在构建期间调用是安全的，但也
  /// 意味着如果您在构建期间调用此方法，UI 将不会更新，直到下
  /// 一帧（即几毫秒后）。
  void update(TextEditingValue newValue) {
    if (_value == newValue) {
      return;
    }
    _value = newValue;
    _updateSelectionOverlay();
    // 即使文本已更改，如果文本指标和选择没有更改，_updateSelectionOverlay 可能不会重建选择覆盖层。
    // 此重建是工具栏基于最新文本值更新所必需的。
    _selectionOverlay.markNeedsBuild();
  }

  void _updateSelectionOverlay() {
    // 使用选择委托的当前值，以便即使覆盖层刚创建（update() 尚未调用），我们也有正确的选择。
    final bool selectionCollapsed =
        selectionDelegate.textEditingValue.selection.isCollapsed;
    _selectionOverlay
      // 更新选择手柄指标。
      ..startHandleType = selectionCollapsed
          ? TextSelectionHandleType.collapsed
          : TextSelectionHandleType.left
      ..lineWidthAtStart = _getStartGlyphWidth()
      ..endHandleType = selectionCollapsed
          ? TextSelectionHandleType.collapsed
          : TextSelectionHandleType.right
      ..lineWidthAtEnd = _getEndGlyphWidth()
      // 更新选择工具栏指标。
      ..selectionEndpoints = renderObject.getEndpointsForSelection(_selection)
      ..toolbarLocation = renderObject.lastSecondaryTapDownPosition;
  }

  /// 使覆盖层更新其渲染。
  ///
  /// 这旨在在 [renderObject] 可能已更改其
  /// 文本指标时调用（例如，因为文本已滚动）。
  void updateForScroll() {
    _updateSelectionOverlay();
    // 此方法可能由于窗口指标更改而调用。在这种情况下，
    // _selectionOverlay 中的任何属性都不会更改，但仍需要重建。
    _selectionOverlay.markNeedsBuild();
  }

  /// 手柄当前是否可见。
  bool get handlesAreVisible =>
      _selectionOverlay._handles != null && handlesVisible;

  /// 工具栏当前是否可见。
  bool get toolbarIsVisible {
    return selectionControls is TextSelectionHandleControls
        ? _selectionOverlay._contextMenuControllerIsShown
        : _selectionOverlay._toolbar != null;
  }

  /// 放大镜当前是否可见。
  bool get magnifierIsVisible => _selectionOverlay._magnifierController.shown;

  /// 隐藏整个覆盖层，包括工具栏和手柄。
  void hide() => _selectionOverlay.hide();

  /// 隐藏覆盖层的工具栏部分。
  ///
  /// 要隐藏整个覆盖层，请参阅 [hide]。
  void hideToolbar() => _selectionOverlay.hideToolbar();

  /// 最终清理。
  void dispose() {
    _selectionOverlay.dispose();
    renderObject.selectionStartInViewport
        .removeListener(_updateTextSelectionOverlayVisibilities);
    renderObject.selectionEndInViewport
        .removeListener(_updateTextSelectionOverlayVisibilities);
    _effectiveToolbarVisibility.dispose();
    _effectiveStartHandleVisibility.dispose();
    _effectiveEndHandleVisibility.dispose();
    hideToolbar();
  }

  // 这里的"宽度"指的是垂直线中的字形宽度。
  // 在非旋转方向上，它将是字形的高度。
  double _getStartGlyphWidth() {
    final String currText = selectionDelegate.textEditingValue.text;
    final int firstSelectedGraphemeExtent;
    Rect? startHandleRect;
    // 仅当先前帧中的文本与当前帧中的文本相同时才计算手柄矩形。
    // 这样做是因为 widget.renderObject 包含来自先前帧的 renderEditable。
    // 如果当前帧和先前帧之间的文本发生变化，则
    // widget.renderObject.getRectForComposingRange 可能会失败。
    // 在当前帧与先前帧不同的情况下，我们回退到 renderObject.preferredLineWidth。
    if (renderObject.plainText == currText &&
        _selection.isValid &&
        !_selection.isCollapsed) {
      final String selectedGraphemes = _selection.textInside(currText);
      firstSelectedGraphemeExtent = selectedGraphemes.characters.first.length;
      startHandleRect = renderObject.getRectForComposingRange(TextRange(
          start: _selection.start,
          end: _selection.start + firstSelectedGraphemeExtent));
    }
    return startHandleRect?.width ?? renderObject.preferredLineWidth;
  }

  // 这里的"宽度"指的是垂直线中的字形宽度。
  // 在非旋转方向上，它将是字形的高度。
  double _getEndGlyphWidth() {
    final String currText = selectionDelegate.textEditingValue.text;
    final int lastSelectedGraphemeExtent;
    Rect? endHandleRect;
    // 请参阅 _getStartGlyphWidth 中的解释。
    if (renderObject.plainText == currText &&
        _selection.isValid &&
        !_selection.isCollapsed) {
      final String selectedGraphemes = _selection.textInside(currText);
      lastSelectedGraphemeExtent = selectedGraphemes.characters.last.length;
      endHandleRect = renderObject.getRectForComposingRange(TextRange(
          start: _selection.end - lastSelectedGraphemeExtent,
          end: _selection.end));
    }
    return endHandleRect?.width ?? renderObject.preferredLineWidth;
  }

  MagnifierInfo _buildMagnifier({
    required MongolRenderEditable renderEditable,
    required Offset globalGesturePosition,
    required TextPosition currentTextPosition,
  }) {
    final Offset globalRenderEditableTopLeft =
        renderEditable.localToGlobal(Offset.zero);
    final Rect localCaretRect =
        renderEditable.getLocalRectForCaret(currentTextPosition);

    final TextSelection lineAtOffset =
        renderEditable.getLineAtOffset(currentTextPosition);
    final TextPosition positionAtEndOfLine = TextPosition(
      offset: lineAtOffset.extentOffset,
      affinity: TextAffinity.upstream,
    );

    // 默认亲和力是下游。
    final TextPosition positionAtBeginningOfLine = TextPosition(
      offset: lineAtOffset.baseOffset,
    );

    final Rect lineBoundaries = Rect.fromPoints(
      renderEditable.getLocalRectForCaret(positionAtBeginningOfLine).centerLeft,
      renderEditable.getLocalRectForCaret(positionAtEndOfLine).centerRight,
    );

    return MagnifierInfo(
      fieldBounds: globalRenderEditableTopLeft & renderEditable.size,
      globalGesturePosition: globalGesturePosition,
      caretRect: localCaretRect.shift(globalRenderEditableTopLeft),
      currentLineBoundaries: lineBoundaries.shift(globalRenderEditableTopLeft),
    );
  }

  // 手势在当前结束手柄位置的接触位置。
  // 当手柄移动时更新。
  late double _endHandleDragPosition;

  // 从 _endHandleDragPosition 到它对应的线的中心的距离。
  late double _endHandleDragPositionToCenterOfLine;

  double _handleCenterDx({required bool isEnd}) {
    final Offset handlePoint = renderObject.localToGlobal(
      isEnd
          ? _selectionOverlay.selectionEndpoints.last.point
          : _selectionOverlay.selectionEndpoints.first.point,
    );
    return handlePoint.dx - renderObject.preferredLineWidth / 2;
  }

  void _showMagnifierAt({
    required TextPosition position,
    required Offset globalGesturePosition,
  }) {
    _selectionOverlay.showMagnifier(
      _buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: globalGesturePosition,
        renderEditable: renderObject,
      ),
    );
  }

  void _updateMagnifierAt({
    required TextPosition position,
    required Offset globalGesturePosition,
  }) {
    _selectionOverlay.updateMagnifier(
      _buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: globalGesturePosition,
        renderEditable: renderObject,
      ),
    );
  }

  TextSelection? _selectionForHandleDrag({
    required bool isEnd,
    required TextPosition position,
  }) {
    if (_selection.isCollapsed) {
      return TextSelection.fromPosition(position);
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        if (isEnd) {
          if (position.offset <= _selection.start) {
            return null;
          }
          return TextSelection(
            extentOffset: position.offset,
            baseOffset: _selection.start,
          );
        }

        if (position.offset >= _selection.end) {
          return null;
        }
        return TextSelection(
          extentOffset: position.offset,
          baseOffset: _selection.end,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        final TextSelection candidate = isEnd
            ? TextSelection(
                baseOffset: _selection.baseOffset,
                extentOffset: position.offset,
              )
            : TextSelection(
                baseOffset: position.offset,
                extentOffset: _selection.extentOffset,
              );
        if (candidate.baseOffset >= candidate.extentOffset) {
          return null;
        }
        return candidate;
    }
  }

  void _handleSelectionEndHandleDragStart(DragStartDetails details) {
    if (!renderObject.attached) {
      return;
    }

    // 这是为了调整选择手柄可能不完全覆盖它们对应的 TextPosition 的事实。
    _endHandleDragPosition = details.globalPosition.dx;
    final double centerOfLine = _handleCenterDx(isEnd: true);
    _endHandleDragPositionToCenterOfLine =
        centerOfLine - _endHandleDragPosition;
    final TextPosition position = renderObject.getPositionForPoint(
      Offset(
        centerOfLine,
        details.globalPosition.dy,
      ),
    );

    _showMagnifierAt(
      position: position,
      globalGesturePosition: details.globalPosition,
    );
  }

  /// 给定手柄位置和拖动位置，返回拖动后手柄的位置。
  ///
  /// 当拖动到达离原始手柄位置一整行宽度的距离时，手柄会在行间立即跳转。
  /// 换句话说，当接触点位于新行上的手柄上与手势开始时相同的位置时，就会发生行跳转。
  double _getHandleDx(double dragDx, double handleDx) {
    final double distanceDragged = dragDx - handleDx;
    final int dragDirection = distanceDragged < 0.0 ? -1 : 1;
    final int linesDragged = dragDirection *
        (distanceDragged.abs() / renderObject.preferredLineWidth).floor();
    return handleDx + linesDragged * renderObject.preferredLineWidth;
  }

  void _handleSelectionEndHandleDragUpdate(DragUpdateDetails details) {
    if (!renderObject.attached) {
      return;
    }

    _endHandleDragPosition =
        _getHandleDx(details.globalPosition.dx, _endHandleDragPosition);
    final Offset adjustedOffset = Offset(
      _endHandleDragPosition + _endHandleDragPositionToCenterOfLine,
      details.globalPosition.dy,
    );

    final TextPosition position =
        renderObject.getPositionForPoint(adjustedOffset);

    final TextSelection? newSelection =
        _selectionForHandleDrag(isEnd: true, position: position);
    if (newSelection == null) {
      return;
    }

    _updateMagnifierAt(
      position: position,
      globalGesturePosition: details.globalPosition,
    );
    _handleSelectionHandleChanged(newSelection, isEnd: true);
  }

  // 手势在当前开始手柄位置的接触位置。
  // 当手柄移动时更新。
  late double _startHandleDragPosition;

  // 从 _startHandleDragPosition 到它对应的线的中心的距离。
  late double _startHandleDragPositionToCenterOfLine;

  void _handleSelectionStartHandleDragStart(DragStartDetails details) {
    if (!renderObject.attached) {
      return;
    }

    // 这是为了调整选择手柄可能不完全覆盖它们对应的 TextPosition 的事实。
    _startHandleDragPosition = details.globalPosition.dx;
    final double centerOfLine = _handleCenterDx(isEnd: false);
    _startHandleDragPositionToCenterOfLine =
        centerOfLine - _startHandleDragPosition;
    final TextPosition position = renderObject.getPositionForPoint(
      Offset(
        centerOfLine,
        details.globalPosition.dy,
      ),
    );

    _showMagnifierAt(
      position: position,
      globalGesturePosition: details.globalPosition,
    );
  }

  void _handleSelectionStartHandleDragUpdate(DragUpdateDetails details) {
    if (!renderObject.attached) {
      return;
    }

    _startHandleDragPosition =
        _getHandleDx(details.globalPosition.dx, _startHandleDragPosition);
    final Offset adjustedOffset = Offset(
      _startHandleDragPosition + _startHandleDragPositionToCenterOfLine,
      details.globalPosition.dy,
    );
    final TextPosition position =
        renderObject.getPositionForPoint(adjustedOffset);

    final TextSelection? newSelection =
        _selectionForHandleDrag(isEnd: false, position: position);
    if (newSelection == null) {
      return;
    }

    _updateMagnifierAt(
      position: position,
      globalGesturePosition: details.globalPosition,
    );
    _handleSelectionHandleChanged(newSelection, isEnd: false);
  }

  void _handleAnyDragEnd(DragEndDetails details) {
    if (!context.mounted) {
      return;
    }
    if (selectionControls is! TextSelectionHandleControls) {
      _selectionOverlay.hideMagnifier();
      if (!_selection.isCollapsed) {
        _selectionOverlay.showToolbar();
      }
      return;
    }
    _selectionOverlay.hideMagnifier();
    if (!_selection.isCollapsed) {
      _selectionOverlay.showToolbar(
        context: context,
        contextMenuBuilder: contextMenuBuilder,
      );
    }
  }

  void _handleSelectionHandleChanged(TextSelection newSelection,
      {required bool isEnd}) {
    final TextPosition textPosition =
        isEnd ? newSelection.extent : newSelection.base;
    selectionDelegate.userUpdateTextEditingValue(
      _value.copyWith(selection: newSelection),
      SelectionChangedCause.drag,
    );
    selectionDelegate.bringIntoView(textPosition);
  }
}

/// [MongolTextSelectionGestureDetectorBuilder] 的委托接口。
///
/// 该接口通常由包装 [MongolEditableText] 的文本字段实现实现，
/// 这些实现使用 [MongolTextSelectionGestureDetectorBuilder] 为其 [MongolEditableText] 构建 [TextSelectionGestureDetector]。
/// 委托向构建器提供有关文本字段当前状态的信息。
/// 基于此信息，构建器向手势检测器添加正确的手势处理程序。
///
/// 另请参阅：
///
///  * [MongolTextField]，它为 Material 文本字段实现此委托。
abstract class MongolTextSelectionGestureDetectorBuilderDelegate {
  /// 指向 [MongolEditableText] 的 [GlobalKey]，
  /// [MongolTextSelectionGestureDetectorBuilder] 将为其构建 [TextSelectionGestureDetector]。
  GlobalKey<MongolEditableTextState> get editableTextKey;

  /// 文本字段是否应该响应强制按压。
  bool get forcePressEnabled;

  /// 用户是否可以在文本字段中选择文本。
  bool get selectionEnabled;
}

/// 构建一个 [TextSelectionGestureDetector] 来包装 [MongolEditableText]。
///
/// 该类为许多与 [MongolEditableText] 的用户交互实现了合理的默认值
/// （请参阅各种手势处理程序方法的文档，例如 [onTapDown]、[onForcePressStart] 等）。
/// [MongolTextSelectionGestureDetectorBuilder] 的子类可以通过覆盖此类的相应处理程序方法来更改响应这些手势事件时执行的行为。
///
/// 通过调用 [buildGestureDetector] 获得包装 [MongolEditableText] 的最终 [TextSelectionGestureDetector]。
///
/// 另请参阅：
///
///  * [MongolTextField]，它使用子类实现 [MongolEditableText] 的 Material 特定手势逻辑。
