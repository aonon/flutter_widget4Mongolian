// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: deprecated_member_use_from_same_package, deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/foundation.dart'
  show ValueListenable, defaultTargetPlatform, kIsWeb, listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show kMinInteractiveDimension;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/services.dart'
    show
        HapticFeedback,
        LineBoundary,
        LogicalKeyboardKey,
        ParagraphBoundary,
        HardwareKeyboard,
        TextBoundary;
export 'package:flutter/services.dart' show TextSelectionDelegate;
import 'package:flutter/widgets.dart';

import '../mongol_editable_text.dart';
import '../mongol_render_editable.dart';

/// 管理一对文本选择手柄的对象。
///
/// 选择手柄显示在最接近给定 [BuildContext] 的 [Overlay] 中。
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

  void _handleSelectionEndHandleDragStart(DragStartDetails details) {
    if (!renderObject.attached) {
      return;
    }

    // 这是为了调整选择手柄可能不完全覆盖它们对应的 TextPosition 的事实。
    _endHandleDragPosition = details.globalPosition.dx;
    final Offset endPoint = renderObject
        .localToGlobal(_selectionOverlay.selectionEndpoints.last.point);
    final double centerOfLine =
        endPoint.dx - renderObject.preferredLineWidth / 2;
    _endHandleDragPositionToCenterOfLine =
        centerOfLine - _endHandleDragPosition;
    final TextPosition position = renderObject.getPositionForPoint(
      Offset(
        centerOfLine,
        details.globalPosition.dy,
      ),
    );

    _selectionOverlay.showMagnifier(
      _buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: details.globalPosition,
        renderEditable: renderObject,
      ),
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

    if (_selection.isCollapsed) {
      _selectionOverlay.updateMagnifier(_buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: details.globalPosition,
        renderEditable: renderObject,
      ));

      final TextSelection currentSelection =
          TextSelection.fromPosition(position);
      _handleSelectionHandleChanged(currentSelection, isEnd: true);
      return;
    }

    final TextSelection newSelection;
    switch (defaultTargetPlatform) {
      // 在 Apple 平台上，拖动基础手柄使其成为范围。
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        newSelection = TextSelection(
          extentOffset: position.offset,
          baseOffset: _selection.start,
        );
        if (position.offset <= _selection.start) {
          return; // 不允许顺序交换。
        }
        break;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        newSelection = TextSelection(
          baseOffset: _selection.baseOffset,
          extentOffset: position.offset,
        );
        if (newSelection.baseOffset >= newSelection.extentOffset) {
          return; // 不允许顺序交换。
        }
        break;
    }

    _handleSelectionHandleChanged(newSelection, isEnd: true);

    _selectionOverlay.updateMagnifier(_buildMagnifier(
      currentTextPosition: newSelection.extent,
      globalGesturePosition: details.globalPosition,
      renderEditable: renderObject,
    ));
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
    final Offset startPoint = renderObject
        .localToGlobal(_selectionOverlay.selectionEndpoints.first.point);
    final double centerOfLine =
        startPoint.dx - renderObject.preferredLineWidth / 2;
    _startHandleDragPositionToCenterOfLine =
        centerOfLine - _startHandleDragPosition;
    final TextPosition position = renderObject.getPositionForPoint(
      Offset(
        centerOfLine,
        details.globalPosition.dy,
      ),
    );

    _selectionOverlay.showMagnifier(
      _buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: details.globalPosition,
        renderEditable: renderObject,
      ),
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

    if (_selection.isCollapsed) {
      _selectionOverlay.updateMagnifier(_buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: details.globalPosition,
        renderEditable: renderObject,
      ));

      final TextSelection currentSelection =
          TextSelection.fromPosition(position);
      _handleSelectionHandleChanged(currentSelection, isEnd: false);
      return;
    }

    final TextSelection newSelection;
    switch (defaultTargetPlatform) {
      // 在 Apple 平台上，拖动基础手柄使其成为范围。
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        newSelection = TextSelection(
          extentOffset: position.offset,
          baseOffset: _selection.end,
        );
        if (newSelection.extentOffset >= _selection.end) {
          return; // 不允许顺序交换。
        }
        break;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        newSelection = TextSelection(
          baseOffset: position.offset,
          extentOffset: _selection.extentOffset,
        );
        if (newSelection.baseOffset >= newSelection.extentOffset) {
          return; // 不允许顺序交换。
        }
        break;
    }

    _selectionOverlay.updateMagnifier(_buildMagnifier(
      currentTextPosition: newSelection.extent.offset < newSelection.base.offset
          ? newSelection.extent
          : newSelection.base,
      globalGesturePosition: details.globalPosition,
      renderEditable: renderObject,
    ));

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
class MongolSelectionOverlay {
  /// Creates an object that manages overlay entries for selection handles.
  ///
  /// The [context] must not be null and must have an [Overlay] as an ancestor.
  MongolSelectionOverlay({
    required this.context,
    this.debugRequiredFor,
    required TextSelectionHandleType startHandleType,
    required double lineWidthAtStart,
    this.startHandlesVisible,
    this.onStartHandleDragStart,
    this.onStartHandleDragUpdate,
    this.onStartHandleDragEnd,
    required TextSelectionHandleType endHandleType,
    required double lineWidthAtEnd,
    this.endHandlesVisible,
    this.onEndHandleDragStart,
    this.onEndHandleDragUpdate,
    this.onEndHandleDragEnd,
    this.toolbarVisible,
    required List<TextSelectionPoint> selectionEndpoints,
    required this.selectionControls,
    @Deprecated(
      'Use `contextMenuBuilder` in `showToolbar` instead. '
      'This feature was deprecated after v3.3.0-0.5.pre.',
    )
    required this.selectionDelegate,
    required this.clipboardStatus,
    required this.startHandleLayerLink,
    required this.endHandleLayerLink,
    required this.toolbarLayerLink,
    this.dragStartBehavior = DragStartBehavior.start,
    this.onSelectionHandleTapped,
    @Deprecated(
      'Use `contextMenuBuilder` in `showToolbar` instead. '
      'This feature was deprecated after v3.3.0-0.5.pre.',
    )
    Offset? toolbarLocation,
    this.magnifierConfiguration = TextMagnifierConfiguration.disabled,
  })  : _startHandleType = startHandleType,
        _lineWidthAtStart = lineWidthAtStart,
        _endHandleType = endHandleType,
        _lineWidthAtEnd = lineWidthAtEnd,
        _selectionEndpoints = selectionEndpoints,
        assert(debugCheckHasOverlay(context));

  /// Build context where the overlay will go
  final BuildContext context;

  final ValueNotifier<MagnifierInfo> _magnifierInfo =
      ValueNotifier<MagnifierInfo>(MagnifierInfo.empty);

  /// [MagnifierController.show] and [MagnifierController.hide] should not be
  /// called directly, except from inside [showMagnifier] and [hideMagnifier].
  /// If it is desired to show or hide the magnifier, call [showMagnifier] or
  /// [hideMagnifier]. This is because the magnifier needs to orchestrate
  /// with other properties in [MongolSelectionOverlay].
  final MagnifierController _magnifierController = MagnifierController();

  /// By default, [SelectionOverlay]'s [TextMagnifierConfiguration] is disabled.
  final TextMagnifierConfiguration magnifierConfiguration;

  /// Shows the magnifier, and hides the toolbar if it was showing when
  /// [showMagnifier] was called. This is safe to call on platforms not mobile,
  /// since a magnifierBuilder will not be provided, or the magnifierBuilder
  /// will return null on platforms not mobile.
  ///
  /// This is NOT the source of truth for if the magnifier is up or not,
  /// since magnifiers may hide themselves. If this info is needed, check
  /// [MagnifierController.shown].
  void showMagnifier(MagnifierInfo initialMagnifierInfo) {
    if (_toolbar != null || _contextMenuControllerIsShown) {
      hideToolbar();
    }

    // Start from empty, so we don't utilize any remnant values.
    _magnifierInfo.value = initialMagnifierInfo;

    // Pre-build the magnifiers so we can tell if we've built something
    // or not. If we don't build a magnifiers, then we should not
    // insert anything in the overlay.
    final Widget? builtMagnifier = magnifierConfiguration.magnifierBuilder(
      context,
      _magnifierController,
      _magnifierInfo,
    );

    if (builtMagnifier == null) {
      return;
    }

    _magnifierController.show(
        context: context,
        below: magnifierConfiguration.shouldDisplayHandlesInMagnifier
            ? null
            : _handles?.first,
        builder: (_) => builtMagnifier);
  }

  /// Hide the current magnifier.
  ///
  /// This does nothing if there is no magnifier.
  void hideMagnifier() {
    // This cannot be a check on `MagnifierController.shown`, since
    // it's possible that the magnifier is still in the overlay, but
    // not shown in cases where the magnifier hides itself.
    if (_magnifierController.overlayEntry == null) {
      return;
    }

    _magnifierController.hide();
  }

  /// The type of start selection handle.
  ///
  /// Changing the value while the handles are visible causes them to rebuild.
  TextSelectionHandleType get startHandleType => _startHandleType;
  TextSelectionHandleType _startHandleType;
  set startHandleType(TextSelectionHandleType value) {
    if (_startHandleType == value) {
      return;
    }
    _startHandleType = value;
    markNeedsBuild();
  }

  /// The line width at the selection start.
  ///
  /// This value is used for calculating the size of the start selection handle.
  ///
  /// Changing the value while the handles are visible causes them to rebuild.
  double get lineWidthAtStart => _lineWidthAtStart;
  double _lineWidthAtStart;
  set lineWidthAtStart(double value) {
    if (_lineWidthAtStart == value) {
      return;
    }
    _lineWidthAtStart = value;
    markNeedsBuild();
  }

  bool _isDraggingStartHandle = false;

  /// Whether the start handle is visible.
  ///
  /// If the value changes, the start handle uses [FadeTransition] to transition
  /// itself on and off the screen.
  ///
  /// If this is null, the start selection handle will always be visible.
  final ValueListenable<bool>? startHandlesVisible;

  /// Called when the users start dragging the start selection handles.
  final ValueChanged<DragStartDetails>? onStartHandleDragStart;

  void _handleStartHandleDragStart(DragStartDetails details) {
    assert(!_isDraggingStartHandle);
    _isDraggingStartHandle = details.kind == PointerDeviceKind.touch;
    onStartHandleDragStart?.call(details);
  }

  /// Called when the users drag the start selection handles to new locations.
  final ValueChanged<DragUpdateDetails>? onStartHandleDragUpdate;

  /// Called when the users lift their fingers after dragging the start selection
  /// handles.
  final ValueChanged<DragEndDetails>? onStartHandleDragEnd;

  void _handleStartHandleDragEnd(DragEndDetails details) {
    _isDraggingStartHandle = false;
    onStartHandleDragEnd?.call(details);
  }

  /// The type of end selection handle.
  ///
  /// Changing the value while the handles are visible causes them to rebuild.
  TextSelectionHandleType get endHandleType => _endHandleType;
  TextSelectionHandleType _endHandleType;
  set endHandleType(TextSelectionHandleType value) {
    if (_endHandleType == value) {
      return;
    }
    _endHandleType = value;
    markNeedsBuild();
  }

  /// The line width at the selection end.
  ///
  /// This value is used for calculating the size of the end selection handle.
  ///
  /// Changing the value while the handles are visible causes them to rebuild.
  double get lineWidthAtEnd => _lineWidthAtEnd;
  double _lineWidthAtEnd;
  set lineWidthAtEnd(double value) {
    if (_lineWidthAtEnd == value) {
      return;
    }
    _lineWidthAtEnd = value;
    markNeedsBuild();
  }

  bool _isDraggingEndHandle = false;

  /// Whether the end handle is visible.
  ///
  /// If the value changes, the end handle uses [FadeTransition] to transition
  /// itself on and off the screen.
  ///
  /// If this is null, the end selection handle will always be visible.
  final ValueListenable<bool>? endHandlesVisible;

  /// Called when the users start dragging the end selection handles.
  final ValueChanged<DragStartDetails>? onEndHandleDragStart;

  void _handleEndHandleDragStart(DragStartDetails details) {
    assert(!_isDraggingEndHandle);
    _isDraggingEndHandle = details.kind == PointerDeviceKind.touch;
    onEndHandleDragStart?.call(details);
  }

  /// Called when the users drag the end selection handles to new locations.
  final ValueChanged<DragUpdateDetails>? onEndHandleDragUpdate;

  /// Called when the users lift their fingers after dragging the end selection
  /// handles.
  final ValueChanged<DragEndDetails>? onEndHandleDragEnd;

  void _handleEndHandleDragEnd(DragEndDetails details) {
    _isDraggingEndHandle = false;
    onEndHandleDragEnd?.call(details);
  }

  /// Whether the toolbar is visible.
  ///
  /// If the value changes, the toolbar uses [FadeTransition] to transition
  /// itself on and off the screen.
  ///
  /// If this is null the toolbar will always be visible.
  final ValueListenable<bool>? toolbarVisible;

  /// The text selection positions of selection start and end.
  List<TextSelectionPoint> get selectionEndpoints => _selectionEndpoints;
  List<TextSelectionPoint> _selectionEndpoints;
  set selectionEndpoints(List<TextSelectionPoint> value) {
    if (!listEquals(_selectionEndpoints, value)) {
      markNeedsBuild();
      if (_isDraggingEndHandle || _isDraggingStartHandle) {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            HapticFeedback.selectionClick();
            break;
          case TargetPlatform.fuchsia:
          case TargetPlatform.iOS:
          case TargetPlatform.linux:
          case TargetPlatform.macOS:
          case TargetPlatform.windows:
            break;
        }
      }
    }
    _selectionEndpoints = value;
  }

  /// Debugging information for explaining why the [Overlay] is required.
  final Widget? debugRequiredFor;

  /// The object supplied to the [CompositedTransformTarget] that wraps the text
  /// field.
  final LayerLink toolbarLayerLink;

  /// The objects supplied to the [CompositedTransformTarget] that wraps the
  /// location of start selection handle.
  final LayerLink startHandleLayerLink;

  /// The objects supplied to the [CompositedTransformTarget] that wraps the
  /// location of end selection handle.
  final LayerLink endHandleLayerLink;

  /// Builds text selection handles and toolbar.
  final TextSelectionControls? selectionControls;

  /// The delegate for manipulating the current selection in the owning
  /// text field.
  @Deprecated(
    'Use `contextMenuBuilder` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  final TextSelectionDelegate? selectionDelegate;

  /// Determines the way that drag start behavior is handled.
  ///
  /// If set to [DragStartBehavior.start], handle drag behavior will
  /// begin at the position where the drag gesture won the arena. If set to
  /// [DragStartBehavior.down] it will begin at the position where a down
  /// event is first detected.
  ///
  /// In general, setting this to [DragStartBehavior.start] will make drag
  /// animation smoother and setting it to [DragStartBehavior.down] will make
  /// drag behavior feel slightly more reactive.
  ///
  /// By default, the drag start behavior is [DragStartBehavior.start].
  ///
  /// See also:
  ///
  ///  * [DragGestureRecognizer.dragStartBehavior], which gives an example for
  ///    the different behaviors.
  final DragStartBehavior dragStartBehavior;

  /// A callback that's optionally invoked when a selection handle is tapped.
  ///
  /// The [TextSelectionControls.buildHandle] implementation the text field
  /// uses decides where the handle's tap "hotspot" is, or whether the
  /// selection handle supports tap gestures at all. For instance,
  /// [MaterialTextSelectionControls] calls [onSelectionHandleTapped] when the
  /// selection handle's "knob" is tapped, while
  /// [CupertinoTextSelectionControls] builds a handle that's not sufficiently
  /// large for tapping (as it's not meant to be tapped) so it does not call
  /// [onSelectionHandleTapped] even when tapped.
  final VoidCallback? onSelectionHandleTapped;

  /// Maintains the status of the clipboard for determining if its contents can
  /// be pasted or not.
  ///
  /// Useful because the actual value of the clipboard can only be checked
  /// asynchronously (see [Clipboard.getData]).
  final ClipboardStatusNotifier? clipboardStatus;

  /// The location of where the toolbar should be drawn in relative to the
  /// location of [toolbarLayerLink].
  ///
  /// If this is null, the toolbar is drawn based on [selectionEndpoints] and
  /// the rect of render object of [context].
  ///
  /// This is useful for displaying toolbars at the mouse right-click locations
  /// in desktop devices.
  @Deprecated(
    'Use the `contextMenuBuilder` parameter in `showToolbar` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  Offset? get toolbarLocation => _toolbarLocation;
  Offset? _toolbarLocation;
  set toolbarLocation(Offset? value) {
    if (_toolbarLocation == value) {
      return;
    }
    _toolbarLocation = value;
    markNeedsBuild();
  }

  /// Controls the fade-in and fade-out animations for the toolbar and handles.
  static const Duration fadeDuration = Duration(milliseconds: 150);

  /// A pair of handles. If this is non-null, there are always 2, though the
  /// second is hidden when the selection is collapsed.
  List<OverlayEntry>? _handles;

  /// A copy/paste toolbar.
  OverlayEntry? _toolbar;

  // Manages the context menu. Not necessarily visible when non-null.
  final ContextMenuController _contextMenuController = ContextMenuController();

  bool get _contextMenuControllerIsShown => _contextMenuController.isShown;

  /// Builds the handles by inserting them into the [context]'s overlay.
  void showHandles() {
    if (_handles != null) {
      return;
    }

    _handles = <OverlayEntry>[
      OverlayEntry(builder: _buildStartHandle),
      OverlayEntry(builder: _buildEndHandle),
    ];
    Overlay.of(context, rootOverlay: true, debugRequiredFor: debugRequiredFor)
        .insertAll(_handles!);
  }

  /// Destroys the handles by removing them from overlay.
  void hideHandles() {
    if (_handles != null) {
      _handles![0].remove();
      _handles![1].remove();
      _handles = null;
    }
  }

  /// Shows the toolbar by inserting it into the [context]'s overlay.
  void showToolbar({
    BuildContext? context,
    WidgetBuilder? contextMenuBuilder,
  }) {
    if (contextMenuBuilder == null) {
      if (_toolbar != null) {
        return;
      }
      _toolbar = OverlayEntry(builder: _buildToolbar);
      Overlay.of(this.context,
              rootOverlay: true, debugRequiredFor: debugRequiredFor)
          .insert(_toolbar!);
      return;
    }

    if (context == null) {
      return;
    }

    final RenderBox renderBox = context.findRenderObject()! as RenderBox;
    _contextMenuController.show(
      context: context,
      contextMenuBuilder: (BuildContext context) {
        return _SelectionToolbarWrapper(
          layerLink: toolbarLayerLink,
          offset: -renderBox.localToGlobal(Offset.zero),
          child: contextMenuBuilder(context),
        );
      },
    );
  }

  bool _buildScheduled = false;

  /// Rebuilds the selection toolbar or handles if they are present.
  void markNeedsBuild() {
    if (_handles == null && _toolbar == null) {
      return;
    }
    // If we are in build state, it will be too late to update visibility.
    // We will need to schedule the build in next frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_buildScheduled) {
        return;
      }
      _buildScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
        _buildScheduled = false;
        if (_handles != null) {
          _handles![0].markNeedsBuild();
          _handles![1].markNeedsBuild();
        }
        _toolbar?.markNeedsBuild();
        if (_contextMenuController.isShown) {
          _contextMenuController.markNeedsBuild();
        }
      });
    } else {
      if (_handles != null) {
        _handles![0].markNeedsBuild();
        _handles![1].markNeedsBuild();
      }
      _toolbar?.markNeedsBuild();
      if (_contextMenuController.isShown) {
        _contextMenuController.markNeedsBuild();
      }
    }
  }

  /// Hides the entire overlay including the toolbar and the handles.
  void hide() {
    if (_handles != null) {
      _handles![0].remove();
      _handles![1].remove();
      _handles = null;
    }
    if (_toolbar != null || _contextMenuControllerIsShown) {
      hideToolbar();
    }
  }

  /// Hides the toolbar part of the overlay.
  ///
  /// To hide the whole overlay, see [hide].
  void hideToolbar() {
    _contextMenuController.remove();
    if (_toolbar == null) {
      return;
    }
    _toolbar?.remove();
    _toolbar = null;
  }

  /// Disposes this object and release resources.
  void dispose() {
    hide();
  }

  Widget _buildStartHandle(BuildContext context) {
    final Widget handle;
    final TextSelectionControls? selectionControls = this.selectionControls;
    if (selectionControls == null) {
      handle = const SizedBox.shrink();
    } else {
      handle = _SelectionHandleOverlay(
        type: _startHandleType,
        handleLayerLink: startHandleLayerLink,
        onSelectionHandleTapped: onSelectionHandleTapped,
        onSelectionHandleDragStart: _handleStartHandleDragStart,
        onSelectionHandleDragUpdate: onStartHandleDragUpdate,
        onSelectionHandleDragEnd: _handleStartHandleDragEnd,
        selectionControls: selectionControls,
        visibility: startHandlesVisible,
        preferredLineWidth: _lineWidthAtStart,
        dragStartBehavior: dragStartBehavior,
      );
    }
    return TextFieldTapRegion(
      child: ExcludeSemantics(
        child: handle,
      ),
    );
  }

  Widget _buildEndHandle(BuildContext context) {
    final Widget handle;
    final TextSelectionControls? selectionControls = this.selectionControls;
    if (selectionControls == null ||
        _startHandleType == TextSelectionHandleType.collapsed) {
      // Hide the second handle when collapsed.
      handle = const SizedBox.shrink();
    } else {
      handle = _SelectionHandleOverlay(
        type: _endHandleType,
        handleLayerLink: endHandleLayerLink,
        onSelectionHandleTapped: onSelectionHandleTapped,
        onSelectionHandleDragStart: _handleEndHandleDragStart,
        onSelectionHandleDragUpdate: onEndHandleDragUpdate,
        onSelectionHandleDragEnd: _handleEndHandleDragEnd,
        selectionControls: selectionControls,
        visibility: endHandlesVisible,
        preferredLineWidth: _lineWidthAtEnd,
        dragStartBehavior: dragStartBehavior,
      );
    }
    return TextFieldTapRegion(
      child: ExcludeSemantics(
        child: handle,
      ),
    );
  }

  // Build the toolbar via TextSelectionControls.
  Widget _buildToolbar(BuildContext context) {
    if (selectionControls == null) {
      return const SizedBox.shrink();
    }
    assert(selectionDelegate != null,
        'If not using contextMenuBuilder, must pass selectionDelegate.');

    final RenderBox renderBox = this.context.findRenderObject()! as RenderBox;

    final Rect editingRegion = Rect.fromPoints(
      renderBox.localToGlobal(Offset.zero),
      renderBox.localToGlobal(renderBox.size.bottomRight(Offset.zero)),
    );

    final bool isMultiline =
        selectionEndpoints.last.point.dx - selectionEndpoints.first.point.dx >
            lineWidthAtEnd / 2;

    // If the selected text spans more than 1 line, vertically center the toolbar.
    // Derived from both iOS and Android.
    final double midY = isMultiline
        ? editingRegion.height / 2
        : (selectionEndpoints.first.point.dy +
                selectionEndpoints.last.point.dy) /
            2;

    final Offset midpoint = Offset(
      midY,
      // The x-coordinate won't be made use of most likely.
      selectionEndpoints.first.point.dx - lineWidthAtStart,
    );

    return _SelectionToolbarWrapper(
      visibility: toolbarVisible,
      layerLink: toolbarLayerLink,
      offset: -editingRegion.topLeft,
      child: Builder(
        builder: (BuildContext context) {
          return selectionControls!.buildToolbar(
            context,
            editingRegion,
            lineWidthAtStart,
            midpoint,
            selectionEndpoints,
            selectionDelegate!,
            clipboardStatus,
            toolbarLocation,
          );
        },
      ),
    );
  }

  /// Update the current magnifier with new selection data, so the magnifier
  /// can respond accordingly.
  ///
  /// If the magnifier is not shown, this still updates the magnifier position
  /// because the magnifier may have hidden itself and is looking for a cue to
  /// reshow itself.
  ///
  /// If there is no magnifier in the overlay, this does nothing.
  void updateMagnifier(MagnifierInfo magnifierInfo) {
    if (_magnifierController.overlayEntry == null) {
      return;
    }

    _magnifierInfo.value = magnifierInfo;
  }
}

class _SelectionToolbarWrapper extends StatefulWidget {
  const _SelectionToolbarWrapper({
    this.visibility,
    required this.layerLink,
    required this.offset,
    required this.child,
  });

  final Widget child;
  final Offset offset;
  final LayerLink layerLink;
  final ValueListenable<bool>? visibility;

  @override
  State<_SelectionToolbarWrapper> createState() =>
      _SelectionToolbarWrapperState();
}

class _SelectionToolbarWrapperState extends State<_SelectionToolbarWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double> get _opacity => _controller.view;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
        duration: SelectionOverlay.fadeDuration, vsync: this);

    _toolbarVisibilityChanged();
    widget.visibility?.addListener(_toolbarVisibilityChanged);
  }

  @override
  void didUpdateWidget(_SelectionToolbarWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibility == widget.visibility) {
      return;
    }
    oldWidget.visibility?.removeListener(_toolbarVisibilityChanged);
    _toolbarVisibilityChanged();
    widget.visibility?.addListener(_toolbarVisibilityChanged);
  }

  @override
  void dispose() {
    widget.visibility?.removeListener(_toolbarVisibilityChanged);
    _controller.dispose();
    super.dispose();
  }

  void _toolbarVisibilityChanged() {
    if (widget.visibility?.value ?? true) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFieldTapRegion(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: FadeTransition(
          opacity: _opacity,
          child: CompositedTransformFollower(
            link: widget.layerLink,
            showWhenUnlinked: false,
            offset: widget.offset,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// This widget represents a single draggable selection handle.
class _SelectionHandleOverlay extends StatefulWidget {
  /// Create selection overlay.
  const _SelectionHandleOverlay({
    required this.type,
    required this.handleLayerLink,
    this.onSelectionHandleTapped,
    this.onSelectionHandleDragStart,
    this.onSelectionHandleDragUpdate,
    this.onSelectionHandleDragEnd,
    required this.selectionControls,
    this.visibility,
    required this.preferredLineWidth,
    this.dragStartBehavior = DragStartBehavior.start,
  });

  final LayerLink handleLayerLink;
  final VoidCallback? onSelectionHandleTapped;
  final ValueChanged<DragStartDetails>? onSelectionHandleDragStart;
  final ValueChanged<DragUpdateDetails>? onSelectionHandleDragUpdate;
  final ValueChanged<DragEndDetails>? onSelectionHandleDragEnd;
  final TextSelectionControls selectionControls;
  final ValueListenable<bool>? visibility;
  final double preferredLineWidth;
  final TextSelectionHandleType type;
  final DragStartBehavior dragStartBehavior;

  @override
  State<_SelectionHandleOverlay> createState() =>
      _SelectionHandleOverlayState();
}

class _SelectionHandleOverlayState extends State<_SelectionHandleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double> get _opacity => _controller.view;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
        duration: SelectionOverlay.fadeDuration, vsync: this);

    _handleVisibilityChanged();
    widget.visibility?.addListener(_handleVisibilityChanged);
  }

  void _handleVisibilityChanged() {
    if (widget.visibility?.value ?? true) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void didUpdateWidget(_SelectionHandleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.visibility?.removeListener(_handleVisibilityChanged);
    _handleVisibilityChanged();
    widget.visibility?.addListener(_handleVisibilityChanged);
  }

  @override
  void dispose() {
    widget.visibility?.removeListener(_handleVisibilityChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Offset handleAnchor = widget.selectionControls.getHandleAnchor(
      widget.type,
      widget.preferredLineWidth,
    );
    final Size handleSize = widget.selectionControls.getHandleSize(
      widget.preferredLineWidth,
    );

    final Rect handleRect = Rect.fromLTWH(
      -handleAnchor.dx,
      -handleAnchor.dy,
      handleSize.width,
      handleSize.height,
    );

    // Make sure the GestureDetector is big enough to be easily interactive.
    final Rect interactiveRect = handleRect.expandToInclude(
      Rect.fromCircle(
          center: handleRect.center, radius: kMinInteractiveDimension / 2),
    );
    final RelativeRect padding = RelativeRect.fromLTRB(
      math.max((interactiveRect.width - handleRect.width) / 2, 0),
      math.max((interactiveRect.height - handleRect.height) / 2, 0),
      math.max((interactiveRect.width - handleRect.width) / 2, 0),
      math.max((interactiveRect.height - handleRect.height) / 2, 0),
    );

    return CompositedTransformFollower(
      link: widget.handleLayerLink,
      offset: interactiveRect.topLeft,
      showWhenUnlinked: false,
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          alignment: Alignment.topLeft,
          width: interactiveRect.width,
          height: interactiveRect.height,
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: <Type, GestureRecognizerFactory>{
              PanGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
                () => PanGestureRecognizer(
                  debugOwner: this,
                  // On web, mouse should be allowed to drag selection handles.
                  supportedDevices: <PointerDeviceKind>{
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                    if (kIsWeb) PointerDeviceKind.mouse,
                    PointerDeviceKind.unknown,
                  },
                ),
                (PanGestureRecognizer instance) {
                  instance
                    ..dragStartBehavior = widget.dragStartBehavior
                    ..onStart = widget.onSelectionHandleDragStart
                    ..onUpdate = widget.onSelectionHandleDragUpdate
                    ..onEnd = widget.onSelectionHandleDragEnd;
                },
              ),
            },
            child: Padding(
              padding: EdgeInsets.only(
                left: padding.left,
                top: padding.top,
                right: padding.right,
                bottom: padding.bottom,
              ),
              child: widget.selectionControls.buildHandle(
                context,
                widget.type,
                widget.preferredLineWidth,
                widget.onSelectionHandleTapped,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextSelectionGestureDetectorState
    extends State<TextSelectionGestureDetector> {
  // Converts the details.consecutiveTapCount from a TapAndDrag*Details object,
  // which can grow to be infinitely large, to a value between 1 and 3. The value
  // that the raw count is converted to is based on the default observed behavior
  // on the native platforms.
  //
  // This method should be used in all instances when details.consecutiveTapCount
  // would be used.
  static int _getEffectiveConsecutiveTapCount(int rawCount) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
        // From observation, these platform's reset their tap count to 0 when
        // the number of consecutive taps exceeds 3. For example on Debian Linux
        // with GTK, when going past a triple click, on the fourth click the
        // selection is moved to the precise click position, on the fifth click
        // the word at the position is selected, and on the sixth click the
        // paragraph at the position is selected.
        return rawCount <= 3
            ? rawCount
            : (rawCount % 3 == 0 ? 3 : rawCount % 3);
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // From observation, these platform's either hold their tap count at 3.
        // For example on macOS, when going past a triple click, the selection
        // should be retained at the paragraph that was first selected on triple
        // click.
        return math.min(rawCount, 3);
      case TargetPlatform.windows:
        // From observation, this platform's consecutive tap actions alternate
        // between double click and triple click actions. For example, after a
        // triple click has selected a paragraph, on the next click the word at
        // the clicked position will be selected, and on the next click the
        // paragraph at the position is selected.
        return rawCount < 2 ? rawCount : 2 + rawCount % 2;
    }
  }

  void _handleTapTrackStart() {
    widget.onTapTrackStart?.call();
  }

  void _handleTapTrackReset() {
    widget.onTapTrackReset?.call();
  }

  // The down handler is force-run on success of a single tap and optimistically
  // run before a long press success.
  void _handleTapDown(TapDragDownDetails details) {
    widget.onTapDown?.call(details);
    // This isn't detected as a double tap gesture in the gesture recognizer
    // because it's 2 single taps, each of which may do different things depending
    // on whether it's a single tap, the first tap of a double tap, the second
    // tap held down, a clean double tap etc.
    if (_getEffectiveConsecutiveTapCount(details.consecutiveTapCount) == 2) {
      return widget.onDoubleTapDown?.call(details);
    }

    if (_getEffectiveConsecutiveTapCount(details.consecutiveTapCount) == 3) {
      return widget.onTripleTapDown?.call(details);
    }
  }

  void _handleTapUp(TapDragUpDetails details) {
    if (_getEffectiveConsecutiveTapCount(details.consecutiveTapCount) == 1) {
      widget.onSingleTapUp?.call(details);
    }
  }

  void _handleTapCancel() {
    widget.onSingleTapCancel?.call();
  }

  void _handleDragStart(TapDragStartDetails details) {
    widget.onDragSelectionStart?.call(details);
  }

  void _handleDragUpdate(TapDragUpdateDetails details) {
    widget.onDragSelectionUpdate?.call(details);
  }

  void _handleDragEnd(TapDragEndDetails details) {
    widget.onDragSelectionEnd?.call(details);
  }

  void _forcePressStarted(ForcePressDetails details) {
    widget.onForcePressStart?.call(details);
  }

  void _forcePressEnded(ForcePressDetails details) {
    widget.onForcePressEnd?.call(details);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    if (widget.onSingleLongTapStart != null) {
      widget.onSingleLongTapStart!(details);
    }
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (widget.onSingleLongTapMoveUpdate != null) {
      widget.onSingleLongTapMoveUpdate!(details);
    }
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    if (widget.onSingleLongTapEnd != null) {
      widget.onSingleLongTapEnd!(details);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory> gestures =
        <Type, GestureRecognizerFactory>{};

    gestures[TapGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
      () => TapGestureRecognizer(debugOwner: this),
      (TapGestureRecognizer instance) {
        instance
          ..onSecondaryTap = widget.onSecondaryTap
          ..onSecondaryTapDown = widget.onSecondaryTapDown;
      },
    );

    if (widget.onSingleLongTapStart != null ||
        widget.onSingleLongTapMoveUpdate != null ||
        widget.onSingleLongTapEnd != null) {
      gestures[LongPressGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
        () => LongPressGestureRecognizer(
            debugOwner: this,
            supportedDevices: <PointerDeviceKind>{PointerDeviceKind.touch}),
        (LongPressGestureRecognizer instance) {
          instance
            ..onLongPressStart = _handleLongPressStart
            ..onLongPressMoveUpdate = _handleLongPressMoveUpdate
            ..onLongPressEnd = _handleLongPressEnd;
        },
      );
    }

    if (widget.onDragSelectionStart != null ||
        widget.onDragSelectionUpdate != null ||
        widget.onDragSelectionEnd != null) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.iOS:
          gestures[TapAndHorizontalDragGestureRecognizer] =
              GestureRecognizerFactoryWithHandlers<
                  TapAndHorizontalDragGestureRecognizer>(
            () => TapAndHorizontalDragGestureRecognizer(debugOwner: this),
            (TapAndHorizontalDragGestureRecognizer instance) {
              instance
                // Text selection should start from the position of the first pointer
                // down event.
                ..dragStartBehavior = DragStartBehavior.down
                ..onTapTrackStart = _handleTapTrackStart
                ..onTapTrackReset = _handleTapTrackReset
                ..onTapDown = _handleTapDown
                ..onDragStart = _handleDragStart
                ..onDragUpdate = _handleDragUpdate
                ..onDragEnd = _handleDragEnd
                ..onTapUp = _handleTapUp
                ..onCancel = _handleTapCancel;
            },
          );
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          gestures[TapAndPanGestureRecognizer] =
              GestureRecognizerFactoryWithHandlers<TapAndPanGestureRecognizer>(
            () => TapAndPanGestureRecognizer(debugOwner: this),
            (TapAndPanGestureRecognizer instance) {
              instance
                // Text selection should start from the position of the first pointer
                // down event.
                ..dragStartBehavior = DragStartBehavior.down
                ..onTapTrackStart = _handleTapTrackStart
                ..onTapTrackReset = _handleTapTrackReset
                ..onTapDown = _handleTapDown
                ..onDragStart = _handleDragStart
                ..onDragUpdate = _handleDragUpdate
                ..onDragEnd = _handleDragEnd
                ..onTapUp = _handleTapUp
                ..onCancel = _handleTapCancel;
            },
          );
      }
    }

    if (widget.onForcePressStart != null || widget.onForcePressEnd != null) {
      gestures[ForcePressGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<ForcePressGestureRecognizer>(
        () => ForcePressGestureRecognizer(debugOwner: this),
        (ForcePressGestureRecognizer instance) {
          instance
            ..onStart =
                widget.onForcePressStart != null ? _forcePressStarted : null
            ..onEnd = widget.onForcePressEnd != null ? _forcePressEnded : null;
        },
      );
    }

    return RawGestureDetector(
      gestures: gestures,
      excludeFromSemantics: true,
      behavior: widget.behavior,
      child: widget.child,
    );
  }
}
