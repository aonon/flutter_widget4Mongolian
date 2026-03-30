// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui hide TextStyle;

import 'package:characters/characters.dart'
    show CharacterRange, StringCharacters;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart'
    show
        ContentInsertionConfiguration,
        kDefaultContentInsertionMimeTypes,
        DeleteToNextWordBoundaryIntent,
        ExpandSelectionToDocumentBoundaryIntent,
        ExtendSelectionVerticallyToAdjacentLineIntent,
        ReplaceTextIntent,
        ScrollToDocumentBoundaryIntent,
        Size,
        kMinInteractiveDimension;
import 'package:flutter/rendering.dart' show RevealedOffset, ViewportOffset;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    show
        Action,
        Actions,
        AnimationController,
        AppPrivateCommandCallback,
        AutofillGroup,
        AutofillGroupState,
        AutomaticKeepAliveClientMixin,
        AxisDirection,
        BuildContext,
        CallbackAction,
        CharacterRange,
        Clip,
        ClipboardStatus,
        ClipboardStatusNotifier,
        Color,
        CompositedTransformTarget,
        ContextAction,
        ContextMenuButtonItem,
        ContextMenuButtonType,
        CopySelectionTextIntent,
        Curve,
        Curves,
        DeleteCharacterIntent,
        DeleteToLineBreakIntent,
        DirectionalCaretMovementIntent,
        DirectionalFocusAction,
        DirectionalFocusIntent,
        DirectionalTextEditingIntent,
        DismissIntent,
        DoNothingAction,
        DoNothingAndStopPropagationTextIntent,
        EdgeInsets,
        ExpandSelectionToLineBreakIntent,
        ExtendSelectionByCharacterIntent,
        ExtendSelectionByPageIntent,
        ExtendSelectionToDocumentBoundaryIntent,
        ExtendSelectionToLineBreakIntent,
        ExtendSelectionToNextWordBoundaryIntent,
        ExtendSelectionToNextWordBoundaryOrCaretLocationIntent,
        Focus,
        FocusNode,
        FocusScope,
        GlobalKey,
        Intent,
        intentForMacOSSelector,
        LayerLink,
        LeafRenderObjectWidget,
        MediaQuery,
        MouseRegion,
        Offset,
        Orientation,
        PasteTextIntent,
        PointerDownEvent,
        primaryFocus,
        Radius,
        Rect,
        RedoTextIntent,
        ScrollBehavior,
        ScrollConfiguration,
        ScrollController,
        ScrollPhysics,
        Scrollable,
        ScrollableState,
        ScrollIntent,
        ScrollIncrementType,
        ScrollPosition,
        ScrollAction,
        SelectAllTextIntent,
        SelectionChangedCallback,
        Semantics,
        Simulation,
        State,
        StatefulWidget,
        TapRegionCallback,
        TextAlign,
        TextDirection,
        TextEditingController,
        TextFieldTapRegion,
        TextMagnifierConfiguration,
        TextSelectionControls,
        TextSelectionHandleType,
        TextSelectionHandleControls,
        TextSelectionToolbarAnchors,
        TextSelectionPoint,
        TextSpan,
        TextStyle,
        TickerMode,
        TickerProviderStateMixin,
        ToolbarOptions,
        TransposeCharactersIntent,
        UndoTextIntent,
        UpdateSelectionIntent,
        View,
        Widget,
        WidgetsBinding,
        WidgetsBindingObserver,
        debugCheckHasMediaQuery;

import 'package:mongol/src/base/mongol_text_align.dart';
import 'package:mongol/src/editing/mongol_render_editable.dart';
import 'package:mongol/src/editing/text_selection/mongol_text_selection.dart';

import 'text_editing_controller_extension.dart';
import 'mongol_text_editing_intents.dart';
import 'mongol_mouse_cursors.dart';
import 'web_text_cursor_helper.dart';

export 'package:flutter/services.dart'
    show
        SelectionChangedCause,
        TextEditingValue,
        TextSelection,
        TextInputType,
        SmartQuotesType,
        SmartDashesType;

/// 用于为给定的 [MongolEditableTextState] 构建上下文菜单的 widget 构建器签名。
///
/// 另请参见：
///
///  * [SelectableRegionContextMenuBuilder]，它为 [SelectableRegion] 执行相同的角色。
typedef MongolEditableTextContextMenuBuilder = Widget Function(
  BuildContext context,
  MongolEditableTextState editableTextState,
);

// 光标从完全不透明淡入淡出到完全透明所需的时间，反之亦然。
// 完整的光标闪烁周期（从透明到不透明再到透明）是此持续时间的两倍。
const Duration _kCursorBlinkHalfPeriod = Duration(milliseconds: 500);

// 在模糊文本字段中显示最近输入的字符的光标 ticks 数。
const int _kObscureShowLatestCharCursorTicks = 3;

// 表示动画中关键帧的时间值对。
class _KeyFrame {
  const _KeyFrame(this.time, this.value);
  // 从 iOS 15.4 UIKit 提取的值。
  static const List<_KeyFrame> iOSBlinkingCaretKeyFrames = <_KeyFrame>[
    _KeyFrame(0, 1), // 0
    _KeyFrame(0.5, 1), // 1
    _KeyFrame(0.5375, 0.75), // 2
    _KeyFrame(0.575, 0.5), // 3
    _KeyFrame(0.6125, 0.25), // 4
    _KeyFrame(0.65, 0), // 5
    _KeyFrame(0.85, 0), // 6
    _KeyFrame(0.8875, 0.25), // 7
    _KeyFrame(0.925, 0.5), // 8
    _KeyFrame(0.9625, 0.75), // 9
    _KeyFrame(1, 1), // 10
  ];

  // 指定动画 `value` 的时间（以秒为单位）。
  final double time;
  final double value;
}

class _DiscreteKeyFrameSimulation extends Simulation {
  _DiscreteKeyFrameSimulation.iOSBlinkingCaret()
      : this._(_KeyFrame.iOSBlinkingCaretKeyFrames, 1);
  _DiscreteKeyFrameSimulation._(this._keyFrames, this.maxDuration)
      : assert(_keyFrames.isNotEmpty),
        assert(_keyFrames.last.time <= maxDuration),
        assert(() {
          for (int i = 0; i < _keyFrames.length - 1; i += 1) {
            if (_keyFrames[i].time > _keyFrames[i + 1].time) {
              return false;
            }
          }
          return true;
        }(), '关键帧序列必须按时间排序。');

  final double maxDuration;

  final List<_KeyFrame> _keyFrames;

  @override
  double dx(double time) => 0;

  @override
  bool isDone(double time) => time >= maxDuration;

  // KeyFrame 的索引对应于最近的输入 `time`。
  int _lastKeyFrameIndex = 0;

  @override
  double x(double time) {
    final int length = _keyFrames.length;

    // 在排序的关键帧列表中执行线性搜索，从最后找到的关键帧开始，
    // 因为输入 `time` 通常会单调小幅增加。
    int searchIndex;
    final int endIndex;
    if (_keyFrames[_lastKeyFrameIndex].time > time) {
      // 模拟可能已重新开始。在索引范围 [0, _lastKeyFrameIndex) 内搜索。
      searchIndex = 0;
      endIndex = _lastKeyFrameIndex;
    } else {
      searchIndex = _lastKeyFrameIndex;
      endIndex = length;
    }

    // 找到目标关键帧。不需要检查 (endIndex - 1)：
    // 如果 (endIndex - 2) 不起作用，我们无论如何都必须选择 (endIndex - 1)。
    while (searchIndex < endIndex - 1) {
      assert(_keyFrames[searchIndex].time <= time);
      final _KeyFrame next = _keyFrames[searchIndex + 1];
      if (time < next.time) {
        break;
      }
      searchIndex += 1;
    }

    _lastKeyFrameIndex = searchIndex;
    return _keyFrames[_lastKeyFrameIndex].value;
  }
}

/// 基本文本输入字段。
///
/// 此 widget 与 [TextInput] 服务交互，让用户编辑其中包含的文本。
/// 它还提供滚动、选择和光标移动功能。此 widget 不提供任何焦点管理（例如，点击获取焦点）。
///
/// ## 处理用户输入
///
/// 当前，用户可以通过键盘或文本选择菜单更改此 widget 包含的文本。
/// 当用户插入或删除文本时，您将收到更改通知并有机会修改新的文本值：
///
/// * [inputFormatters] 将首先应用于用户输入。
///
/// * [controller] 的 [TextEditingController.value] 将使用格式化结果进行更新，
///   并且 [controller] 的监听器将收到通知。
///
/// * 如果指定了 [onChanged] 回调，它将最后被调用。
///
/// ## 输入操作
///
/// 可以提供 [TextInputAction] 来自定义 Android 和 iOS 软键盘上操作按钮的外观。
/// 默认操作是 [TextInputAction.done]。
///
/// 许多 [TextInputAction] 在 Android 和 iOS 之间是通用的。
/// 但是，如果提供的 [textInputAction] 在调试模式下不受当前平台支持，
/// 当相应的 MongolEditableText 获得焦点时会抛出错误。
/// 例如，在 Android 设备上运行时提供 iOS 的 "emergencyCall" 操作会在调试模式下导致错误。
/// 在发布模式下，不兼容的 [TextInputAction] 会在 Android 上替换为 "unspecified"，
/// 或在 iOS 上替换为 "default"。
/// 可以通过检查当前平台然后选择适当的操作来选择合适的 [textInputAction]。
///
/// ## 生命周期
///
/// 编辑完成后，例如按下键盘上的 "完成" 按钮，会发生两个操作：
///
///   1. 编辑完成。此步骤的默认行为包括调用 [onChanged]。
///      可以覆盖该默认行为。有关详细信息，请参见 [onEditingComplete]。
///
///   2. [onSubmitted] 会使用用户的输入值被调用。
///
/// [onSubmitted] 可用于当用户完成当前聚焦的输入 widget 时手动将焦点移动到另一个输入 widget。
///
/// 与其直接使用此 widget，不如考虑使用 [MongolTextField]，它是一个功能齐全的、
/// 材料设计的文本输入字段，带有占位符文本、标签和 [Form] 集成。
///
/// ## 手势事件处理
///
/// 当 [rendererIgnoresPointer] 为 false（默认值）时，此 widget 为用户操作（如点击、长按和滚动）
/// 提供基本的、平台无关的手势处理。
/// 对于自定义选择行为，可以通过编程方式调用 [MongolRenderEditable.selectPosition]、
/// [MongolRenderEditable.selectWord] 等方法。
///
/// 另请参见：
///
///  * [MongolTextField]，它是一个功能齐全的、材料设计的文本输入字段，
///    带有占位符文本、标签和 [Form] 集成。
class MongolEditableText extends StatefulWidget {
  /// 创建一个基本的文本输入控件。
  ///
  /// [maxLines] 属性可以设置为 null 以移除对行数的限制。默认为 1，意味着这是一个单行
  /// 文本字段。[maxLines] 必须为 null 或大于零。
  ///
  /// 如果未设置 [keyboardType] 或其为 null，其值将从 [autofillHints] 推断，
  /// 如果 [autofillHints] 不为空。否则，如果 [maxLines] 恰好为 1，默认为
  /// [TextInputType.text]，如果 [maxLines] 为 null 或大于 1，则默认为
  /// [TextInputType.multiline]。
  ///
  /// 如果 [showCursor] 为 false 或 [showCursor] 为 null（默认值）且 [readOnly] 为 true，
  /// 则不显示文本光标。
  MongolEditableText({
    super.key,
    required this.controller,
    required this.focusNode,
    this.readOnly = false,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    required this.style,
    required this.cursorColor,
    this.textAlign = MongolTextAlign.top,
    this.textScaleFactor,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.forceLine = true,
    this.autofocus = false,
    bool? showCursor,
    this.showSelectionHandles = false,
    this.selectionColor,
    this.selectionControls,
    TextInputType? keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onAppPrivateCommand,
    this.onSelectionChanged,
    this.onSelectionHandleTapped,
    this.onTapOutside,
    List<TextInputFormatter>? inputFormatters,
    this.mouseCursor,
    this.rendererIgnoresPointer = false,
    this.cursorHeight = 2.0,
    this.cursorWidth,
    this.cursorRadius,
    this.cursorOpacityAnimates = false,
    this.cursorOffset,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.keyboardAppearance = Brightness.light,
    this.dragStartBehavior = DragStartBehavior.start,
    bool? enableInteractiveSelection,
    this.enableWebReadOnlyInputConnection = true,
    this.scrollController,
    this.scrollPhysics,
    @Deprecated(
      'Use `contextMenuBuilder` instead. '
      'This feature was deprecated after v3.3.0-0.5.pre.',
    )
    ToolbarOptions? toolbarOptions,
    this.autofillHints,
    this.autofillClient,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.scrollBehavior,
    this.contentInsertionConfiguration,
    this.contextMenuBuilder,
    this.magnifierConfiguration = TextMagnifierConfiguration.disabled,
  })  : assert(obscuringCharacter.length == 1),
        assert(maxLines == null || maxLines > 0),
        assert(minLines == null || minLines > 0),
        assert(
          (maxLines == null) || (minLines == null) || (maxLines >= minLines),
          "minLines 不能大于 maxLines",
        ),
        assert(
          !expands || (maxLines == null && minLines == null),
          '当 expands 为 true 时，minLines 和 maxLines 必须为 null。',
        ),
        assert(!obscureText || maxLines == 1, '模糊字段不能是多行的。'),
        assert(
          !readOnly || autofillHints == null,
          "只读字段不能有自动填充提示。",
        ),
        enableInteractiveSelection =
            enableInteractiveSelection ?? (!readOnly || !obscureText),
        toolbarOptions = selectionControls is TextSelectionHandleControls &&
                toolbarOptions == null
            ? ToolbarOptions.empty
            : toolbarOptions ??
                (obscureText
                    ? (readOnly
                        // 在只读模糊字段中甚至没有必要提供"全选"选项。
                        ? ToolbarOptions.empty
                        // 可写但模糊。
                        : const ToolbarOptions(
                            selectAll: true,
                            paste: true,
                          ))
                    : (readOnly
                        // 只读，不模糊。
                        ? const ToolbarOptions(
                            selectAll: true,
                            copy: true,
                          )
                        // 可写，不模糊。
                        : const ToolbarOptions(
                            copy: true,
                            cut: true,
                            selectAll: true,
                            paste: true,
                          ))),
        keyboardType = keyboardType ??
            _inferKeyboardType(
                autofillHints: autofillHints, maxLines: maxLines),
        inputFormatters = maxLines == 1
            ? <TextInputFormatter>[
                FilteringTextInputFormatter.singleLineFormatter,
                ...inputFormatters ??
                    const Iterable<TextInputFormatter>.empty(),
              ]
            : inputFormatters,
        showCursor = showCursor ?? !readOnly;

  /// 控制正在编辑的文本。
  final TextEditingController controller;

  /// 控制此 widget 是否具有键盘焦点。
  final FocusNode focusNode;

  /// 当 [obscureText] 为 true 时用于模糊文本的字符。
  ///
  /// 必须只有一个字符。
  ///
  /// 默认为字符 U+2022 BULLET (•)。
  final String obscuringCharacter;

  /// 是否隐藏正在编辑的文本（例如，用于密码）。
  ///
  /// 当设置为 true 时，文本字段中的所有字符都被 [obscuringCharacter] 替换。
  ///
  /// 默认为 false。
  final bool obscureText;

  /// 文本是否可以更改。
  ///
  /// 当设置为 true 时，文本不能通过任何快捷方式或键盘操作修改。文本仍然可以选择。
  ///
  /// 默认为 false。
  final bool readOnly;

  /// 文本是否会占据整个高度，而不管文本高度如何。
  ///
  /// 当设置为 false 时，高度将基于文本高度。
  ///
  /// 默认为 true。
  ///
  /// 另请参见：
  ///
  ///  * [textWidthBasis]，它控制文本宽度的计算。
  final bool forceLine;

  /// 工具栏选项的配置。
  ///
  /// 默认情况下，所有选项都已启用。如果 [readOnly] 为 true，
  /// 则无论如何都会禁用粘贴和剪切。
  final ToolbarOptions toolbarOptions;

  /// 是否显示选择手柄。
  ///
  /// 当选择处于活动状态时，边界的每一侧都会有两个手柄，或者如果选择被折叠，则有一个手柄。
  /// 可以拖动手柄来调整选择。
  ///
  /// 另请参见：
  ///
  ///  * [showCursor]，它控制光标的可见性。
  final bool showSelectionHandles;

  /// 是否显示光标。
  ///
  /// 光标是指 [MongolEditableText] 获得焦点时的闪烁插入符号。
  ///
  /// 另请参见：
  ///
  ///  * [showSelectionHandles]，它控制选择手柄的可见性。
  final bool showCursor;

  /// 是否启用自动更正。
  ///
  /// 默认为 true。不能为空。
  final bool autocorrect;

  /// 用户键入时是否显示输入建议。
  ///
  /// 此标志仅影响 Android。在 iOS 上，建议直接与 [autocorrect] 相关联，
  /// 因此只有当 [autocorrect] 为 true 时才会显示建议。在 Android 上，自动更正和建议是分开控制的。
  ///
  /// 默认为 true。
  ///
  /// 另请参见：
  ///
  ///  * <https://developer.android.com/reference/android/text/InputType.html#TYPE_TEXT_FLAG_NO_SUGGESTIONS>
  final bool enableSuggestions;

  /// 用于可编辑文本的文本样式。
  final TextStyle style;

  /// 文本应如何垂直对齐。
  ///
  /// 默认为 [MongolTextAlign.top]。
  final MongolTextAlign textAlign;

  /// 每个逻辑像素的字体像素数。
  ///
  /// 例如，如果文本缩放因子为 1.5，文本将比指定的字体大小大 50%。
  ///
  /// 默认为从环境 [MediaQuery] 获得的 [MediaQueryData.textScaleFactor]，
  /// 或者如果作用域中没有 [MediaQuery]，则为 1.0。
  final double? textScaleFactor;

  /// 绘制光标时使用的颜色。
  final Color cursorColor;

  /// 文本要跨越的最大行数，必要时换行。
  ///
  /// 如果为 1（默认值），文本将不会换行，而是会垂直滚动。
  ///
  /// 如果为 null，则行数没有限制，文本容器将以一行的足够水平空间开始，
  /// 并随着输入额外的行而自动增长以适应。
  ///
  /// 如果不为 null，该值必须大于零，并且它会将输入锁定到给定的行数，并占用足够的垂直空间
  /// 以容纳该数量的行。同时设置 [minLines] 允许输入在指定范围内增长。
  ///
  /// [minLines] 和 [maxLines] 可能的完整行为集如下。这些示例同样适用于 `MongolTextField`、
  /// `MongolTextFormField` 和 `MongolEditableText`。
  ///
  /// 占用单行并根据需要垂直滚动的输入。
  /// ```dart
  /// MongolTextField()
  /// ```
  ///
  /// 输入宽度从一行增长到输入文本所需的任意行数。如果其父级施加宽度限制，
  /// 当宽度达到该限制时，它将水平滚动。
  /// ```dart
  /// MongolTextField(maxLines: null)
  /// ```
  ///
  /// 输入的宽度足以容纳给定的行数。如果输入额外的行，输入将水平滚动。
  /// ```dart
  /// MongolTextField(maxLines: 2)
  /// ```
  ///
  /// 输入宽度在最小和最大之间随内容增长。可以使用 `maxLines: null` 实现无限最大值。
  /// ```dart
  /// MongolTextField(minLines: 2, maxLines: 4)
  /// ```
  final int? maxLines;

  /// 当内容跨越较少行时要占用的最小行数。
  ///
  /// 如果为 null（默认值），文本容器开始时具有一行的足够水平空间，
  /// 并随着输入额外的行而增长以适应。
  ///
  /// 这可以与 [maxLines] 结合使用，以实现各种行为。
  ///
  /// 如果设置了该值，它必须大于零。如果该值大于 1，
  /// [maxLines] 也应设置为 null 或大于此值。
  ///
  /// 当同时设置 [maxLines] 时，宽度将在指定的行数范围内增长。
  /// 当 [maxLines] 为 null 时，它将从 [minLines] 开始，根据需要增长到任意宽度。
  ///
  /// 以下是 [minLines] 和 [maxLines] 可能的行为示例。
  /// 这些同样适用于 `MongolTextField`、`MongolTextFormField` 和 `MongolEditableText`。
  ///
  /// 始终至少占用 2 行且具有无限最大值的输入。
  /// 根据需要水平扩展。
  /// ```dart
  /// MongolTextField(minLines: 2)
  /// ```
  ///
  /// 输入宽度从 2 行开始，增长到 4 行，此时达到宽度限制。
  /// 如果输入额外的行，它将水平滚动。
  /// ```dart
  /// MongolTextField(minLines:2, maxLines: 4)
  /// ```
  ///
  /// 有关 [maxLines] 和 [minLines] 如何相互作用以产生各种行为的完整说明，
  /// 请参见 [maxLines] 中的示例。
  ///
  /// 默认为 null。
  final int? minLines;

  /// 此 widget 的宽度是否将调整为填充其父级。
  ///
  /// 如果设置为 true 并包装在 [Expanded] 或 [SizedBox] 等父 widget 中，
  /// 输入将扩展以填充父级。
  ///
  /// 当设置为 true 时，[maxLines] 和 [minLines] 都必须为 null，否则会抛出错误。
  ///
  /// 默认为 false。
  ///
  /// 有关 [maxLines]、[minLines] 和 [expands] 如何相互作用以产生各种行为的完整说明，
  /// 请参见 [maxLines] 中的示例。
  ///
  /// 与父级宽度匹配的输入：
  /// ```dart
  /// Expanded(
  ///   child: MongolTextField(maxLines: null, expands: true),
  /// )
  /// ```
  final bool expands;

  /// 如果没有其他内容已经聚焦，此文本字段是否应聚焦自身。
  ///
  /// 如果为 true，一旦此文本字段获得焦点，键盘就会打开。
  /// 否则，只有在用户点击文本字段后才会显示键盘。
  ///
  /// 默认为 false。不能为空。
  // 有关此键盘行为的原理，请参见 https://github.com/flutter/flutter/issues/7035。
  final bool autofocus;

  /// 绘制选择时使用的颜色。
  ///
  /// 对于 [MongolTextField]，该值设置为环境 [ThemeData.textSelectionColor]。
  final Color? selectionColor;

  /// 用于构建文本选择手柄和工具栏的可选委托。
  ///
  /// 单独使用的 [MongolEditableText] widget 不会自行触发选择工具栏的显示。
  /// 工具栏是通过响应适当的用户事件调用 [MongolEditableTextState.showToolbar] 来显示的。
  ///
  /// 另请参见：
  ///
  ///  * [MongolTextField]，[MongolEditableText] 的 Material Design 主题包装器，
  ///    它根据用户平台在 [ThemeData.platform] 中设置的内容，
  ///    在适当的用户事件时显示选择工具栏。
  final TextSelectionControls? selectionControls;

  /// 用于编辑文本的键盘类型。
  ///
  /// 如果 [maxLines] 为 1，则默认为 [TextInputType.text]，
  /// 否则默认为 [TextInputType.multiline]。
  final TextInputType keyboardType;

  /// 用于软键盘的操作按钮类型。
  final TextInputAction? textInputAction;

  /// 当用户发起对 MongolTextField 值的更改时调用：当他们插入或删除文本时。
  ///
  /// 当通过 MongolTextField 的 [controller] 以编程方式更改 MongolTextField 的文本时，
  /// 此回调不会运行。通常不需要通知此类更改，因为它们是由应用程序本身发起的。
  ///
  /// 要通知 MongolTextField 的文本、光标和选择的所有更改，
  /// 可以使用 [TextEditingController.addListener] 向其 [controller] 添加监听器。
  ///
  /// ## 处理表情符号和其他复杂字符
  ///
  /// 处理可能包含复杂字符的用户输入文本时，始终使用
  /// [characters](https://pub.dev/packages/characters) 包非常重要。
  /// 这将确保扩展字形簇和代理对被视为单个字符，就像它们在用户看来一样。
  ///
  /// 例如，当查找某些用户输入的长度时，使用 `string.characters.length`。
  /// 不要使用 `string.length` 甚至 `string.runes.length`。
  /// 对于复杂字符 "👨‍👩‍👦"，这在用户看来是一个字符，
  /// `string.characters.length` 直观地返回 1。
  /// 另一方面，`string.length` 返回 8，`string.runes.length` 返回 5！
  ///
  /// 另请参见：
  ///
  ///  * [inputFormatters]，它们在 [onChanged] 运行之前被调用，
  ///    可以验证和更改（"格式化"）输入值。
  ///  * [onEditingComplete]、[onSubmitted]、[onSelectionChanged]：
  ///    这些是更专门的输入更改通知。
  final ValueChanged<String>? onChanged;

  /// 当用户提交可编辑内容时调用（例如，用户按下键盘上的 "完成" 按钮）。
  ///
  /// [onEditingComplete] 的默认实现根据情况执行 2 种不同的行为：
  ///
  ///  - 当按下完成操作时，例如 "完成"、"前往"、"发送" 或 "搜索"，
  ///    用户的内容被提交到 [controller]，然后放弃焦点。
  ///
  ///  - 当按下非完成操作时，例如 "下一个" 或 "上一个"，
  ///    用户的内容被提交到 [controller]，但不放弃焦点，
  ///    因为开发人员可能希望在 [onSubmitted] 中立即将焦点移动到另一个输入 widget。
  ///
  /// 提供 [onEditingComplete] 会阻止上述默认行为。
  final VoidCallback? onEditingComplete;

  /// 当用户表示他们已完成编辑字段中的文本时调用。
  final ValueChanged<String>? onSubmitted;

  /// 用于接收来自输入方法的私有命令。
  ///
  /// 当收到 [TextInputClient.performPrivateCommand] 的结果时调用。
  ///
  /// 这可用于提供仅在某些输入方法与其客户端之间已知的特定于域的功能。
  ///
  /// 另请参见：
  ///   * [https://developer.android.com/reference/android/view/inputmethod/InputConnection#performPrivateCommand(java.lang.String,%20android.os.Bundle)]，
  ///     这是 performPrivateCommand 的 Android 文档，用于从输入方法发送命令。
  ///   * [https://developer.android.com/reference/android/view/inputmethod/InputMethodManager#sendAppPrivateCommand]，
  ///     这是 sendAppPrivateCommand 的 Android 文档，用于向输入方法发送命令。
  final AppPrivateCommandCallback? onAppPrivateCommand;

  /// 当用户更改文本选择（包括光标位置）时调用。
  final SelectionChangedCallback? onSelectionChanged;

  /// 当选择手柄被点击时调用的回调。
  ///
  /// 常规点击和长按都会调用此回调，但拖动手势不会。
  final VoidCallback? onSelectionHandleTapped;

  /// 当文本字段聚焦时，在 [TextFieldTapRegion] 组外部发生的每次点击都会调用。
  ///
  /// 如果为 null，当在 UI 的另一部分接收到 [PointerDownEvent] 时，
  /// 将对该文本字段的 [focusNode] 调用 [FocusNode.unfocus]。
  /// 但是，它不会因移动应用触摸事件（不包括鼠标点击）而失去焦点，
  /// 以符合平台约定。要更改此行为，可以在此处设置一个以不同方式操作的回调。
  ///
  /// 当向文本字段添加额外控件时（例如，微调器、复制选定文本或修改格式的按钮），
  /// 如果点击该控件不会使文本字段失去焦点，将会很有帮助。
  /// 为了使外部 widget 被视为文本字段的一部分（用于点击字段"外部"的目的），
  /// 将控件包装在 [TextFieldTapRegion] 中。
  ///
  /// 传递给函数的 [PointerDownEvent] 是导致通知的事件。
  /// 事件可能发生在文本字段定义的直接边界框之外，
  /// 尽管它将在 [TextFieldTapRegion] 成员的边界框内。
  ///
  /// 另请参见：
  ///
  ///  * [TapRegion]，了解如何确定区域组。
  final TapRegionCallback? onTapOutside;

  /// 可选的输入验证和格式化覆盖。
  ///
  /// 当文本输入更改时，格式化程序按提供的顺序运行。
  /// 当此参数更改时，新的格式化程序将不会应用，直到用户下次插入或删除文本。
  final List<TextInputFormatter>? inputFormatters;

  /// 鼠标指针进入或悬停在 widget 上时的光标。
  ///
  /// 如果此属性为 null，将使用适合竖排文本的水平I形光标。
  ///
  /// [mouseCursor] 是 [MongolEditableText] 中唯一控制鼠标指针外观的属性。
  /// 所有其他与 "cursor" 相关的属性都代表文本光标，
  /// 通常是编辑位置的闪烁垂直线。
  final MouseCursor? mouseCursor;

  /// 如果为 true，此 widget 创建的 [MongolRenderEditable] 将不处理指针事件，
  /// 请参见 [MongolRenderEditable] 和 [MongolRenderEditable.ignorePointer]。
  ///
  /// 此属性默认为 false。
  final bool rendererIgnoresPointer;

  /// 光标将有多宽。
  ///
  /// 如果此属性为 null，将使用 [MongolRenderEditable.preferredLineWidth]。
  final double? cursorWidth;

  /// 光标将有多厚。
  ///
  /// 默认为 2.0。
  ///
  /// 光标将在文本上方绘制。光标高度将从字符之间的边界向下延伸。
  /// 这对应于相对于所选位置向下游延伸。
  /// 可以使用负值来反转此行为。
  final double cursorHeight;

  /// 光标的角应该有多圆。
  ///
  /// 默认情况下，光标没有半径。
  final Radius? cursorRadius;

  /// 光标是否会在每次光标闪烁期间从完全透明动画到完全不透明。
  ///
  /// 默认情况下，光标不透明度将在 iOS 平台上动画，而在 Android 平台上不会动画。
  final bool cursorOpacityAnimates;

  /// 在屏幕上绘制光标时使用的偏移量（以像素为单位）。
  ///
  /// 默认情况下，在 iOS 平台上，光标位置应设置为 (0.0, -[cursorHeight] * 0.5) 的偏移量，
  /// 在 Android 平台上设置为 (0, 0)。
  /// 应用偏移量的原点是光标默认最终渲染的任意位置。
  final Offset? cursorOffset;

  /// 键盘的外观。
  ///
  /// 此设置仅在 iOS 设备上生效。
  ///
  /// 默认为 [Brightness.light]。
  final Brightness keyboardAppearance;

  /// 配置当 MongolTextField 滚动到视图中时围绕 [Scrollable] 的边缘的填充。
  ///
  /// 当此 widget 获得焦点且未完全可见时（例如，部分滚动到屏幕外或被键盘重叠），
  /// 它将尝试通过滚动周围的 [Scrollable]（如果存在）来使自己可见。
  /// 此值控制滚动后 MongolTextField 与 [Scrollable] 边缘的距离。
  ///
  /// 默认为 EdgeInsets.all(20.0)。
  final EdgeInsets scrollPadding;

  /// 是否启用用于更改文本选择的用户界面功能。
  ///
  /// 例如，将此设置为 true 将启用长按 MongolTextField 以选择文本并显示
  /// 剪切/复制/粘贴菜单，以及点击移动文本插入符等功能。
  ///
  /// 当此值为 false 时，用户无法调整文本选择，无法复制文本，
  /// 也无法从剪贴板粘贴到文本字段中。
  final bool enableInteractiveSelection;

  /// 是否允许只读字段在 Web 上建立输入连接。
  ///
  /// 默认为 true，以保留浏览器原生的复制、全选和键盘选区行为。
  /// 将其设为 false 可避免只读字段在 Web 上创建输入连接。
  final bool enableWebReadOnlyInputConnection;

  /// 将此属性设置为 true 会使光标在获得焦点后停止闪烁或淡入淡出。
  /// 此属性对测试目的很有用。
  ///
  /// 它不会影响首先聚焦 EditableText 以使光标出现的必要性。
  ///
  /// 默认为 false，导致典型的闪烁光标。
  static bool debugDeterministicCursor = false;

  /// 确定如何处理拖动开始行为。
  ///
  /// 如果设置为 [DragStartBehavior.start]，滚动拖动行为将在检测到拖动手势时开始。
  /// 如果设置为 [DragStartBehavior.down]，它将在首次检测到按下事件时开始。
  ///
  /// 一般来说，将此设置为 [DragStartBehavior.start] 将使拖动动画更平滑，
  /// 而将其设置为 [DragStartBehavior.down] 将使拖动行为感觉稍微更具响应性。
  ///
  /// 默认情况下，拖动开始行为是 [DragStartBehavior.start]。
  ///
  /// 另请参见：
  ///
  ///  * [DragGestureRecognizer.dragStartBehavior]，它给出了不同行为的示例。
  final DragStartBehavior dragStartBehavior;

  /// 用于水平滚动输入的 [ScrollController]。
  ///
  /// 如果为 null，它将实例化一个新的 ScrollController。
  ///
  /// 请参见 [Scrollable.controller]。
  final ScrollController? scrollController;

  /// 用于水平滚动输入的 [ScrollPhysics]。
  ///
  /// 如果未指定，它将根据当前平台的行为。
  ///
  /// 请参见 [Scrollable.physics]。
  ///
  /// 如果向 [scrollBehavior] 提供了显式的 [ScrollBehavior]，
  /// 则该行为提供的 [ScrollPhysics] 将在 [scrollPhysics] 之后优先。
  final ScrollPhysics? scrollPhysics;

  /// 与 [enableInteractiveSelection] 相同。
  ///
  /// 此 getter 主要是为了与 [MongolRenderEditable.selectionEnabled] 保持一致。
  bool get selectionEnabled => enableInteractiveSelection;

  /// 帮助自动填充服务识别此文本输入类型的字符串列表。
  ///
  /// 当设置为 null 或空时，此文本输入不会将其自动填充信息发送到平台，
  /// 防止它参与由不同 [AutofillClient] 触发的自动填充，
  /// 即使它们在同一个 [AutofillScope] 中。
  /// 此外，在 Android 和 web 上，将此设置为 null 或空将禁用此文本字段的自动填充。
  ///
  /// 支持自动填充的最低平台 SDK 版本是 Android 的 API 级别 26 和 iOS 的 iOS 10.0。
  ///
  /// ### 设置 iOS 自动填充：
  ///
  /// 要提供最佳用户体验并确保您的应用在 iOS 上完全支持密码自动填充，请按照以下步骤操作：
  ///
  /// * 设置您的 iOS 应用的
  ///   [关联域](https://developer.apple.com/documentation/safariservices/supporting_associated_domains_in_your_app)。
  /// * 一些自动填充提示仅适用于特定的 [keyboardType]。例如，
  ///   [AutofillHints.name] 需要 [TextInputType.name]，
  ///   [AutofillHints.email] 仅适用于 [TextInputType.emailAddress]。
  ///   确保输入字段具有兼容的 [keyboardType]。根据经验，
  ///   [TextInputType.name] 与 iOS 上预定义的许多自动填充提示配合使用效果良好。
  ///
  /// ### 自动填充故障排除
  ///
  /// 自动填充服务提供商严重依赖 [autofillHints]。
  /// 确保 [autofillHints] 中的条目受当前使用的自动填充服务支持
  ///（服务名称通常可以在移动设备的系统设置中找到）。
  ///
  /// #### 当我点击文本字段时，自动填充 UI 拒绝显示
  ///
  /// 检查设备的系统设置，确保自动填充已打开，
  /// 并且自动填充服务中存储了可用的凭据。
  ///
  /// * iOS 密码自动填充：前往设置 -> 密码，打开 "自动填充密码"，
  ///   并通过按右上角的 "+" 按钮添加新密码进行测试。
  ///   如果您的应用没有设置关联域，请使用任意 "网站"。
  ///   只要存储了至少一个密码，当密码相关字段获得焦点时，
  ///   您应该能够在软件键盘的快速输入栏中看到一个钥匙形图标。
  ///
  /// * iOS 联系信息自动填充：iOS 似乎从当前与设备关联的 Apple ID 中提取联系信息。
  ///   前往设置 -> Apple ID（通常是第一个条目，
  ///   或者如果您尚未在设备上设置，则为 "登录到您的 iPhone"），
  ///   并填写相关字段。如果您想测试更多联系信息类型，
  ///   请尝试在联系人 -> 我的卡片中添加它们。
  ///
  /// * Android 自动填充：前往设置 -> 系统 -> 语言和输入 -> 自动填充服务。
  ///   启用您选择的自动填充服务，并确保有与您的应用关联的可用凭据。
  ///
  /// #### 我调用了 `TextInput.finishAutofillContext`，但自动填充保存提示没有显示
  ///
  /// * iOS：iOS 在保存用户密码时可能不会显示提示或任何其他视觉指示。
  ///   前往设置 -> 密码，检查您的新密码是否已保存。
  ///   如果没有正确设置应用中的关联域，
  ///   保存密码和自动生成强密码都不起作用。
  ///   要设置关联域，请按照 <https://developer.apple.com/documentation/safariservices/supporting_associated_domains_in_your_app> 中的说明进行操作。
  final Iterable<String>? autofillHints;

  /// 控制此输入字段自动填充行为的 [AutofillClient]。
  ///
  /// 当为 null 时，此 widget 的 [MongolEditableTextState] 将用作 [AutofillClient]。
  /// 此属性可能会覆盖 [autofillHints]。
  final AutofillClient? autofillClient;

  /// 内容将根据此选项被裁剪（或不被裁剪）。
  ///
  /// 有关所有可能选项及其常见用例的详细信息，请参见枚举 [Clip]。
  ///
  /// 默认为 [Clip.hardEdge]。
  final Clip clipBehavior;

  /// 用于保存和恢复 [MongolEditableText] 滚动偏移的恢复 ID。
  ///
  /// 如果提供了恢复 ID，[MongolEditableText] 将保留其当前滚动偏移并在状态恢复期间恢复它。
  ///
  /// 滚动偏移存储在使用提供的恢复 ID 从周围 [RestorationScope] 声明的 [RestorationBucket] 中。
  ///
  /// 保留和恢复 [MongolEditableText] 内容的责任由 [controller] 的所有者承担，
  /// 他们可以为此目的使用 [RestorableTextEditingController]。
  ///
  /// 另请参见：
  ///
  ///  * [RestorationManager]，它解释了 Flutter 中状态恢复的工作原理。
  final String? restorationId;

  /// 将单独应用于此 widget 的 [ScrollBehavior]。
  ///
  /// 默认为 null，其中继承的 [ScrollBehavior] 被复制并修改以更改视口装饰，如 [Scrollbar]。
  ///
  /// [ScrollBehavior] 还提供 [ScrollPhysics]。
  /// 如果在 [scrollPhysics] 中提供了显式的 [ScrollPhysics]，
  /// 它将优先，然后是 [scrollBehavior]，然后是继承的祖先 [ScrollBehavior]。
  ///
  /// 继承的 [ScrollConfiguration] 的 [ScrollBehavior] 将默认修改为仅在 [maxLines] 大于 1 时应用 [Scrollbar]。
  final ScrollBehavior? scrollBehavior;

  /// {@template flutter.widgets.editableText.contentInsertionConfiguration}
  /// 通过系统输入方法插入的媒体内容的处理程序配置。
  ///
  /// 默认为 null，在这种情况下，媒体内容插入将被禁用，
  /// 系统将显示一条消息，通知用户文本字段不支持插入媒体内容。
  ///
  /// 设置 [ContentInsertionConfiguration.onContentInserted] 以提供处理程序。
  /// 此外，设置 [ContentInsertionConfiguration.allowedMimeTypes]
  /// 以限制插入内容的允许 MIME 类型。
  ///
  /// {@tool dartpad}
  ///
  /// 此示例显示如何在您的 `TextField` 中访问插入内容的数据。
  ///
  /// ** 请参见 examples/api/lib/widgets/editable_text/editable_text.on_content_inserted.0.dart 中的代码 **
  /// {@end-tool}
  ///
  /// 如果未提供 [contentInsertionConfiguration]，默认情况下
  /// 一个空的 MIME 类型列表将发送到 Flutter 引擎。
  /// 必须提供处理函数以自定义插入内容的允许 MIME 类型。
  ///
  /// 如果在没有处理程序的情况下插入富内容，系统将显示
  /// 一条消息，通知用户当前文本输入不支持插入富内容。
  /// {@endtemplate}
  final ContentInsertionConfiguration? contentInsertionConfiguration;

  /// 当用户请求时构建文本选择工具栏。
  ///
  /// `primaryAnchor` 是上下文菜单的所需锚点位置，
  /// 而 `secondaryAnchor` 是菜单不适合时的回退位置。
  ///
  /// `buttonItems` 表示为此 widget 默认构建的按钮。
  ///
  /// 如果未提供，将不显示上下文菜单。
  final MongolEditableTextContextMenuBuilder? contextMenuBuilder;

  final TextMagnifierConfiguration magnifierConfiguration;

  bool get _userSelectionEnabled =>
      enableInteractiveSelection && (!readOnly || !obscureText);

  /// 返回表示此平台默认可编辑字段选择菜单中按钮的 [ContextMenuButtonItem]。
  ///
  /// 例如，[MongolEditableText] 使用此方法为其上下文菜单生成默认按钮。
  ///
  /// 另请参见：
  ///
  /// * [MongolEditableTextState.contextMenuButtonItems]，它为特定的 MongolEditableText 提供 [ContextMenuButtonItem]。
  /// * [SelectableRegion.getSelectableButtonItems]，它执行类似的角色，但适用于可选择但不可编辑的内容。
  static List<ContextMenuButtonItem> getEditableButtonItems({
    required final ClipboardStatus? clipboardStatus,
    required final VoidCallback? onCopy,
    required final VoidCallback? onCut,
    required final VoidCallback? onPaste,
    required final VoidCallback? onSelectAll,
  }) {
    // 如果粘贴按钮已启用，在剪贴板状态已知之前不要渲染任何内容，
    // 因为它用于确定是否显示粘贴按钮。
    if (onPaste != null && clipboardStatus == ClipboardStatus.unknown) {
      return <ContextMenuButtonItem>[];
    }

    return <ContextMenuButtonItem>[
      if (onCut != null)
        ContextMenuButtonItem(
          onPressed: onCut,
          type: ContextMenuButtonType.cut,
        ),
      if (onCopy != null)
        ContextMenuButtonItem(
          onPressed: onCopy,
          type: ContextMenuButtonType.copy,
        ),
      if (onPaste != null)
        ContextMenuButtonItem(
          onPressed: onPaste,
          type: ContextMenuButtonType.paste,
        ),
      if (onSelectAll != null)
        ContextMenuButtonItem(
          onPressed: onSelectAll,
          type: ContextMenuButtonType.selectAll,
        ),
    ];
  }

  /// 如果未指定，推断 `MongolEditableText` 的键盘类型。
  static TextInputType _inferKeyboardType({
    required Iterable<String>? autofillHints,
    required int? maxLines,
  }) {
    if (autofillHints == null || autofillHints.isEmpty) {
      return maxLines == 1 ? TextInputType.text : TextInputType.multiline;
    }

    final String effectiveHint = autofillHints.first;

    // 在 iOS 上，通常指定文本内容类型不足以使输入字段符合自动填充条件。
    // 键盘类型也需要与内容类型兼容。为了让 MongolEditableText 上的自动填充默认工作，
    // iOS 上的键盘类型推断与其他平台不同。
    //
    // 带有 "autofill not working" 注释的条目是 iOS 文本内容类型，
    // 它们应该与指定的键盘类型一起工作，但不会触发（即使在原生应用程序中）。
    // 在 iOS 13.5 上测试。
    if (!kIsWeb) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          const Map<String, TextInputType> iOSKeyboardType =
              <String, TextInputType>{
            AutofillHints.addressCity: TextInputType.name,
            AutofillHints.addressCityAndState: TextInputType.name, // 自动填充不工作。
            AutofillHints.addressState: TextInputType.name,
            AutofillHints.countryName: TextInputType.name,
            AutofillHints.creditCardNumber: TextInputType.number, // 无法测试。
            AutofillHints.email: TextInputType.emailAddress,
            AutofillHints.familyName: TextInputType.name,
            AutofillHints.fullStreetAddress: TextInputType.name,
            AutofillHints.givenName: TextInputType.name,
            AutofillHints.jobTitle: TextInputType.name, // 自动填充不工作。
            AutofillHints.location: TextInputType.name, // 自动填充不工作。
            AutofillHints.middleName: TextInputType.name, // 自动填充不工作。
            AutofillHints.name: TextInputType.name,
            AutofillHints.namePrefix: TextInputType.name, // 自动填充不工作。
            AutofillHints.nameSuffix: TextInputType.name, // 自动填充不工作。
            AutofillHints.newPassword: TextInputType.text,
            AutofillHints.newUsername: TextInputType.text,
            AutofillHints.nickname: TextInputType.name, // 自动填充不工作。
            AutofillHints.oneTimeCode: TextInputType.number,
            AutofillHints.organizationName: TextInputType.text, // 自动填充不工作。
            AutofillHints.password: TextInputType.text,
            AutofillHints.postalCode: TextInputType.name,
            AutofillHints.streetAddressLine1: TextInputType.name,
            AutofillHints.streetAddressLine2: TextInputType.name, // 自动填充不工作。
            AutofillHints.sublocality: TextInputType.name, // 自动填充不工作。
            AutofillHints.telephoneNumber: TextInputType.name,
            AutofillHints.url: TextInputType.url, // 自动填充不工作。
            AutofillHints.username: TextInputType.text,
          };

          final TextInputType? keyboardType = iOSKeyboardType[effectiveHint];
          if (keyboardType != null) {
            return keyboardType;
          }
          break;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          break;
      }
    }

    if (maxLines != 1) {
      return TextInputType.multiline;
    }

    const inferKeyboardType = <String, TextInputType>{
      AutofillHints.addressCity: TextInputType.streetAddress,
      AutofillHints.addressCityAndState: TextInputType.streetAddress,
      AutofillHints.addressState: TextInputType.streetAddress,
      AutofillHints.birthday: TextInputType.datetime,
      AutofillHints.birthdayDay: TextInputType.datetime,
      AutofillHints.birthdayMonth: TextInputType.datetime,
      AutofillHints.birthdayYear: TextInputType.datetime,
      AutofillHints.countryCode: TextInputType.number,
      AutofillHints.countryName: TextInputType.text,
      AutofillHints.creditCardExpirationDate: TextInputType.datetime,
      AutofillHints.creditCardExpirationDay: TextInputType.datetime,
      AutofillHints.creditCardExpirationMonth: TextInputType.datetime,
      AutofillHints.creditCardExpirationYear: TextInputType.datetime,
      AutofillHints.creditCardFamilyName: TextInputType.name,
      AutofillHints.creditCardGivenName: TextInputType.name,
      AutofillHints.creditCardMiddleName: TextInputType.name,
      AutofillHints.creditCardName: TextInputType.name,
      AutofillHints.creditCardNumber: TextInputType.number,
      AutofillHints.creditCardSecurityCode: TextInputType.number,
      AutofillHints.creditCardType: TextInputType.text,
      AutofillHints.email: TextInputType.emailAddress,
      AutofillHints.familyName: TextInputType.name,
      AutofillHints.fullStreetAddress: TextInputType.streetAddress,
      AutofillHints.gender: TextInputType.text,
      AutofillHints.givenName: TextInputType.name,
      AutofillHints.impp: TextInputType.url,
      AutofillHints.jobTitle: TextInputType.text,
      AutofillHints.language: TextInputType.text,
      AutofillHints.location: TextInputType.streetAddress,
      AutofillHints.middleInitial: TextInputType.name,
      AutofillHints.middleName: TextInputType.name,
      AutofillHints.name: TextInputType.name,
      AutofillHints.namePrefix: TextInputType.name,
      AutofillHints.nameSuffix: TextInputType.name,
      AutofillHints.newPassword: TextInputType.text,
      AutofillHints.newUsername: TextInputType.text,
      AutofillHints.nickname: TextInputType.text,
      AutofillHints.oneTimeCode: TextInputType.text,
      AutofillHints.organizationName: TextInputType.text,
      AutofillHints.password: TextInputType.text,
      AutofillHints.photo: TextInputType.text,
      AutofillHints.postalAddress: TextInputType.streetAddress,
      AutofillHints.postalAddressExtended: TextInputType.streetAddress,
      AutofillHints.postalAddressExtendedPostalCode: TextInputType.number,
      AutofillHints.postalCode: TextInputType.number,
      AutofillHints.streetAddressLevel1: TextInputType.streetAddress,
      AutofillHints.streetAddressLevel2: TextInputType.streetAddress,
      AutofillHints.streetAddressLevel3: TextInputType.streetAddress,
      AutofillHints.streetAddressLevel4: TextInputType.streetAddress,
      AutofillHints.streetAddressLine1: TextInputType.streetAddress,
      AutofillHints.streetAddressLine2: TextInputType.streetAddress,
      AutofillHints.streetAddressLine3: TextInputType.streetAddress,
      AutofillHints.sublocality: TextInputType.streetAddress,
      AutofillHints.telephoneNumber: TextInputType.phone,
      AutofillHints.telephoneNumberAreaCode: TextInputType.phone,
      AutofillHints.telephoneNumberCountryCode: TextInputType.phone,
      AutofillHints.telephoneNumberDevice: TextInputType.phone,
      AutofillHints.telephoneNumberExtension: TextInputType.phone,
      AutofillHints.telephoneNumberLocal: TextInputType.phone,
      AutofillHints.telephoneNumberLocalPrefix: TextInputType.phone,
      AutofillHints.telephoneNumberLocalSuffix: TextInputType.phone,
      AutofillHints.telephoneNumberNational: TextInputType.phone,
      AutofillHints.transactionAmount:
          TextInputType.numberWithOptions(decimal: true),
      AutofillHints.transactionCurrency: TextInputType.text,
      AutofillHints.url: TextInputType.url,
      AutofillHints.username: TextInputType.text,
    };

    return inferKeyboardType[effectiveHint] ?? TextInputType.text;
  }

  @override
  MongolEditableTextState createState() => MongolEditableTextState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        DiagnosticsProperty<TextEditingController>('controller', controller));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode));
    properties.add(DiagnosticsProperty<bool>('obscureText', obscureText,
        defaultValue: false));
    properties.add(DiagnosticsProperty<bool>('autocorrect', autocorrect,
        defaultValue: true));
    properties.add(DiagnosticsProperty<bool>(
        'enableSuggestions', enableSuggestions,
        defaultValue: true));
    style.debugFillProperties(properties);
    properties.add(EnumProperty<MongolTextAlign>('textAlign', textAlign,
        defaultValue: null));
    properties.add(
        DoubleProperty('textScaleFactor', textScaleFactor, defaultValue: null));
    properties.add(IntProperty('maxLines', maxLines, defaultValue: 1));
    properties.add(IntProperty('minLines', minLines, defaultValue: null));
    properties.add(
        DiagnosticsProperty<bool>('expands', expands, defaultValue: false));
    properties.add(
        DiagnosticsProperty<bool>('autofocus', autofocus, defaultValue: false));
    properties.add(DiagnosticsProperty<TextInputType>(
        'keyboardType', keyboardType,
        defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollController>(
        'scrollController', scrollController,
        defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollPhysics>(
        'scrollPhysics', scrollPhysics,
        defaultValue: null));
    properties.add(DiagnosticsProperty<Iterable<String>>(
        'autofillHints', autofillHints,
        defaultValue: null));
    properties.add(DiagnosticsProperty<bool>(
        'enableInteractiveSelection', enableInteractiveSelection,
        defaultValue: true));
    properties.add(DiagnosticsProperty<List<String>>('contentCommitMimeTypes',
        contentInsertionConfiguration?.allowedMimeTypes ?? const <String>[],
        defaultValue: contentInsertionConfiguration == null
            ? const <String>[]
            : kDefaultContentInsertionMimeTypes));
  }
}

/// [MongolEditableText] 的状态。
class MongolEditableTextState extends State<MongolEditableText>
    with
        AutomaticKeepAliveClientMixin<MongolEditableText>,
        WidgetsBindingObserver,
        TickerProviderStateMixin<MongolEditableText>,
        TextSelectionDelegate,
        TextInputClient
    implements AutofillClient {
  Timer? _cursorTimer; // 控制光标闪烁的计时器
  AnimationController get _cursorBlinkOpacityController {
    return _backingCursorBlinkOpacityController ??= AnimationController(
      vsync: this,
    )..addListener(_onCursorColorTick);
  }

  AnimationController? _backingCursorBlinkOpacityController; // 光标闪烁透明度动画控制器
  late final Simulation _iosBlinkCursorSimulation =
      _DiscreteKeyFrameSimulation.iOSBlinkingCaret(); // iOS 风格的光标闪烁模拟

  final ValueNotifier<bool> _cursorVisibilityNotifier =
      ValueNotifier<bool>(true); // 光标可见性通知器
  final GlobalKey _editableKey = GlobalKey(); // 可编辑文本的全局键

  /// 检测剪贴板是否可以粘贴。
  final ClipboardStatusNotifier? clipboardStatus =
      kIsWeb ? null : ClipboardStatusNotifier();

  TextInputConnection? _textInputConnection; // 与平台文本输入系统的连接
  bool get _hasInputConnection =>
      _textInputConnection?.attached ?? false; // 是否有活跃的输入连接

  MongolTextSelectionOverlay? _selectionOverlay; // 文本选择覆盖层

  final GlobalKey _scrollableKey = GlobalKey(); // 可滚动组件的全局键
  ScrollController? _internalScrollController; // 内部滚动控制器
  ScrollController get _scrollController =>
      widget.scrollController ??
      (_internalScrollController ??= ScrollController()); // 获取滚动控制器

  final LayerLink _toolbarLayerLink = LayerLink(); // 工具栏层链接
  final LayerLink _startHandleLayerLink = LayerLink(); // 开始选择手柄层链接
  final LayerLink _endHandleLayerLink = LayerLink(); // 结束选择手柄层链接

  bool _didAutoFocus = false; // 是否已自动聚焦

  AutofillGroupState? _currentAutofillScope; // 当前自动填充作用域

  @override
  AutofillScope? get currentAutofillScope => _currentAutofillScope;

  AutofillClient get _effectiveAutofillClient =>
      widget.autofillClient ?? this; // 有效的自动填充客户端

  /// 是否与平台创建文本编辑的输入连接。
  ///
  /// Read-only input fields do not need a connection with the platform since
  /// there's no need for text editing capabilities (e.g. virtual keyboard).
  ///
  /// On the web, we always need a connection because we want some browser
  /// functionalities to continue to work on read-only input fields like:
  ///
  /// - Relevant context menu.
  /// - cmd/ctrl+c shortcut to copy.
  /// - cmd/ctrl+a to select all.
  /// - Changing the selection using a physical keyboard.
  bool get _shouldCreateInputConnection =>
      !widget.readOnly || (kIsWeb && widget.enableWebReadOnlyInputConnection);

  Orientation? _lastOrientation;

  int? _viewId;

  @override
  bool get wantKeepAlive => widget.focusNode.hasFocus;

  Color get _cursorColor =>
      widget.cursorColor.withOpacity(_cursorBlinkOpacityController.value);

  @override
  bool get cutEnabled {
    if (widget.selectionControls is! TextSelectionHandleControls) {
      return widget.toolbarOptions.cut &&
          !widget.readOnly &&
          !widget.obscureText;
    }
    return !widget.readOnly &&
        !widget.obscureText &&
        !textEditingValue.selection.isCollapsed;
  }

  @override
  bool get copyEnabled {
    if (widget.selectionControls is! TextSelectionHandleControls) {
      return widget.toolbarOptions.copy && !widget.obscureText;
    }
    return !widget.obscureText && !textEditingValue.selection.isCollapsed;
  }

  @override
  bool get pasteEnabled {
    if (widget.selectionControls is! TextSelectionHandleControls) {
      return widget.toolbarOptions.paste && !widget.readOnly;
    }
    return !widget.readOnly &&
        (clipboardStatus == null ||
            clipboardStatus!.value == ClipboardStatus.pasteable);
  }

  @override
  bool get selectAllEnabled {
    if (widget.selectionControls is! TextSelectionHandleControls) {
      return widget.toolbarOptions.selectAll &&
          (!widget.readOnly || !widget.obscureText) &&
          widget.enableInteractiveSelection;
    }

    if (!widget.enableInteractiveSelection ||
        (widget.readOnly && widget.obscureText)) {
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        return false;
      case TargetPlatform.iOS:
        return textEditingValue.text.isNotEmpty &&
            textEditingValue.selection.isCollapsed;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return textEditingValue.text.isNotEmpty &&
            !(textEditingValue.selection.start == 0 &&
                textEditingValue.selection.end == textEditingValue.text.length);
    }
  }

  void _onChangedClipboardStatus() {
    setState(() {
      // Inform the widget that the value of clipboardStatus has changed.
    });
  }

  TextEditingValue get _textEditingValueForTextLayoutMetrics {
    final Widget? editableWidget = _editableKey.currentContext?.widget;
    if (editableWidget is! _MongolEditable) {
      throw StateError('_Editable must be mounted.');
    }
    return editableWidget.value;
  }

  /// Copy current selection to [Clipboard].
  @override
  void copySelection(SelectionChangedCause cause) {
    final TextSelection selection = textEditingValue.selection;
    if (selection.isCollapsed || widget.obscureText) {
      return;
    }
    final String text = textEditingValue.text;
    Clipboard.setData(ClipboardData(text: selection.textInside(text)));
    if (cause == SelectionChangedCause.toolbar) {
      bringIntoView(textEditingValue.selection.extent);
      hideToolbar(false);

      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          break;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          // Collapse the selection and hide the toolbar and handles.
          userUpdateTextEditingValue(
            TextEditingValue(
              text: textEditingValue.text,
              selection: TextSelection.collapsed(
                  offset: textEditingValue.selection.end),
            ),
            SelectionChangedCause.toolbar,
          );
          break;
      }
    }
    clipboardStatus?.update();
  }

  /// Cut current selection to [Clipboard].
  @override
  void cutSelection(SelectionChangedCause cause) {
    if (widget.readOnly || widget.obscureText) {
      return;
    }
    final TextSelection selection = textEditingValue.selection;
    final String text = textEditingValue.text;
    if (selection.isCollapsed) {
      return;
    }
    Clipboard.setData(ClipboardData(text: selection.textInside(text)));
    _replaceText(ReplaceTextIntent(textEditingValue, '', selection, cause));
    if (cause == SelectionChangedCause.toolbar) {
      // Schedule a call to bringIntoView() after renderEditable updates.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          bringIntoView(textEditingValue.selection.extent);
        }
      });
      hideToolbar();
    }
    clipboardStatus?.update();
  }

  /// Paste text from [Clipboard].
  @override
  Future<void> pasteText(SelectionChangedCause cause) async {
    if (widget.readOnly) {
      return;
    }
    final TextSelection selection = textEditingValue.selection;
    if (!selection.isValid) {
      return;
    }
    // Snapshot the input before using `await`.
    // See https://github.com/flutter/flutter/issues/11427
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null) {
      return;
    }

    // After the paste, the cursor should be collapsed and located after the
    // pasted content.
    final int lastSelectionIndex =
        math.max(selection.baseOffset, selection.extentOffset);
    final TextEditingValue collapsedTextEditingValue =
        textEditingValue.copyWith(
      selection: TextSelection.collapsed(offset: lastSelectionIndex),
    );

    userUpdateTextEditingValue(
      collapsedTextEditingValue.replaced(selection, data.text!),
      cause,
    );
    if (cause == SelectionChangedCause.toolbar) {
      // Schedule a call to bringIntoView() after renderEditable updates.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          bringIntoView(textEditingValue.selection.extent);
        }
      });
      hideToolbar();
    }
  }

  /// Select the entire text value.
  @override
  void selectAll(SelectionChangedCause cause) {
    if (widget.readOnly && widget.obscureText) {
      // If we can't modify it, and we can't copy it, there's no point in
      // selecting it.
      return;
    }
    userUpdateTextEditingValue(
      textEditingValue.copyWith(
        selection: TextSelection(
            baseOffset: 0, extentOffset: textEditingValue.text.length),
      ),
      cause,
    );

    if (cause == SelectionChangedCause.toolbar) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.iOS:
        case TargetPlatform.fuchsia:
          break;
        case TargetPlatform.macOS:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          hideToolbar();
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          bringIntoView(textEditingValue.selection.extent);
          break;
        case TargetPlatform.macOS:
        case TargetPlatform.iOS:
          break;
      }
    }
  }

  /// This method is not yet implemented and always returns null.
  SuggestionSpan? findSuggestionSpanAtCursorIndex(int cursorIndex) {
    // Spellcheck is not implemented yet.
    return null;
  }

  /// This method is not yet implemented and always returns false.
  bool showSpellCheckSuggestionsToolbar() {
    // Spellcheck is not implemented yet.
    return false;
  }

  /// Returns the [ContextMenuButtonItem]s for the given [ToolbarOptions].
  @Deprecated(
    'Use `contextMenuBuilder` instead of `toolbarOptions`. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  List<ContextMenuButtonItem>? buttonItemsForToolbarOptions(
      [TargetPlatform? targetPlatform]) {
    final ToolbarOptions toolbarOptions = widget.toolbarOptions;
    if (toolbarOptions == ToolbarOptions.empty) {
      return null;
    }
    return <ContextMenuButtonItem>[
      if (toolbarOptions.cut && cutEnabled)
        ContextMenuButtonItem(
          onPressed: () {
            cutSelection(SelectionChangedCause.toolbar);
          },
          type: ContextMenuButtonType.cut,
        ),
      if (toolbarOptions.copy && copyEnabled)
        ContextMenuButtonItem(
          onPressed: () {
            copySelection(SelectionChangedCause.toolbar);
          },
          type: ContextMenuButtonType.copy,
        ),
      if (toolbarOptions.paste && clipboardStatus != null && pasteEnabled)
        ContextMenuButtonItem(
          onPressed: () {
            pasteText(SelectionChangedCause.toolbar);
          },
          type: ContextMenuButtonType.paste,
        ),
      if (toolbarOptions.selectAll && selectAllEnabled)
        ContextMenuButtonItem(
          onPressed: () {
            selectAll(SelectionChangedCause.toolbar);
          },
          type: ContextMenuButtonType.selectAll,
        ),
    ];
  }

  /// Gets the line widths at the start and end of the selection for the given
  /// [MongolEditableTextState].
  _GlyphWidths _getGlyphWidths() {
    final TextSelection selection = textEditingValue.selection;

    // Only calculate handle rects if the text in the previous frame
    // is the same as the text in the current frame. This is done because
    // widget.renderObject contains the renderEditable from the previous frame.
    // If the text changed between the current and previous frames then
    // widget.renderObject.getRectForComposingRange might fail. In cases where
    // the current frame is different from the previous we fall back to
    // renderObject.preferredLineHeight.
    final TextSpan span = renderEditable.text!;
    final String prevText = span.toPlainText();
    final String currentText = textEditingValue.text;
    if (prevText != currentText ||
        !selection.isValid ||
        selection.isCollapsed) {
      return _GlyphWidths(
        start: renderEditable.preferredLineWidth,
        end: renderEditable.preferredLineWidth,
      );
    }

    final String selectedGraphemes = selection.textInside(currentText);
    final int firstSelectedGraphemeExtent =
        selectedGraphemes.characters.first.length;
    final Rect? startCharacterRect =
        renderEditable.getRectForComposingRange(TextRange(
      start: selection.start,
      end: selection.start + firstSelectedGraphemeExtent,
    ));
    final int lastSelectedGraphemeExtent =
        selectedGraphemes.characters.last.length;
    final Rect? endCharacterRect =
        renderEditable.getRectForComposingRange(TextRange(
      start: selection.end - lastSelectedGraphemeExtent,
      end: selection.end,
    ));
    return _GlyphWidths(
      start: startCharacterRect?.width ?? renderEditable.preferredLineWidth,
      end: endCharacterRect?.width ?? renderEditable.preferredLineWidth,
    );
  }

  /// Returns the anchor points for the default context menu.
  TextSelectionToolbarAnchors get contextMenuAnchors {
    if (renderEditable.lastSecondaryTapDownPosition != null) {
      return TextSelectionToolbarAnchors(
        primaryAnchor: renderEditable.lastSecondaryTapDownPosition!,
      );
    }

    final _GlyphWidths glyphWidths = _getGlyphWidths();
    final TextSelection selection = textEditingValue.selection;
    final List<TextSelectionPoint> points =
        renderEditable.getEndpointsForSelection(selection);
    return TextSelectionToolbarAnchors.fromSelection(
      renderBox: renderEditable,
      startGlyphHeight: glyphWidths.start,
      endGlyphHeight: glyphWidths.end,
      selectionEndpoints: points,
    );
  }

  /// Returns the [ContextMenuButtonItem]s representing the buttons in this
  /// platform's default selection menu for [MongolEditableText].
  List<ContextMenuButtonItem> get contextMenuButtonItems {
    return buttonItemsForToolbarOptions() ??
        MongolEditableText.getEditableButtonItems(
          clipboardStatus: clipboardStatus?.value,
          onCopy: copyEnabled
              ? () => copySelection(SelectionChangedCause.toolbar)
              : null,
          onCut: cutEnabled
              ? () => cutSelection(SelectionChangedCause.toolbar)
              : null,
          onPaste: pasteEnabled
              ? () => pasteText(SelectionChangedCause.toolbar)
              : null,
          onSelectAll: selectAllEnabled
              ? () => selectAll(SelectionChangedCause.toolbar)
              : null,
        );
  }

  // todo editor-fixes copy from [EditableTextState]
  @override
  void autofill(TextEditingValue value) => updateEditingValue(value);

  @override
  void insertTextPlaceholder(Size size) {
    // todo editor-fixes should we implement it?
  }

  @override
  void removeTextPlaceholder() {
    // todo editor-fixes should we implement it?
  }

  // State lifecycle:

  @override
  void initState() {
    super.initState();
    injectVerticalTextCursorStyle();
    clipboardStatus?.addListener(_onChangedClipboardStatus);
    widget.controller.addListener(_didChangeTextEditingValue);
    widget.focusNode.addListener(_handleFocusChanged);
    _scrollController.addListener(_onEditableScroll);
    _cursorVisibilityNotifier.value = widget.showCursor;
  }

  // Whether `TickerMode.of(context)` is true and animations (like blinking the
  // cursor) are supposed to run.
  bool _tickersEnabled = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final AutofillGroupState? newAutofillGroup = AutofillGroup.maybeOf(context);
    if (currentAutofillScope != newAutofillGroup) {
      _currentAutofillScope?.unregister(autofillId);
      _currentAutofillScope = newAutofillGroup;
      _currentAutofillScope?.register(_effectiveAutofillClient);
    }

    if (!_didAutoFocus && widget.autofocus) {
      _didAutoFocus = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && renderEditable.hasSize) {
          FocusScope.of(context).autofocus(widget.focusNode);
        }
      });
    }

    // Restart or stop the blinking cursor when TickerMode changes.
    final bool newTickerEnabled = TickerMode.of(context);
    if (_tickersEnabled != newTickerEnabled) {
      _tickersEnabled = newTickerEnabled;
      if (_tickersEnabled && _cursorActive) {
        _startCursorBlink();
      } else if (!_tickersEnabled && _cursorTimer != null) {
        _cursorTimer!.cancel();
        _cursorTimer = null;
      }
    }

    // Check for changes in viewId.
    if (_hasInputConnection) {
      final int newViewId = View.of(context).viewId;
      if (newViewId != _viewId) {
        _textInputConnection!
            .updateConfig(_effectiveAutofillClient.textInputConfiguration);
      }
    }

    if (!_isIOS && !_isAndroid) {
      return;
    }

    // Hide the text selection toolbar on mobile when orientation changes.
    final Orientation orientation = MediaQuery.of(context).orientation;
    if (_lastOrientation == null) {
      _lastOrientation = orientation;
      return;
    }
    if (orientation != _lastOrientation) {
      _lastOrientation = orientation;
      if (_isIOS) {
        hideToolbar(false);
      }
      if (_isAndroid) {
        hideToolbar();
      }
    }
  }

  @override
  void didUpdateWidget(MongolEditableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_didChangeTextEditingValue);
      widget.controller.addListener(_didChangeTextEditingValue);
      _updateRemoteEditingValueIfNeeded();
    }
    if (widget.controller.selection != oldWidget.controller.selection) {
      _selectionOverlay?.update(_value);
    }
    _selectionOverlay?.handlesVisible = widget.showSelectionHandles;

    if (widget.autofillClient != oldWidget.autofillClient) {
      _currentAutofillScope
          ?.unregister(oldWidget.autofillClient?.autofillId ?? autofillId);
      _currentAutofillScope?.register(_effectiveAutofillClient);
    }

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      widget.focusNode.addListener(_handleFocusChanged);
      updateKeepAlive();
    }

    if (widget.scrollController != oldWidget.scrollController) {
      (oldWidget.scrollController ?? _internalScrollController)
          ?.removeListener(_onEditableScroll);
      _scrollController.addListener(_onEditableScroll);
    }

    if (!_shouldCreateInputConnection) {
      _closeInputConnectionIfNeeded();
    } else if (oldWidget.readOnly && _hasFocus) {
      _openInputConnection();
    }

    if (kIsWeb && _hasInputConnection) {
      if (oldWidget.readOnly != widget.readOnly) {
        _textInputConnection!
            .updateConfig(_effectiveAutofillClient.textInputConfiguration);
      }
    }

    if (widget.style != oldWidget.style) {
      final TextStyle style = widget.style;
      // The _textInputConnection will pick up the new style when it attaches in
      // _openInputConnection.
      if (_hasInputConnection) {
        _textInputConnection!.setStyle(
          fontFamily: style.fontFamily,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          textDirection: TextDirection.ltr,
          textAlign: _rotatedTextAlign(widget.textAlign),
        );
      }
    }
    final bool canPaste =
        widget.selectionControls is TextSelectionHandleControls
            ? pasteEnabled
            : widget.selectionControls?.canPaste(this) ?? false;
    if (widget.selectionEnabled &&
        pasteEnabled &&
        clipboardStatus != null &&
        canPaste) {
      clipboardStatus!.update();
    }
  }

  TextAlign _rotatedTextAlign(MongolTextAlign mongolTextAlign) {
    switch (mongolTextAlign) {
      case MongolTextAlign.top:
        return TextAlign.left;
      case MongolTextAlign.center:
        return ui.TextAlign.center;
      case MongolTextAlign.bottom:
        return TextAlign.right;
      case MongolTextAlign.justify:
        return TextAlign.justify;
    }
  }

  @override
  void dispose() {
    _internalScrollController?.dispose();
    _currentAutofillScope?.unregister(autofillId);
    widget.controller.removeListener(_didChangeTextEditingValue);
    _closeInputConnectionIfNeeded();
    assert(!_hasInputConnection);
    _cursorTimer?.cancel();
    _cursorTimer = null;
    _backingCursorBlinkOpacityController?.dispose();
    _backingCursorBlinkOpacityController = null;
    _selectionOverlay?.dispose();
    _selectionOverlay = null;
    widget.focusNode.removeListener(_handleFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    clipboardStatus?.removeListener(_onChangedClipboardStatus);
    clipboardStatus?.dispose();
    _cursorVisibilityNotifier.dispose();
    super.dispose();
    assert(_batchEditDepth <= 0, 'unfinished batch edits: $_batchEditDepth');
  }

  // TextInputClient implementation:

  /// The last known [TextEditingValue] of the platform text input plugin.
  ///
  /// This value is updated when the platform text input plugin sends a new
  /// update via [updateEditingValue], or when [MongolEditableText] calls
  /// [TextInputConnection.setEditingState] to overwrite the platform text input
  /// plugin's [TextEditingValue].
  ///
  /// Used in [_updateRemoteEditingValueIfNeeded] to determine whether the
  /// remote value is outdated and needs updating.
  TextEditingValue? _lastKnownRemoteTextEditingValue;

  @override
  TextEditingValue get currentTextEditingValue => _value;

  @override
  void updateEditingValue(TextEditingValue value) {
    // This method handles text editing state updates from the platform text
    // input plugin. The [MongolEditableText] may not have the focus or an open
    // input connection, as autofill can update a disconnected
    // [MongolEditableText].

    // Since we still have to support keyboard select, this is the best place
    // to disable text updating.
    if (!_shouldCreateInputConnection) {
      return;
    }

    if (_checkNeedsAdjustAffinity(value)) {
      value = value.copyWith(
          selection:
              value.selection.copyWith(affinity: _value.selection.affinity));
    }

    if (widget.readOnly) {
      // In the read-only case, we only care about selection changes, and reject
      // everything else.
      value = _value.copyWith(selection: value.selection);
    }
    _lastKnownRemoteTextEditingValue = value;

    if (value == _value) {
      // This is possible, for example, when the numeric keyboard is input,
      // the engine will notify twice for the same value.
      // Track at https://github.com/flutter/flutter/issues/65811
      return;
    }

    if (value.text == _value.text && value.composing == _value.composing) {
      // `selection` is the only change.
      _handleSelectionChanged(
          value.selection,
          (_textInputConnection?.scribbleInProgress ?? false)
              ? SelectionChangedCause.scribble
              : SelectionChangedCause.keyboard);
    } else {
      // Only hide the toolbar overlay, the selection handle's visibility will be handled
      // by `_handleSelectionChanged`. https://github.com/flutter/flutter/issues/108673
      hideToolbar(false);

      final bool revealObscuredInput = _hasInputConnection &&
          widget.obscureText &&
          WidgetsBinding.instance.platformDispatcher.brieflyShowPassword &&
          value.text.length == _value.text.length + 1;

      _obscureShowCharTicksPending =
          revealObscuredInput ? _kObscureShowLatestCharCursorTicks : 0;
      _obscureLatestCharIndex =
          revealObscuredInput ? _value.selection.baseOffset : null;
      _formatAndSetValue(value, SelectionChangedCause.keyboard);
    }

    // Wherever the value is changed by the user, schedule a showCaretOnScreen
    // to make sure the user can see the changes they just made. Programmatical
    // changes to `textEditingValue` do not trigger the behavior even if the
    // text field is focused.
    _scheduleShowCaretOnScreen(withAnimation: true);
    if (_hasInputConnection) {
      // To keep the cursor from blinking while typing, we want to restart the
      // cursor timer every time a new character is typed.
      _stopCursorBlink(resetCharTicks: false);
      _startCursorBlink();
    }
  }

  bool _checkNeedsAdjustAffinity(TextEditingValue value) {
    // Trust the engine affinity if the text changes or selection changes.
    return value.text == _value.text &&
        value.selection.isCollapsed == _value.selection.isCollapsed &&
        value.selection.start == _value.selection.start &&
        value.selection.affinity != _value.selection.affinity;
  }

  @override
  void performAction(TextInputAction action) {
    switch (action) {
      case TextInputAction.newline:
        // If this is a multiline EditableText, do nothing for a "newline"
        // action; The newline is already inserted. Otherwise, finalize
        // editing.
        if (!_isMultiline) _finalizeEditing(action, shouldUnfocus: true);
        break;
      case TextInputAction.done:
      case TextInputAction.go:
      case TextInputAction.next:
      case TextInputAction.previous:
      case TextInputAction.search:
      case TextInputAction.send:
        _finalizeEditing(action, shouldUnfocus: true);
        break;
      case TextInputAction.continueAction:
      case TextInputAction.emergencyCall:
      case TextInputAction.join:
      case TextInputAction.none:
      case TextInputAction.route:
      case TextInputAction.unspecified:
        // Finalize editing, but don't give up focus because this keyboard
        // action does not imply the user is done inputting information.
        _finalizeEditing(action, shouldUnfocus: false);
        break;
    }
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    widget.onAppPrivateCommand!(action, data);
  }

  @override
  void insertContent(KeyboardInsertedContent content) {
    assert(widget.contentInsertionConfiguration?.allowedMimeTypes
            .contains(content.mimeType) ??
        false);
    widget.contentInsertionConfiguration?.onContentInserted.call(content);
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // unimplemented
  }

  @pragma('vm:notify-debugger-on-exception')
  void _finalizeEditing(TextInputAction action, {required bool shouldUnfocus}) {
    // Take any actions necessary now that the user has completed editing.
    if (widget.onEditingComplete != null) {
      try {
        widget.onEditingComplete!();
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'widgets',
          context:
              ErrorDescription('while calling onEditingComplete for $action'),
        ));
      }
    } else {
      // Default behavior if the developer did not provide an
      // onEditingComplete callback: Finalize editing and remove focus, or move
      // it to the next/previous field, depending on the action.
      widget.controller.clearComposing();
      if (shouldUnfocus) {
        switch (action) {
          case TextInputAction.none:
          case TextInputAction.unspecified:
          case TextInputAction.done:
          case TextInputAction.go:
          case TextInputAction.search:
          case TextInputAction.send:
          case TextInputAction.continueAction:
          case TextInputAction.join:
          case TextInputAction.route:
          case TextInputAction.emergencyCall:
          case TextInputAction.newline:
            widget.focusNode.unfocus();
            break;
          case TextInputAction.next:
            widget.focusNode.nextFocus();
            break;
          case TextInputAction.previous:
            widget.focusNode.previousFocus();
            break;
        }
      }
    }

    final ValueChanged<String>? onSubmitted = widget.onSubmitted;
    if (onSubmitted == null) {
      return;
    }

    // Invoke optional callback with the user's submitted content.
    try {
      onSubmitted(_value.text);
    } catch (exception, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'widgets',
        context: ErrorDescription('while calling onSubmitted for $action'),
      ));
    }

    // If `shouldUnfocus` is true, the text field should no longer be focused
    // after the microtask queue is drained. But in case the developer cancelled
    // the focus change in the `onSubmitted` callback by focusing this input
    // field again, reset the soft keyboard.
    // See https://github.com/flutter/flutter/issues/84240.
    //
    // `_restartConnectionIfNeeded` creates a new TextInputConnection to replace
    // the current one. This on iOS switches to a new input view and on Android
    // restarts the input method, and in both cases the soft keyboard will be
    // reset.
    if (shouldUnfocus) {
      _scheduleRestartConnection();
    }
  }

  int _batchEditDepth = 0;

  /// Begins a new batch edit, within which new updates made to the text editing
  /// value will not be sent to the platform text input plugin.
  ///
  /// Batch edits nest. When the outermost batch edit finishes, [endBatchEdit]
  /// will attempt to send [currentTextEditingValue] to the text input plugin if
  /// it detected a change.
  void beginBatchEdit() {
    _batchEditDepth += 1;
  }

  /// Ends the current batch edit started by the last call to [beginBatchEdit],
  /// and send [currentTextEditingValue] to the text input plugin if needed.
  ///
  /// Throws an error in debug mode if this [EditableText] is not in a batch
  /// edit.
  void endBatchEdit() {
    _batchEditDepth -= 1;
    assert(
      _batchEditDepth >= 0,
      'Unbalanced call to endBatchEdit: beginBatchEdit must be called first.',
    );
    _updateRemoteEditingValueIfNeeded();
  }

  void _updateRemoteEditingValueIfNeeded() {
    if (_batchEditDepth > 0 || !_hasInputConnection) return;
    final localValue = _value;
    if (localValue == _lastKnownRemoteTextEditingValue) return;
    _textInputConnection!.setEditingState(localValue);
    _lastKnownRemoteTextEditingValue = localValue;
  }

  TextEditingValue get _value => widget.controller.value;
  set _value(TextEditingValue value) {
    widget.controller.value = value;
  }

  bool get _hasFocus => widget.focusNode.hasFocus;

  // On desktop platforms there is no virtual keyboard and the focus system
  // does not set a keyboard token on requestFocus(), so consumeKeyboardToken()
  // always returns false. We must open the TextInputConnection unconditionally
  // whenever the field gains focus on desktop.
  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isMobilePlatform =>
      _isAndroid || _isIOS || defaultTargetPlatform == TargetPlatform.fuchsia;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows);
  bool get _isMultiline => widget.maxLines != 1;

  // Finds the closest scroll offset to the current scroll offset that fully
  // reveals the given caret rect. If the given rect's main axis extent is too
  // large to be fully revealed in `renderEditable`, it will be centered along
  // the main axis.
  //
  // If this is a multiline MongolEditableText (which means the Editable can only
  // scroll horizontally), the given rect's width will first be extended to match
  // `renderEditable.preferredLineWidth`, before the target scroll offset is
  // calculated.
  RevealedOffset _getOffsetToRevealCaret(Rect rect) {
    if (!_scrollController.position.allowImplicitScrolling) {
      return RevealedOffset(offset: _scrollController.offset, rect: rect);
    }

    final editableSize = renderEditable.size;
    final double additionalOffset;
    final Offset unitOffset;

    if (!_isMultiline) {
      additionalOffset = rect.height >= editableSize.height
          // Center `rect` if it's oversized.
          ? editableSize.height / 2 - rect.center.dy
          // Valid additional offsets range from (rect.bottom - size.height)
          // to (rect.top). Pick the closest one if out of range.
          : clampDouble(0.0, rect.bottom - editableSize.height, rect.top);
      unitOffset = const Offset(0, 1);
    } else {
      // The caret is horizontally centered within the line. Expand the caret's
      // width so that it spans the line because we're going to ensure that the
      // entire expanded caret is scrolled into view.
      final expandedRect = Rect.fromCenter(
        center: rect.center,
        height: rect.height,
        width: math.max(rect.width, renderEditable.preferredLineWidth),
      );

      additionalOffset = expandedRect.width >= editableSize.width
          ? editableSize.width / 2 - expandedRect.center.dx
          : clampDouble(
              0.0, expandedRect.right - editableSize.width, expandedRect.left);
      unitOffset = const Offset(1, 0);
    }

    // No overscrolling when encountering tall fonts/scripts that extend past
    // the ascent.
    final double targetOffset = clampDouble(
      additionalOffset + _scrollController.offset,
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );

    final offsetDelta = _scrollController.offset - targetOffset;
    return RevealedOffset(
        rect: rect.shift(unitOffset * offsetDelta), offset: targetOffset);
  }

  /// Whether to send the autofill information to the autofill service.
  bool get _needsAutofill => widget.autofillHints?.isNotEmpty ?? false;

  void _openInputConnection() {
    if (!_shouldCreateInputConnection) {
      return;
    }
    if (!_hasInputConnection) {
      final localValue = _value;

      // When _needsAutofill == true && currentAutofillScope == null, autofill
      // is allowed but saving the user input from the text field is
      // discouraged.
      //
      // In case the autofillScope changes from a non-null value to null, or
      // _needsAutofill changes to false from true, the platform needs to be
      // notified to exclude this field from the autofill context. So we need to
      // provide the autofillId.
      // todo editor-fixes replace with below code
      // _textInputConnection = _needsAutofill && currentAutofillScope != null
      //     ? currentAutofillScope!.attach(this, textInputConfiguration)
      //     : TextInput.attach(
      //         this,
      //         _createTextInputConfiguration(
      //             _isInAutofillContext || _needsAutofill));
      _textInputConnection = _needsAutofill && currentAutofillScope != null
          ? currentAutofillScope!
              .attach(this, _effectiveAutofillClient.textInputConfiguration)
          : TextInput.attach(
              this, _effectiveAutofillClient.textInputConfiguration);
      _textInputConnection!.show();
      _updateSizeAndTransform();
      _updateComposingRectIfNeeded();
      _updateCaretRectIfNeeded();
      if (_needsAutofill) {
        // Request autofill AFTER the size and the transform have been sent to
        // the platform text input plugin.
        _textInputConnection!.requestAutofill();
      }

      final style = widget.style;
      _textInputConnection!
        ..setStyle(
          fontFamily: style.fontFamily,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          textDirection: TextDirection.ltr,
          textAlign: _rotatedTextAlign(widget.textAlign),
        )
        ..setEditingState(localValue);
    } else {
      _textInputConnection!.show();
    }
  }

  void _closeInputConnectionIfNeeded() {
    if (_hasInputConnection) {
      _textInputConnection!.close();
      _textInputConnection = null;
      _lastKnownRemoteTextEditingValue = null;
    }
  }

  void _openOrCloseInputConnectionIfNeeded() {
    if (_hasFocus && (widget.focusNode.consumeKeyboardToken() || _isDesktop)) {
      _openInputConnection();
    } else if (!_hasFocus) {
      _closeInputConnectionIfNeeded();
      widget.controller.clearComposing();
    }
  }

  bool _restartConnectionScheduled = false;
  void _scheduleRestartConnection() {
    if (_restartConnectionScheduled) {
      return;
    }
    _restartConnectionScheduled = true;
    scheduleMicrotask(_restartConnectionIfNeeded);
  }

  // Discards the current [TextInputConnection] and establishes a new one.
  //
  // This method is rarely needed. This is currently used to reset the input
  // type when the "submit" text input action is triggered and the developer
  // puts the focus back to this input field..
  void _restartConnectionIfNeeded() {
    _restartConnectionScheduled = false;
    if (!_hasInputConnection || !_shouldCreateInputConnection) {
      return;
    }
    _textInputConnection!.close();
    _textInputConnection = null;
    _lastKnownRemoteTextEditingValue = null;

    final AutofillScope? currentAutofillScope =
        _needsAutofill ? this.currentAutofillScope : null;
    final TextInputConnection newConnection = currentAutofillScope?.attach(
            this, textInputConfiguration) ??
        TextInput.attach(this, _effectiveAutofillClient.textInputConfiguration);
    _textInputConnection = newConnection;

    final TextStyle style = widget.style;
    newConnection
      ..show()
      ..setStyle(
        fontFamily: style.fontFamily,
        fontSize: style.fontSize,
        fontWeight: style.fontWeight,
        textDirection: TextDirection.ltr,
        textAlign: _rotatedTextAlign(widget.textAlign),
      )
      ..setEditingState(_value);
    _lastKnownRemoteTextEditingValue = _value;
  }

  @override
  void didChangeInputControl(
      TextInputControl? oldControl, TextInputControl? newControl) {
    if (_hasFocus && _hasInputConnection) {
      oldControl?.hide();
      newControl?.show();
    }
  }

  @override
  void connectionClosed() {
    if (_hasInputConnection) {
      _textInputConnection!.connectionClosedReceived();
      _textInputConnection = null;
      _lastKnownRemoteTextEditingValue = null;
      _finalizeEditing(TextInputAction.done, shouldUnfocus: true);
    }
  }

  /// Express interest in interacting with the keyboard.
  ///
  /// If this control is already attached to the keyboard, this function will
  /// request that the keyboard become visible. Otherwise, this function will
  /// ask the focus system that it become focused. If successful in acquiring
  /// focus, the control will then attach to the keyboard and request that the
  /// keyboard become visible.
  void requestKeyboard() {
    if (_hasFocus) {
      _openInputConnection();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  void _updateOrDisposeSelectionOverlayIfNeeded() {
    if (_selectionOverlay != null) {
      if (_hasFocus) {
        _selectionOverlay!.update(_value);
      } else {
        _selectionOverlay!.dispose();
        _selectionOverlay = null;
      }
    }
  }

  void _onEditableScroll() {
    _selectionOverlay?.updateForScroll();
  }

  MongolTextSelectionOverlay _createSelectionOverlay() {
    final selectionOverlay = MongolTextSelectionOverlay(
      clipboardStatus: clipboardStatus,
      context: context,
      value: _value,
      debugRequiredFor: widget,
      toolbarLayerLink: _toolbarLayerLink,
      startHandleLayerLink: _startHandleLayerLink,
      endHandleLayerLink: _endHandleLayerLink,
      renderObject: renderEditable,
      selectionControls: widget.selectionControls,
      selectionDelegate: this,
      dragStartBehavior: widget.dragStartBehavior,
      onSelectionHandleTapped: widget.onSelectionHandleTapped,
      contextMenuBuilder: widget.contextMenuBuilder == null
          ? null
          : (BuildContext context) {
              return widget.contextMenuBuilder!(
                context,
                this,
              );
            },
      magnifierConfiguration: widget.magnifierConfiguration,
    );

    return selectionOverlay;
  }

  @pragma('vm:notify-debugger-on-exception')
  void _handleSelectionChanged(
      TextSelection selection, SelectionChangedCause? cause) {
    // We return early if the selection is not valid. This can happen when the
    // text of [MongolEditableText] is updated at the same time as the selection is
    // changed by a gesture event.
    if (!widget.controller.isSelectionWithinTextBounds(selection)) return;

    widget.controller.selection = selection;

    // This will show the keyboard for all selection changes on the
    // MongolEditableText except for those triggered by a keyboard input.
    // Typically MongolEditableText shouldn't take user keyboard input if
    // it's not focused already. If the MongolEditableText is being
    // autofilled it shouldn't request focus.
    switch (cause) {
      case null:
      case SelectionChangedCause.doubleTap:
      case SelectionChangedCause.drag:
      case SelectionChangedCause.forcePress:
      case SelectionChangedCause.longPress:
      case SelectionChangedCause.scribble:
      case SelectionChangedCause.tap:
      case SelectionChangedCause.toolbar:
        requestKeyboard();
        break;
      case SelectionChangedCause.keyboard:
        if (_hasFocus) {
          requestKeyboard();
        }
        break;
    }
    if (widget.selectionControls == null && widget.contextMenuBuilder == null) {
      _selectionOverlay?.dispose();
      _selectionOverlay = null;
    } else {
      if (_selectionOverlay == null) {
        _selectionOverlay = _createSelectionOverlay();
      } else {
        _selectionOverlay!.update(_value);
      }
      _selectionOverlay!.handlesVisible = widget.showSelectionHandles;
      _selectionOverlay!.showHandles();
    }
    try {
      widget.onSelectionChanged?.call(selection, cause);
    } catch (exception, stack) {
      debugPrint('Error while calling onSelectionChanged for $cause');
      debugPrint(stack.toString());
    }

    // To keep the cursor from blinking while it moves, restart the timer here.
    if (_cursorTimer != null) {
      _stopCursorBlink(resetCharTicks: false);
      _startCursorBlink();
    }
  }

  // Animation configuration for scrolling the caret back on screen.
  static const Duration _caretAnimationDuration = Duration(milliseconds: 100);
  static const Curve _caretAnimationCurve = Curves.fastOutSlowIn;

  bool _showCaretOnScreenScheduled = false;

  void _scheduleShowCaretOnScreen({required bool withAnimation}) {
    if (_showCaretOnScreenScheduled) {
      return;
    }
    _showCaretOnScreenScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _showCaretOnScreenScheduled = false;
      // Since we are in a post frame callback, check currentContext in case
      // RenderEditable has been disposed (in which case it will be null).
      final renderEditable = _editableKey.currentContext?.findRenderObject()
          as MongolRenderEditable?;
      if (renderEditable == null ||
          !(renderEditable.selection?.isValid ?? false) ||
          !_scrollController.hasClients) {
        return;
      }

      final lineWidth = renderEditable.preferredLineWidth;

      // Enlarge the target rect by scrollPadding to ensure that caret is not
      // positioned directly at the edge after scrolling.
      var rightSpacing = widget.scrollPadding.right;
      if (_selectionOverlay?.selectionControls != null) {
        final handleWidth = _selectionOverlay!.selectionControls!
            .getHandleSize(lineWidth)
            .width;
        final interactiveHandleWidth = math.max(
          handleWidth,
          kMinInteractiveDimension,
        );
        final anchor = _selectionOverlay!.selectionControls!.getHandleAnchor(
          TextSelectionHandleType.collapsed,
          lineWidth,
        );
        final handleCenter = handleWidth / 2 - anchor.dx;
        rightSpacing = math.max(
          handleCenter + interactiveHandleWidth / 2,
          rightSpacing,
        );
      }

      final caretPadding = widget.scrollPadding.copyWith(right: rightSpacing);

      final caretRect =
          renderEditable.getLocalRectForCaret(renderEditable.selection!.extent);
      final targetOffset = _getOffsetToRevealCaret(caretRect);

      final Rect rectToReveal;
      final TextSelection selection = textEditingValue.selection;
      if (selection.isCollapsed) {
        rectToReveal = targetOffset.rect;
      } else {
        final List<Rect> selectionBoxes =
            renderEditable.getBoxesForSelection(selection);
        rectToReveal = selection.baseOffset < selection.extentOffset
            ? selectionBoxes.last
            : selectionBoxes.first;
      }

      if (withAnimation) {
        _scrollController.animateTo(
          targetOffset.offset,
          duration: _caretAnimationDuration,
          curve: _caretAnimationCurve,
        );
        renderEditable.showOnScreen(
          rect: caretPadding.inflateRect(rectToReveal),
          duration: _caretAnimationDuration,
          curve: _caretAnimationCurve,
        );
      } else {
        _scrollController.jumpTo(targetOffset.offset);
        if (_value.selection.isCollapsed) {
          renderEditable.showOnScreen(
            rect: caretPadding.inflateRect(rectToReveal),
          );
        }
      }
    });
  }

  // keeping "bottom" rather than changing it to "right" because it likely refers
  // to the keyboard location. But this might be wrong.
  late double _lastBottomViewInset;

  @override
  void didChangeMetrics() {
    if (_lastBottomViewInset !=
        WidgetsBinding.instance.window.viewInsets.bottom) {
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        _selectionOverlay?.updateForScroll();
      });
      if (_lastBottomViewInset <
          WidgetsBinding.instance.window.viewInsets.bottom) {
        // Because the metrics change signal from engine will come here every frame
        // (on both iOS and Android). So we don't need to show caret with animation.
        _scheduleShowCaretOnScreen(withAnimation: false);
      }
    }
    _lastBottomViewInset = WidgetsBinding.instance.window.viewInsets.bottom;
  }

  @pragma('vm:notify-debugger-on-exception')
  void _formatAndSetValue(TextEditingValue value, SelectionChangedCause? cause,
      {bool userInteraction = false}) {
    // Only apply input formatters if the text has changed (including uncommited
    // text in the composing region), or when the user committed the composing
    // text.
    // Gboard is very persistent in restoring the composing region. Applying
    // input formatters on composing-region-only changes (except clearing the
    // current composing region) is very infinite-loop-prone: the formatters
    // will keep trying to modify the composing region while Gboard will keep
    // trying to restore the original composing region.
    final textChanged = _value.text != value.text ||
        (!_value.composing.isCollapsed && value.composing.isCollapsed);
    final selectionChanged = _value.selection != value.selection;

    if (textChanged) {
      value = widget.inputFormatters?.fold<TextEditingValue>(
            value,
            (TextEditingValue newValue, TextInputFormatter formatter) =>
                formatter.formatEditUpdate(_value, newValue),
          ) ??
          value;
    }

    // Put all optional user callback invocations in a batch edit to prevent
    // sending multiple `TextInput.updateEditingValue` messages.
    beginBatchEdit();
    _value = value;
    // Changes made by the keyboard can sometimes be "out of band" for listening
    // components, so always send those events, even if we didn't think it
    // changed. Also, the user long pressing should always send a selection change
    // as well.
    if (selectionChanged ||
        (userInteraction &&
            (cause == SelectionChangedCause.longPress ||
                cause == SelectionChangedCause.keyboard))) {
      _handleSelectionChanged(_value.selection, cause);
    }
    if (textChanged) {
      try {
        widget.onChanged?.call(_value.text);
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'widgets',
          context: ErrorDescription('while calling onChanged'),
        ));
      }
    }

    endBatchEdit();
  }

  void _onCursorColorTick() {
    renderEditable.cursorColor =
        widget.cursorColor.withOpacity(_cursorBlinkOpacityController.value);
    _cursorVisibilityNotifier.value =
        widget.showCursor && _cursorBlinkOpacityController.value > 0;
  }

  /// Whether the blinking cursor is actually visible at this precise moment
  /// (it's hidden half the time, since it blinks).
  @visibleForTesting
  bool get cursorCurrentlyVisible => _cursorBlinkOpacityController.value > 0;

  /// The cursor blink interval (the amount of time the cursor is in the "on"
  /// state or the "off" state). A complete cursor blink period is twice this
  /// value (half on, half off).
  @visibleForTesting
  Duration get cursorBlinkInterval => _kCursorBlinkHalfPeriod;

  /// The current status of the text selection handles.
  @visibleForTesting
  MongolTextSelectionOverlay? get selectionOverlay => _selectionOverlay;

  int _obscureShowCharTicksPending = 0;
  int? _obscureLatestCharIndex;

  // Indicates whether the cursor should be blinking right now (but it may
  // actually not blink because it's disabled via TickerMode.of(context)).
  bool _cursorActive = false;

  void _startCursorBlink() {
    assert(!(_cursorTimer?.isActive ?? false) ||
        !(_backingCursorBlinkOpacityController?.isAnimating ?? false));
    _cursorActive = true;
    if (!_tickersEnabled) {
      return;
    }
    _cursorTimer?.cancel();
    _cursorBlinkOpacityController.value = 1.0;
    if (MongolEditableText.debugDeterministicCursor) {
      return;
    }
    if (widget.cursorOpacityAnimates) {
      _cursorBlinkOpacityController
          .animateWith(_iosBlinkCursorSimulation)
          .whenComplete(_onCursorTick);
    } else {
      _cursorTimer = Timer.periodic(_kCursorBlinkHalfPeriod, (Timer timer) {
        _onCursorTick();
      });
    }
  }

  void _onCursorTick() {
    if (_obscureShowCharTicksPending > 0) {
      _obscureShowCharTicksPending =
          WidgetsBinding.instance.platformDispatcher.brieflyShowPassword
              ? _obscureShowCharTicksPending - 1
              : 0;
      if (_obscureShowCharTicksPending == 0) {
        setState(() {});
      }
    }

    if (widget.cursorOpacityAnimates) {
      _cursorTimer?.cancel();
      // Schedule this as an async task to avoid blocking tester.pumpAndSettle
      // indefinitely.
      _cursorTimer = Timer(
          Duration.zero,
          () => _cursorBlinkOpacityController
              .animateWith(_iosBlinkCursorSimulation)
              .whenComplete(_onCursorTick));
    } else {
      if (!(_cursorTimer?.isActive ?? false) && _tickersEnabled) {
        _cursorTimer = Timer.periodic(_kCursorBlinkHalfPeriod, (Timer timer) {
          _onCursorTick();
        });
      }
      _cursorBlinkOpacityController.value =
          _cursorBlinkOpacityController.value == 0 ? 1 : 0;
    }
  }

  void _stopCursorBlink({bool resetCharTicks = true}) {
    _cursorActive = false;
    _cursorBlinkOpacityController.value = 0.0;
    _cursorTimer?.cancel();
    _cursorTimer = null;
    if (resetCharTicks) {
      _obscureShowCharTicksPending = 0;
    }
  }

  void _startOrStopCursorTimerIfNeeded() {
    if (_cursorTimer == null && _hasFocus && _value.selection.isCollapsed) {
      _startCursorBlink();
    } else if (_cursorActive && (!_hasFocus || !_value.selection.isCollapsed)) {
      _stopCursorBlink();
    }
  }

  void _didChangeTextEditingValue() {
    _updateRemoteEditingValueIfNeeded();
    _startOrStopCursorTimerIfNeeded();
    _updateOrDisposeSelectionOverlayIfNeeded();
    setState(() {
      /* We use widget.controller.value in build(). */
    });
    _adjacentLineAction.stopCurrentVerticalRunIfSelectionChanges();
  }

  void _handleFocusChanged() {
    _openOrCloseInputConnectionIfNeeded();
    _startOrStopCursorTimerIfNeeded();
    _updateOrDisposeSelectionOverlayIfNeeded();
    if (_hasFocus) {
      // Listen for changing viewInsets, which indicates keyboard showing up.
      WidgetsBinding.instance.addObserver(this);
      _lastBottomViewInset = WidgetsBinding.instance.window.viewInsets.bottom;
      if (!widget.readOnly) {
        _scheduleShowCaretOnScreen(withAnimation: true);
      }
      if (!_value.selection.isValid) {
        // Place cursor at the end if the selection is invalid when we receive focus.
        _handleSelectionChanged(
            TextSelection.collapsed(offset: _value.text.length), null);
      }
    } else {
      WidgetsBinding.instance.removeObserver(this);
      setState(() {});
    }
    updateKeepAlive();
  }

  void _updateSizeAndTransform() {
    if (_hasInputConnection) {
      final size = renderEditable.size;
      final transform = renderEditable.getTransformTo(null);
      _textInputConnection!.setEditableSizeAndTransform(size, transform);
      SchedulerBinding.instance
          .addPostFrameCallback((Duration _) => _updateSizeAndTransform());
    }
  }

  // Sends the current composing rect to the iOS text input plugin via the text
  // input channel. We need to keep sending the information even if no text is
  // currently marked, as the information usually lags behind. The text input
  // plugin needs to estimate the composing rect based on the latest caret rect,
  // when the composing rect info didn't arrive in time.
  void _updateComposingRectIfNeeded() {
    final composingRange = _value.composing;
    if (_hasInputConnection) {
      assert(mounted);
      var composingRect =
          renderEditable.getRectForComposingRange(composingRange);
      // Send the caret location instead if there's no marked text yet.
      if (composingRect == null) {
        assert(!composingRange.isValid || composingRange.isCollapsed);
        final offset = composingRange.isValid ? composingRange.start : 0;
        composingRect =
            renderEditable.getLocalRectForCaret(TextPosition(offset: offset));
      }
      _textInputConnection!.setComposingRect(composingRect);
      SchedulerBinding.instance
          .addPostFrameCallback((Duration _) => _updateComposingRectIfNeeded());
    }
  }

  void _updateCaretRectIfNeeded() {
    if (_hasInputConnection) {
      if (renderEditable.selection != null &&
          renderEditable.selection!.isValid &&
          renderEditable.selection!.isCollapsed) {
        final TextPosition currentTextPosition =
            TextPosition(offset: renderEditable.selection!.baseOffset);
        final Rect caretRect =
            renderEditable.getLocalRectForCaret(currentTextPosition);
        _textInputConnection!.setCaretRect(caretRect);
      }
      SchedulerBinding.instance
          .addPostFrameCallback((Duration _) => _updateCaretRectIfNeeded());
    }
  }

  /// The renderer for this widget's descendant.
  ///
  /// This property is typically used to notify the renderer of input gestures
  /// when [MongolRenderEditable.ignorePointer] is true.
  late final MongolRenderEditable renderEditable =
      _editableKey.currentContext!.findRenderObject()! as MongolRenderEditable;

  @override
  TextEditingValue get textEditingValue => _value;

  double get _devicePixelRatio => MediaQuery.of(context).devicePixelRatio;

  @override
  void userUpdateTextEditingValue(
      TextEditingValue value, SelectionChangedCause? cause) {
    // Compare the current TextEditingValue with the pre-format new
    // TextEditingValue value, in case the formatter would reject the change.
    final bool shouldShowCaret =
        widget.readOnly ? _value.selection != value.selection : _value != value;
    if (shouldShowCaret) {
      _scheduleShowCaretOnScreen(withAnimation: true);
    }

    // Even if the value doesn't change, it may be necessary to focus and build
    // the selection overlay. For example, this happens when right clicking an
    // unfocused field that previously had a selection in the same spot.
    if (value == textEditingValue) {
      if (!widget.focusNode.hasFocus) {
        widget.focusNode.requestFocus();
        _selectionOverlay = _createSelectionOverlay();
      }
      return;
    }

    _formatAndSetValue(value, cause, userInteraction: true);
  }

  @override
  void bringIntoView(TextPosition position) {
    final localRect = renderEditable.getLocalRectForCaret(position);
    final targetOffset = _getOffsetToRevealCaret(localRect);

    _scrollController.jumpTo(targetOffset.offset);
    renderEditable.showOnScreen(rect: targetOffset.rect);
  }

  /// Shows the selection toolbar at the location of the current cursor.
  ///
  /// Returns `false` if a toolbar couldn't be shown, such as when the toolbar
  /// is already shown, or when no text selection currently exists.
  @override
  bool showToolbar() {
    if (_selectionOverlay == null || _selectionOverlay!.toolbarIsVisible) {
      return false;
    }

    _selectionOverlay!.showToolbar();
    return true;
  }

  @override
  void hideToolbar([bool hideHandles = true]) {
    if (hideHandles) {
      // Hide the handles and the toolbar.
      _selectionOverlay?.hide();
    } else {
      // Hide only the toolbar but not the handles.
      _selectionOverlay?.hideToolbar();
    }
  }

  /// Toggles the visibility of the toolbar.
  void toggleToolbar([bool hideHandles = true]) {
    final MongolTextSelectionOverlay selectionOverlay =
        _selectionOverlay ??= _createSelectionOverlay();

    if (selectionOverlay.toolbarIsVisible) {
      hideToolbar(hideHandles);
    } else {
      showToolbar();
    }
  }

  /// Shows the magnifier at the position given by `positionToShow`,
  /// if there is no magnifier visible.
  ///
  /// Updates the magnifier to the position given by `positionToShow`,
  /// if there is a magnifier visible.
  ///
  /// Does nothing if a magnifier couldn't be shown, such as when the selection
  /// overlay does not currently exist.
  void showMagnifier(Offset positionToShow) {
    if (_selectionOverlay == null) {
      return;
    }

    if (_selectionOverlay!.magnifierIsVisible) {
      _selectionOverlay!.updateMagnifier(positionToShow);
    } else {
      _selectionOverlay!.showMagnifier(positionToShow);
    }
  }

  /// Hides the magnifier if it is visible.
  void hideMagnifier() {
    if (_selectionOverlay == null) {
      return;
    }

    if (_selectionOverlay!.magnifierIsVisible) {
      _selectionOverlay!.hideMagnifier();
    }
  }

  @override
  void performSelector(String selectorName) {
    final Intent? intent = intentForMacOSSelector(selectorName);

    if (intent != null) {
      final BuildContext? primaryContext = primaryFocus?.context;
      if (primaryContext != null) {
        Actions.invoke(primaryContext, intent);
      }
    }
  }

  @override
  String get autofillId => 'MongolEditableText-$hashCode';

  @override
  TextInputConfiguration get textInputConfiguration {
    final List<String>? autofillHints =
        widget.autofillHints?.toList(growable: false);
    final AutofillConfiguration autofillConfiguration = autofillHints != null
        ? AutofillConfiguration(
            uniqueIdentifier: autofillId,
            autofillHints: autofillHints,
            currentEditingValue: currentTextEditingValue,
          )
        : AutofillConfiguration.disabled;

    _viewId = View.of(context).viewId;
    return TextInputConfiguration(
      viewId: _viewId,
      inputType: widget.keyboardType,
      readOnly: widget.readOnly,
      obscureText: widget.obscureText,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      enableInteractiveSelection: widget._userSelectionEnabled,
      inputAction: widget.textInputAction ??
          (widget.keyboardType == TextInputType.multiline
              ? TextInputAction.newline
              : TextInputAction.done),
      keyboardAppearance: widget.keyboardAppearance,
      autofillConfiguration: autofillConfiguration,
    );
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // unimplemented
  }

  VoidCallback? _semanticsOnCopy(TextSelectionControls? controls) {
    return widget.selectionEnabled &&
            _hasFocus &&
            (widget.selectionControls is TextSelectionHandleControls
                ? copyEnabled
                : copyEnabled &&
                    (widget.selectionControls?.canCopy(this) ?? false))
        ? () {
            controls?.handleCopy(this);
            copySelection(SelectionChangedCause.toolbar);
          }
        : null;
  }

  VoidCallback? _semanticsOnCut(TextSelectionControls? controls) {
    return widget.selectionEnabled &&
            _hasFocus &&
            (widget.selectionControls is TextSelectionHandleControls
                ? cutEnabled
                : cutEnabled &&
                    (widget.selectionControls?.canCut(this) ?? false))
        ? () {
            controls?.handleCut(this);
            cutSelection(SelectionChangedCause.toolbar);
          }
        : null;
  }

  VoidCallback? _semanticsOnPaste(TextSelectionControls? controls) {
    return widget.selectionEnabled &&
            _hasFocus &&
            (widget.selectionControls is TextSelectionHandleControls
                ? pasteEnabled
                : pasteEnabled &&
                    (widget.selectionControls?.canPaste(this) ?? false)) &&
            (clipboardStatus == null ||
                clipboardStatus!.value == ClipboardStatus.pasteable)
        ? () {
            controls?.handlePaste(this);
            pasteText(SelectionChangedCause.toolbar);
          }
        : null;
  }

  // --------------------------- Text Editing Actions ---------------------------

  _TextBoundary _characterBoundary(DirectionalTextEditingIntent intent) {
    final _TextBoundary atomicTextBoundary = widget.obscureText
        ? _CodeUnitBoundary(_value)
        : _CharacterBoundary(_value);
    return _CollapsedSelectionBoundary(atomicTextBoundary, intent.forward);
  }

  _TextBoundary _nextWordBoundary(DirectionalTextEditingIntent intent) {
    final _TextBoundary atomicTextBoundary;
    final _TextBoundary boundary;

    if (widget.obscureText) {
      atomicTextBoundary = _CodeUnitBoundary(_value);
      boundary = _DocumentBoundary(_value);
    } else {
      final TextEditingValue textEditingValue =
          _textEditingValueForTextLayoutMetrics;
      atomicTextBoundary = _CharacterBoundary(textEditingValue);
      // This isn't enough. Newline characters.
      boundary = _ExpandedTextBoundary(_WhitespaceBoundary(textEditingValue),
          _WordBoundary(renderEditable, textEditingValue));
    }

    final _MixedBoundary mixedBoundary = intent.forward
        ? _MixedBoundary(atomicTextBoundary, boundary)
        : _MixedBoundary(boundary, atomicTextBoundary);
    // Use a _MixedBoundary to make sure we don't leave invalid codepoints in
    // the field after deletion.
    return _CollapsedSelectionBoundary(mixedBoundary, intent.forward);
  }

  _TextBoundary _linebreak(DirectionalTextEditingIntent intent) {
    final _TextBoundary atomicTextBoundary;
    final _TextBoundary boundary;

    if (widget.obscureText) {
      atomicTextBoundary = _CodeUnitBoundary(_value);
      boundary = _DocumentBoundary(_value);
    } else {
      final TextEditingValue textEditingValue =
          _textEditingValueForTextLayoutMetrics;
      atomicTextBoundary = _CharacterBoundary(textEditingValue);
      boundary = _LineBreak(renderEditable, textEditingValue);
    }

    // The _MixedBoundary is to make sure we don't leave invalid code units in
    // the field after deletion.
    // `boundary` doesn't need to be wrapped in a _CollapsedSelectionBoundary,
    // since the document boundary is unique and the linebreak boundary is
    // already caret-location based.
    return intent.forward
        ? _MixedBoundary(
            _CollapsedSelectionBoundary(atomicTextBoundary, true), boundary)
        : _MixedBoundary(
            boundary, _CollapsedSelectionBoundary(atomicTextBoundary, false));
  }

  void _updateSelection(UpdateSelectionIntent intent) {
    bringIntoView(intent.newSelection.extent);
    userUpdateTextEditingValue(
      intent.currentTextEditingValue.copyWith(selection: intent.newSelection),
      intent.cause,
    );
  }

  late final Action<UpdateSelectionIntent> _updateSelectionAction =
      CallbackAction<UpdateSelectionIntent>(onInvoke: _updateSelection);

  late final _UpdateTextSelectionToAdjacentLineAction<
          ExtendSelectionVerticallyToAdjacentLineIntent> _adjacentLineAction =
      _UpdateTextSelectionToAdjacentLineAction<
          ExtendSelectionVerticallyToAdjacentLineIntent>(this);

  _TextBoundary _documentBoundary(DirectionalTextEditingIntent intent) =>
      _DocumentBoundary(_value);

  Action<T> _makeOverridable<T extends Intent>(Action<T> defaultAction) {
    return Action<T>.overridable(
        context: context, defaultAction: defaultAction);
  }

  Action<T> _makeOverridableCallback<T extends Intent>(
    Object? Function(T intent) onInvoke,
  ) {
    return _makeOverridable(CallbackAction<T>(onInvoke: onInvoke));
  }

  Action<T>
      _makeSelectionUpdateAction<T extends DirectionalCaretMovementIntent>(
    bool ignoreNonCollapsedSelection,
    _TextBoundary Function(DirectionalTextEditingIntent intent) getTextBoundary,
  ) {
    return _makeOverridable(
      _UpdateTextSelectionAction<T>(
        this,
        ignoreNonCollapsedSelection,
        getTextBoundary,
      ),
    );
  }

  Action<T> _makeDeleteAction<T extends DirectionalTextEditingIntent>(
    _TextBoundary Function(DirectionalTextEditingIntent intent) getTextBoundary,
  ) {
    return _makeOverridable(_DeleteTextAction<T>(this, getTextBoundary));
  }

  /// Transpose the characters immediately before and after the current
  /// collapsed selection.
  ///
  /// When the cursor is at the end of the text, transposes the last two
  /// characters, if they exist.
  ///
  /// When the cursor is at the start of the text, does nothing.
  void _transposeCharacters(TransposeCharactersIntent intent) {
    if (_value.text.characters.length <= 1 ||
        !_value.selection.isCollapsed ||
        _value.selection.baseOffset == 0) {
      return;
    }

    final String text = _value.text;
    final TextSelection selection = _value.selection;
    final bool atEnd = selection.baseOffset == text.length;
    final CharacterRange transposing =
        CharacterRange.at(text, selection.baseOffset);
    if (atEnd) {
      transposing.moveBack(2);
    } else {
      transposing
        ..moveBack()
        ..expandNext();
    }
    assert(transposing.currentCharacters.length == 2);

    userUpdateTextEditingValue(
      TextEditingValue(
        text: transposing.stringBefore +
            transposing.currentCharacters.last +
            transposing.currentCharacters.first +
            transposing.stringAfter,
        selection: TextSelection.collapsed(
          offset: transposing.stringBeforeLength + transposing.current.length,
        ),
      ),
      SelectionChangedCause.keyboard,
    );
  }

  late final Action<TransposeCharactersIntent> _transposeCharactersAction =
      CallbackAction<TransposeCharactersIntent>(onInvoke: _transposeCharacters);

  void _replaceText(ReplaceTextIntent intent) {
    final TextEditingValue oldValue = _value;
    final TextEditingValue newValue = intent.currentTextEditingValue.replaced(
      intent.replacementRange,
      intent.replacementText,
    );
    userUpdateTextEditingValue(newValue, intent.cause);

    // If there's no change in text and selection (e.g. when selecting and
    // pasting identical text), the widget won't be rebuilt on value update.
    // Handle this by calling _didChangeTextEditingValue() so caret and scroll
    // updates can happen.
    if (newValue == oldValue) {
      _didChangeTextEditingValue();
    }
  }

  late final Action<ReplaceTextIntent> _replaceTextAction =
      CallbackAction<ReplaceTextIntent>(onInvoke: _replaceText);

  late final Action<DeleteCharacterIntent> _deleteCharacterAction =
      _makeDeleteAction<DeleteCharacterIntent>(_characterBoundary);
  late final Action<DeleteToNextWordBoundaryIntent>
      _deleteToNextWordBoundaryAction =
      _makeDeleteAction<DeleteToNextWordBoundaryIntent>(_nextWordBoundary);
  late final Action<DeleteToLineBreakIntent> _deleteToLineBreakAction =
      _makeDeleteAction<DeleteToLineBreakIntent>(_linebreak);

  late final Action<ExtendSelectionByCharacterIntent>
      _extendSelectionByCharacterAction =
      _makeSelectionUpdateAction<ExtendSelectionByCharacterIntent>(
    false,
    _characterBoundary,
  );
  late final Action<ExtendSelectionToNextWordBoundaryIntent>
      _extendSelectionToNextWordBoundaryAction =
      _makeSelectionUpdateAction<ExtendSelectionToNextWordBoundaryIntent>(
    true,
    _nextWordBoundary,
  );
  late final Action<ExtendSelectionToLineBreakIntent>
      _extendSelectionToLineBreakAction =
      _makeSelectionUpdateAction<ExtendSelectionToLineBreakIntent>(
    true,
    _linebreak,
  );
  late final Action<ExtendSelectionToDocumentBoundaryIntent>
      _extendSelectionToDocumentBoundaryAction =
      _makeSelectionUpdateAction<ExtendSelectionToDocumentBoundaryIntent>(
    true,
    _documentBoundary,
  );
  late final Action<ExtendSelectionToNextWordBoundaryOrCaretLocationIntent>
      _extendSelectionToNextWordBoundaryOrCaretLocationAction =
      _makeOverridable(_ExtendSelectionOrCaretPositionAction(
    this,
    _nextWordBoundary,
  ));

  late final Action<ExpandSelectionToLineBreakIntent>
      _expandSelectionToLineBreakAction =
      _makeOverridableCallback<ExpandSelectionToLineBreakIntent>(
    _expandSelectionToLinebreak,
  );
  late final Action<ExpandSelectionToDocumentBoundaryIntent>
      _expandSelectionToDocumentBoundaryAction =
      _makeOverridableCallback<ExpandSelectionToDocumentBoundaryIntent>(
    _expandSelectionToDocumentBoundary,
  );
  late final Action<ScrollToDocumentBoundaryIntent>
      _scrollToDocumentBoundaryAction =
      _makeOverridableCallback<ScrollToDocumentBoundaryIntent>(
    _scrollToDocumentBoundary,
  );

  // Scrolls either to the beginning or end of the document depending on the
  // intent's `forward` parameter.
  void _scrollToDocumentBoundary(ScrollToDocumentBoundaryIntent intent) {
    if (intent.forward) {
      bringIntoView(TextPosition(offset: _value.text.length));
    } else {
      bringIntoView(const TextPosition(offset: 0));
    }
  }

  /// Handles [ScrollIntent] by scrolling the [Scrollable] inside of
  /// [MongolEditableText].
  void _scroll(ScrollIntent intent) {
    if (intent.type != ScrollIncrementType.page) {
      return;
    }

    final ScrollPosition position = _scrollController.position;
    if (widget.maxLines == 1) {
      _scrollController.jumpTo(position.maxScrollExtent);
      return;
    }

    // If the field isn't scrollable, do nothing. For example, when the lines of
    // text is less than maxLines, the field has nothing to scroll.
    if (position.maxScrollExtent == 0.0 && position.minScrollExtent == 0.0) {
      return;
    }

    final ScrollableState? state =
        _scrollableKey.currentState as ScrollableState?;
    final double increment =
        ScrollAction.getDirectionalIncrement(state!, intent);
    final double destination = clampDouble(
      position.pixels + increment,
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (destination == position.pixels) {
      return;
    }
    _scrollController.jumpTo(destination);
  }

  /// Extend the selection down by page if the `forward` parameter is true, or
  /// up by page otherwise.
  void _extendSelectionByPage(ExtendSelectionByPageIntent intent) {
    if (widget.maxLines == 1) {
      return;
    }

    final TextSelection nextSelection;
    final Rect extentRect = renderEditable.getLocalRectForCaret(
      _value.selection.extent,
    );
    final ScrollableState? state =
        _scrollableKey.currentState as ScrollableState?;
    final double increment = ScrollAction.getDirectionalIncrement(
      state!,
      ScrollIntent(
        direction: intent.forward ? AxisDirection.right : AxisDirection.left,
        type: ScrollIncrementType.page,
      ),
    );
    final ScrollPosition position = _scrollController.position;
    if (intent.forward) {
      if (_value.selection.extentOffset >= _value.text.length) {
        return;
      }
      final Offset nextExtentOffset =
          Offset(extentRect.left + increment, extentRect.top);
      final double width = position.maxScrollExtent + renderEditable.size.width;
      final TextPosition nextExtent =
          nextExtentOffset.dx + position.pixels >= width
              ? TextPosition(offset: _value.text.length)
              : renderEditable.getPositionForPoint(
                  renderEditable.localToGlobal(nextExtentOffset),
                );
      nextSelection = _value.selection.copyWith(
        extentOffset: nextExtent.offset,
      );
    } else {
      if (_value.selection.extentOffset <= 0) {
        return;
      }
      final Offset nextExtentOffset =
          Offset(extentRect.left + increment, extentRect.top);
      final TextPosition nextExtent = nextExtentOffset.dx + position.pixels <= 0
          ? const TextPosition(offset: 0)
          : renderEditable.getPositionForPoint(
              renderEditable.localToGlobal(nextExtentOffset),
            );
      nextSelection = _value.selection.copyWith(
        extentOffset: nextExtent.offset,
      );
    }

    bringIntoView(nextSelection.extent);
    userUpdateTextEditingValue(
      _value.copyWith(selection: nextSelection),
      SelectionChangedCause.keyboard,
    );
  }

  void _expandSelectionToDocumentBoundary(
      ExpandSelectionToDocumentBoundaryIntent intent) {
    final _TextBoundary textBoundary = _documentBoundary(intent);
    _expandSelection(intent.forward, textBoundary, true);
  }

  void _expandSelectionToLinebreak(ExpandSelectionToLineBreakIntent intent) {
    final _TextBoundary textBoundary = _linebreak(intent);
    _expandSelection(intent.forward, textBoundary);
  }

  void _expandSelection(bool forward, _TextBoundary textBoundary,
      [bool extentAtIndex = false]) {
    final TextSelection textBoundarySelection =
        textBoundary.textEditingValue.selection;
    if (!textBoundarySelection.isValid) {
      return;
    }

    final bool inOrder =
        textBoundarySelection.baseOffset <= textBoundarySelection.extentOffset;
    final bool towardsExtent = forward == inOrder;
    final TextPosition position = towardsExtent
        ? textBoundarySelection.extent
        : textBoundarySelection.base;

    final TextPosition newExtent = forward
        ? textBoundary.getTrailingTextBoundaryAt(position)
        : textBoundary.getLeadingTextBoundaryAt(position);

    final TextSelection newSelection = textBoundarySelection.expandTo(
        newExtent, textBoundarySelection.isCollapsed || extentAtIndex);
    userUpdateTextEditingValue(
      _value.copyWith(selection: newSelection),
      SelectionChangedCause.keyboard,
    );
    bringIntoView(newSelection.extent);
  }

  Object? _hideToolbarIfVisible(DismissIntent intent) {
    if (_selectionOverlay?.toolbarIsVisible ?? false) {
      hideToolbar(false);
      return null;
    }
    return Actions.invoke(context, intent);
  }

  /// The default behavior used if [onTapOutside] is null.
  ///
  /// The `event` argument is the [PointerDownEvent] that caused the notification.
  void _defaultOnTapOutside(PointerDownEvent event) {
    /// The focus dropping behavior is only present on desktop platforms
    /// and mobile browsers.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        // On mobile platforms, we don't unfocus on touch events unless they're
        // in the web browser, but we do unfocus for all other kinds of events.
        switch (event.kind) {
          case ui.PointerDeviceKind.touch:
            if (kIsWeb) {
              widget.focusNode.unfocus();
            }
            break;
          case ui.PointerDeviceKind.mouse:
          case ui.PointerDeviceKind.stylus:
          case ui.PointerDeviceKind.invertedStylus:
          case ui.PointerDeviceKind.unknown:
            widget.focusNode.unfocus();
            break;
          case ui.PointerDeviceKind.trackpad:
            throw UnimplementedError(
                'Unexpected pointer down event for trackpad');
        }
        break;
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        widget.focusNode.unfocus();
        break;
    }
  }

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    DoNothingAndStopPropagationTextIntent: DoNothingAction(consumesKey: false),
    ReplaceTextIntent: _replaceTextAction,
    UpdateSelectionIntent: _updateSelectionAction,
    DirectionalFocusIntent: DirectionalFocusAction.forTextField(),
    DismissIntent:
        CallbackAction<DismissIntent>(onInvoke: _hideToolbarIfVisible),

    // Delete
    DeleteCharacterIntent: _deleteCharacterAction,
    DeleteToNextWordBoundaryIntent: _deleteToNextWordBoundaryAction,
    DeleteToLineBreakIntent: _deleteToLineBreakAction,

    // Extend/Move Selection
    ExtendSelectionByCharacterIntent: _extendSelectionByCharacterAction,
    ExtendSelectionByPageIntent: _makeOverridable(
        CallbackAction<ExtendSelectionByPageIntent>(
            onInvoke: _extendSelectionByPage)),
    MongolExtendSelectionByCharacterIntent: _extendSelectionByCharacterAction,
    ExtendSelectionToNextWordBoundaryIntent:
        _extendSelectionToNextWordBoundaryAction,
    MongolExtendSelectionToNextWordBoundaryIntent:
        _extendSelectionToNextWordBoundaryAction,
    ExtendSelectionToLineBreakIntent: _extendSelectionToLineBreakAction,
    MongolExtendSelectionToLineBreakIntent: _extendSelectionToLineBreakAction,
    ExpandSelectionToLineBreakIntent: _expandSelectionToLineBreakAction,
    MongolExpandSelectionToLineBreakIntent: _expandSelectionToLineBreakAction,
    ExpandSelectionToDocumentBoundaryIntent:
        _expandSelectionToDocumentBoundaryAction,
    ExtendSelectionVerticallyToAdjacentLineIntent:
        _makeOverridable(_adjacentLineAction),
    MongolExtendSelectionHorizontallyToAdjacentLineIntent:
        _makeOverridable(_adjacentLineAction),
    ExtendSelectionToDocumentBoundaryIntent:
        _extendSelectionToDocumentBoundaryAction,
    MongolExtendSelectionToDocumentBoundaryIntent:
        _extendSelectionToDocumentBoundaryAction,
    ExtendSelectionToNextWordBoundaryOrCaretLocationIntent:
        _extendSelectionToNextWordBoundaryOrCaretLocationAction,
    MongolExtendSelectionToNextWordBoundaryOrCaretLocationIntent:
        _extendSelectionToNextWordBoundaryOrCaretLocationAction,
    ScrollToDocumentBoundaryIntent: _scrollToDocumentBoundaryAction,
    ScrollIntent: CallbackAction<ScrollIntent>(onInvoke: _scroll),

    // Copy Paste
    SelectAllTextIntent: _makeOverridable(_SelectAllAction(this)),
    CopySelectionTextIntent: _makeOverridable(_CopySelectionAction(this)),
    PasteTextIntent: _makeOverridable(CallbackAction<PasteTextIntent>(
        onInvoke: (PasteTextIntent intent) => pasteText(intent.cause))),

    TransposeCharactersIntent: _makeOverridable(_transposeCharactersAction),
  };

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    super.build(context); // See AutomaticKeepAliveClientMixin.

    final TextSelectionControls? controls = widget.selectionControls;
    return TextFieldTapRegion(
      onTapOutside: widget.onTapOutside ?? _defaultOnTapOutside,
      debugLabel: kReleaseMode ? null : 'MongolEditableText',
      child: MouseRegion(
        cursor: widget.mouseCursor ?? mongolVerticalTextCursor,
        child: Actions(
          actions: _actions,
          child: _TextEditingHistory(
            controller: widget.controller,
            onTriggered: (TextEditingValue value) {
              userUpdateTextEditingValue(value, SelectionChangedCause.keyboard);
            },
            child: Focus(
              focusNode: widget.focusNode,
              includeSemantics: false,
              debugLabel: kReleaseMode ? null : 'MongolEditableText',
              child: Scrollable(
                key: _scrollableKey,
                excludeFromSemantics: true,
                axisDirection:
                    _isMultiline ? AxisDirection.right : AxisDirection.down,
                controller: _scrollController,
                physics: widget.scrollPhysics,
                dragStartBehavior: widget.dragStartBehavior,
                restorationId: widget.restorationId,
                scrollBehavior: widget.scrollBehavior ??
                    ScrollConfiguration.of(context).copyWith(
                      scrollbars: _isMultiline,
                      overscroll: false,
                    ),
                viewportBuilder: (BuildContext context, ViewportOffset offset) {
                  return CompositedTransformTarget(
                    link: _toolbarLayerLink,
                    child: Semantics(
                      onCopy: _semanticsOnCopy(controls),
                      onCut: _semanticsOnCut(controls),
                      onPaste: _semanticsOnPaste(controls),
                      textDirection: TextDirection.ltr,
                      child: _MongolEditable(
                        key: _editableKey,
                        startHandleLayerLink: _startHandleLayerLink,
                        endHandleLayerLink: _endHandleLayerLink,
                        textSpan: buildTextSpan(),
                        value: _value,
                        cursorColor: _cursorColor,
                        showCursor: MongolEditableText.debugDeterministicCursor
                            ? ValueNotifier<bool>(widget.showCursor)
                            : _cursorVisibilityNotifier,
                        forceLine: widget.forceLine,
                        readOnly: widget.readOnly,
                        hasFocus: _hasFocus,
                        maxLines: widget.maxLines,
                        minLines: widget.minLines,
                        expands: widget.expands,
                        selectionColor: widget.selectionColor,
                        textScaleFactor: widget.textScaleFactor ??
                            MediaQuery.textScalerOf(context).scale(1.0),
                        textAlign: widget.textAlign,
                        obscuringCharacter: widget.obscuringCharacter,
                        obscureText: widget.obscureText,
                        autocorrect: widget.autocorrect,
                        enableSuggestions: widget.enableSuggestions,
                        offset: offset,
                        rendererIgnoresPointer: widget.rendererIgnoresPointer,
                        cursorWidth: widget.cursorWidth,
                        cursorHeight: widget.cursorHeight,
                        cursorRadius: widget.cursorRadius,
                        cursorOffset: widget.cursorOffset ?? Offset.zero,
                        enableInteractiveSelection:
                            widget._userSelectionEnabled,
                        textSelectionDelegate: this,
                        devicePixelRatio: _devicePixelRatio,
                        clipBehavior: widget.clipBehavior,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds [TextSpan] from current editing value.
  ///
  /// By default makes text in composing range appear as underlined.
  /// Descendants can override this method to customize appearance of text.
  TextSpan buildTextSpan() {
    if (widget.obscureText) {
      var text = _value.text;
      text = widget.obscuringCharacter * text.length;
      // Reveal the latest character in an obscured field only on mobile.
      if (_isMobilePlatform) {
        final o =
            _obscureShowCharTicksPending > 0 ? _obscureLatestCharIndex : null;
        if (o != null && o >= 0 && o < text.length) {
          text = text.replaceRange(o, o + 1, _value.text.substring(o, o + 1));
        }
      }
      return TextSpan(style: widget.style, text: text);
    }
    // Read only mode should not paint text composing.
    return widget.controller.buildTextSpan(
      context: context,
      style: widget.style,
      withComposing: !widget.readOnly,
    );
  }
}

class _MongolEditable extends LeafRenderObjectWidget {
  const _MongolEditable({
    super.key,
    required this.textSpan,
    required this.value,
    required this.startHandleLayerLink,
    required this.endHandleLayerLink,
    this.cursorColor,
    required this.showCursor,
    required this.forceLine,
    required this.readOnly,
    required this.hasFocus,
    required this.maxLines,
    this.minLines,
    required this.expands,
    this.selectionColor,
    required this.textScaleFactor,
    required this.textAlign,
    required this.obscuringCharacter,
    required this.obscureText,
    required this.autocorrect,
    required this.enableSuggestions,
    required this.offset,
    this.rendererIgnoresPointer = false,
    this.cursorWidth,
    required this.cursorHeight,
    this.cursorRadius,
    required this.cursorOffset,
    this.enableInteractiveSelection = true,
    required this.textSelectionDelegate,
    required this.devicePixelRatio,
    required this.clipBehavior,
  });

  final TextSpan textSpan;
  final TextEditingValue value;
  final Color? cursorColor;
  final LayerLink startHandleLayerLink;
  final LayerLink endHandleLayerLink;
  final ValueNotifier<bool> showCursor;
  final bool forceLine;
  final bool readOnly;
  final bool hasFocus;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final Color? selectionColor;
  final double textScaleFactor;
  final MongolTextAlign textAlign;
  final String obscuringCharacter;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final ViewportOffset offset;
  final bool rendererIgnoresPointer;
  final double? cursorWidth;
  final double cursorHeight;
  final Radius? cursorRadius;
  final Offset cursorOffset;
  final bool enableInteractiveSelection;
  final TextSelectionDelegate textSelectionDelegate;
  final double devicePixelRatio;
  final Clip clipBehavior;

  @override
  MongolRenderEditable createRenderObject(BuildContext context) {
    return MongolRenderEditable(
      text: textSpan,
      cursorColor: cursorColor,
      startHandleLayerLink: startHandleLayerLink,
      endHandleLayerLink: endHandleLayerLink,
      showCursor: showCursor,
      forceLine: forceLine,
      readOnly: readOnly,
      hasFocus: hasFocus,
      maxLines: maxLines,
      minLines: minLines,
      expands: expands,
      selectionColor: selectionColor,
      textScaleFactor: textScaleFactor,
      textAlign: textAlign,
      selection: value.selection,
      offset: offset,
      ignorePointer: rendererIgnoresPointer,
      obscuringCharacter: obscuringCharacter,
      obscureText: obscureText,
      cursorWidth: cursorWidth,
      cursorHeight: cursorHeight,
      cursorRadius: cursorRadius,
      cursorOffset: cursorOffset,
      enableInteractiveSelection: enableInteractiveSelection,
      textSelectionDelegate: textSelectionDelegate,
      devicePixelRatio: devicePixelRatio,
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, MongolRenderEditable renderObject) {
    renderObject
      ..text = textSpan
      ..cursorColor = cursorColor
      ..startHandleLayerLink = startHandleLayerLink
      ..endHandleLayerLink = endHandleLayerLink
      ..showCursor = showCursor
      ..forceLine = forceLine
      ..readOnly = readOnly
      ..hasFocus = hasFocus
      ..maxLines = maxLines
      ..minLines = minLines
      ..expands = expands
      ..selectionColor = selectionColor
      ..textScaleFactor = textScaleFactor
      ..textAlign = textAlign
      ..selection = value.selection
      ..offset = offset
      ..ignorePointer = rendererIgnoresPointer
      ..obscuringCharacter = obscuringCharacter
      ..obscureText = obscureText
      ..cursorWidth = cursorWidth
      ..cursorHeight = cursorHeight
      ..cursorRadius = cursorRadius
      ..cursorOffset = cursorOffset
      ..enableInteractiveSelection = enableInteractiveSelection
      ..textSelectionDelegate = textSelectionDelegate
      ..devicePixelRatio = devicePixelRatio
      ..clipBehavior = clipBehavior;
  }
}

/// An interface for retrieving the logical text boundary (left-closed-right-open)
/// at a given location in a document.
///
/// Depending on the implementation of the [_TextBoundary], the input
/// [TextPosition] can either point to a code unit, or a position between 2 code
/// units (which can be visually represented by the caret if the selection were
/// to collapse to that position).
///
/// For example, [_LineBreak] interprets the input [TextPosition] as a caret
/// location, since in Flutter the caret is generally painted between the
/// character the [TextPosition] points to and its previous character, and
/// [_LineBreak] cares about the affinity of the input [TextPosition]. Most
/// other text boundaries however, interpret the input [TextPosition] as the
/// location of a code unit in the document, since it's easier to reason about
/// the text boundary given a code unit in the text.
///
/// To convert a "code-unit-based" [_TextBoundary] to "caret-location-based",
/// use the [_CollapsedSelectionBoundary] combinator.
abstract class _TextBoundary {
  const _TextBoundary();

  TextEditingValue get textEditingValue;

  /// Returns the leading text boundary at the given location, inclusive.
  TextPosition getLeadingTextBoundaryAt(TextPosition position);

  /// Returns the trailing text boundary at the given location, exclusive.
  TextPosition getTrailingTextBoundaryAt(TextPosition position);

  TextRange getTextBoundaryAt(TextPosition position) {
    return TextRange(
      start: getLeadingTextBoundaryAt(position).offset,
      end: getTrailingTextBoundaryAt(position).offset,
    );
  }
}

// -----------------------------  Text Boundaries -----------------------------

class _CodeUnitBoundary extends _TextBoundary {
  const _CodeUnitBoundary(this.textEditingValue);

  @override
  final TextEditingValue textEditingValue;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) =>
      TextPosition(offset: position.offset);
  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) => TextPosition(
      offset: math.min(position.offset + 1, textEditingValue.text.length));
}

// The word modifier generally removes the word boundaries around white spaces
// (and newlines), IOW white spaces and some other punctuations are considered
// a part of the next word in the search direction.
class _WhitespaceBoundary extends _TextBoundary {
  const _WhitespaceBoundary(this.textEditingValue);

  @override
  final TextEditingValue textEditingValue;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) {
    for (int index = position.offset; index >= 0; index -= 1) {
      if (!TextLayoutMetrics.isWhitespace(
          textEditingValue.text.codeUnitAt(index))) {
        return TextPosition(offset: index);
      }
    }
    return const TextPosition(offset: 0);
  }

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    for (int index = position.offset;
        index < textEditingValue.text.length;
        index += 1) {
      if (!TextLayoutMetrics.isWhitespace(
          textEditingValue.text.codeUnitAt(index))) {
        return TextPosition(offset: index + 1);
      }
    }
    return TextPosition(offset: textEditingValue.text.length);
  }
}

// Most apps delete the entire grapheme when the backspace key is pressed.
// Also always put the new caret location to character boundaries to avoid
// sending malformed UTF-16 code units to the paragraph builder.
class _CharacterBoundary extends _TextBoundary {
  const _CharacterBoundary(this.textEditingValue);

  @override
  final TextEditingValue textEditingValue;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) {
    final int endOffset =
        math.min(position.offset + 1, textEditingValue.text.length);
    return TextPosition(
      offset:
          CharacterRange.at(textEditingValue.text, position.offset, endOffset)
              .stringBeforeLength,
    );
  }

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    final int endOffset =
        math.min(position.offset + 1, textEditingValue.text.length);
    final CharacterRange range =
        CharacterRange.at(textEditingValue.text, position.offset, endOffset);
    return TextPosition(
      offset: textEditingValue.text.length - range.stringAfterLength,
    );
  }

  @override
  TextRange getTextBoundaryAt(TextPosition position) {
    final int endOffset =
        math.min(position.offset + 1, textEditingValue.text.length);
    final CharacterRange range =
        CharacterRange.at(textEditingValue.text, position.offset, endOffset);
    return TextRange(
      start: range.stringBeforeLength,
      end: textEditingValue.text.length - range.stringAfterLength,
    );
  }
}

// [UAX #29](https://unicode.org/reports/tr29/) defined word boundaries.
class _WordBoundary extends _TextBoundary {
  const _WordBoundary(this.textLayout, this.textEditingValue);

  final TextLayoutMetrics textLayout;

  @override
  final TextEditingValue textEditingValue;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) {
    return TextPosition(
      offset: textLayout.getWordBoundary(position).start,
      // Word boundary seems to always report downstream on many platforms.
      affinity:
          TextAffinity.downstream, // ignore: avoid_redundant_argument_values
    );
  }

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    return TextPosition(
      offset: textLayout.getWordBoundary(position).end,
      // Word boundary seems to always report downstream on many platforms.
      affinity:
          TextAffinity.downstream, // ignore: avoid_redundant_argument_values
    );
  }
}

// The linebreaks of the current text layout. The input [TextPosition]s are
// interpreted as caret locations because [TextPainter.getLineAtOffset] is
// text-affinity-aware.
class _LineBreak extends _TextBoundary {
  const _LineBreak(
    this.textLayout,
    this.textEditingValue,
  );

  final TextLayoutMetrics textLayout;

  @override
  final TextEditingValue textEditingValue;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) {
    return TextPosition(
      offset: textLayout.getLineAtOffset(position).start,
    );
  }

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    return TextPosition(
      offset: textLayout.getLineAtOffset(position).end,
      affinity: TextAffinity.upstream,
    );
  }
}

// The document boundary is unique and is a constant function of the input
// position.
class _DocumentBoundary extends _TextBoundary {
  const _DocumentBoundary(this.textEditingValue);

  @override
  final TextEditingValue textEditingValue;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) =>
      const TextPosition(offset: 0);
  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    return TextPosition(
      offset: textEditingValue.text.length,
      affinity: TextAffinity.upstream,
    );
  }
}

// ------------------------  Text Boundary Combinators ------------------------

// Expands the innerTextBoundary with outerTextBoundary.
class _ExpandedTextBoundary extends _TextBoundary {
  _ExpandedTextBoundary(this.innerTextBoundary, this.outerTextBoundary);

  final _TextBoundary innerTextBoundary;
  final _TextBoundary outerTextBoundary;

  @override
  TextEditingValue get textEditingValue {
    assert(innerTextBoundary.textEditingValue ==
        outerTextBoundary.textEditingValue);
    return innerTextBoundary.textEditingValue;
  }

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) {
    return outerTextBoundary.getLeadingTextBoundaryAt(
      innerTextBoundary.getLeadingTextBoundaryAt(position),
    );
  }

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    return outerTextBoundary.getTrailingTextBoundaryAt(
      innerTextBoundary.getTrailingTextBoundaryAt(position),
    );
  }
}

// Force the innerTextBoundary to interpret the input [TextPosition]s as caret
// locations instead of code unit positions.
//
// The innerTextBoundary must be a [_TextBoundary] that interprets the input
// [TextPosition]s as code unit positions.
class _CollapsedSelectionBoundary extends _TextBoundary {
  _CollapsedSelectionBoundary(this.innerTextBoundary, this.isForward);

  final _TextBoundary innerTextBoundary;
  final bool isForward;

  @override
  TextEditingValue get textEditingValue => innerTextBoundary.textEditingValue;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) {
    return isForward
        ? innerTextBoundary.getLeadingTextBoundaryAt(position)
        : position.offset <= 0
            ? const TextPosition(offset: 0)
            : innerTextBoundary.getLeadingTextBoundaryAt(
                TextPosition(offset: position.offset - 1));
  }

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    return isForward
        ? innerTextBoundary.getTrailingTextBoundaryAt(position)
        : position.offset <= 0
            ? const TextPosition(offset: 0)
            : innerTextBoundary.getTrailingTextBoundaryAt(
                TextPosition(offset: position.offset - 1));
  }
}

// A _TextBoundary that creates a [TextRange] where its start is from the
// specified leading text boundary and its end is from the specified trailing
// text boundary.
class _MixedBoundary extends _TextBoundary {
  _MixedBoundary(this.leadingTextBoundary, this.trailingTextBoundary);

  final _TextBoundary leadingTextBoundary;
  final _TextBoundary trailingTextBoundary;

  @override
  TextEditingValue get textEditingValue {
    assert(leadingTextBoundary.textEditingValue ==
        trailingTextBoundary.textEditingValue);
    return leadingTextBoundary.textEditingValue;
  }

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) =>
      leadingTextBoundary.getLeadingTextBoundaryAt(position);

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) =>
      trailingTextBoundary.getTrailingTextBoundaryAt(position);
}

// -------------------------------  Text Actions -------------------------------
class _DeleteTextAction<T extends DirectionalTextEditingIntent>
    extends ContextAction<T> {
  _DeleteTextAction(this.state, this.getTextBoundariesForIntent);

  final MongolEditableTextState state;
  final _TextBoundary Function(T intent) getTextBoundariesForIntent;

  TextRange _expandNonCollapsedRange(TextEditingValue value) {
    final TextRange selection = value.selection;
    assert(selection.isValid);
    assert(!selection.isCollapsed);
    final _TextBoundary atomicBoundary = state.widget.obscureText
        ? _CodeUnitBoundary(value)
        : _CharacterBoundary(value);

    return TextRange(
      start: atomicBoundary
          .getLeadingTextBoundaryAt(TextPosition(offset: selection.start))
          .offset,
      end: atomicBoundary
          .getTrailingTextBoundaryAt(TextPosition(offset: selection.end - 1))
          .offset,
    );
  }

  @override
  Object? invoke(T intent, [BuildContext? context]) {
    final TextSelection selection = state._value.selection;
    assert(selection.isValid);

    if (!selection.isCollapsed) {
      return Actions.invoke(
        context!,
        ReplaceTextIntent(
            state._value,
            '',
            _expandNonCollapsedRange(state._value),
            SelectionChangedCause.keyboard),
      );
    }

    final _TextBoundary textBoundary = getTextBoundariesForIntent(intent);
    if (!textBoundary.textEditingValue.selection.isValid) {
      return null;
    }
    if (!textBoundary.textEditingValue.selection.isCollapsed) {
      return Actions.invoke(
        context!,
        ReplaceTextIntent(
            state._value,
            '',
            _expandNonCollapsedRange(textBoundary.textEditingValue),
            SelectionChangedCause.keyboard),
      );
    }

    return Actions.invoke(
      context!,
      ReplaceTextIntent(
        textBoundary.textEditingValue,
        '',
        textBoundary
            .getTextBoundaryAt(textBoundary.textEditingValue.selection.base),
        SelectionChangedCause.keyboard,
      ),
    );
  }

  @override
  bool get isActionEnabled =>
      !state.widget.readOnly && state._value.selection.isValid;
}

class _UpdateTextSelectionAction<T extends DirectionalCaretMovementIntent>
    extends ContextAction<T> {
  _UpdateTextSelectionAction(
    this.state,
    this.ignoreNonCollapsedSelection,
    this.getTextBoundariesForIntent,
  );

  final MongolEditableTextState state;
  final bool ignoreNonCollapsedSelection;
  final _TextBoundary Function(T intent) getTextBoundariesForIntent;

  static const int newlineCodeUnit = 10;

  // Returns true iff the given position is at a wordwrap boundary in the
  // upstream position.
  bool _isAtWordwrapUpstream(TextPosition position) {
    final TextPosition end = TextPosition(
      offset: state.renderEditable.getLineAtOffset(position).end,
      affinity: TextAffinity.upstream,
    );
    return end == position &&
        end.offset != state.textEditingValue.text.length &&
        state.textEditingValue.text.codeUnitAt(position.offset) !=
            newlineCodeUnit;
  }

  // Returns true iff the given position at a wordwrap boundary in the
  // downstream position.
  bool _isAtWordwrapDownstream(TextPosition position) {
    final TextPosition start = TextPosition(
      offset: state.renderEditable.getLineAtOffset(position).start,
    );
    return start == position &&
        start.offset != 0 &&
        state.textEditingValue.text.codeUnitAt(position.offset - 1) !=
            newlineCodeUnit;
  }

  @override
  Object? invoke(T intent, [BuildContext? context]) {
    final TextSelection selection = state._value.selection;
    assert(selection.isValid);

    final bool collapseSelection =
        intent.collapseSelection || !state.widget.selectionEnabled;
    // Collapse to the logical start/end.
    TextSelection collapse(TextSelection selection) {
      assert(selection.isValid);
      assert(!selection.isCollapsed);
      return selection.copyWith(
        baseOffset: intent.forward ? selection.end : selection.start,
        extentOffset: intent.forward ? selection.end : selection.start,
      );
    }

    if (!selection.isCollapsed &&
        !ignoreNonCollapsedSelection &&
        collapseSelection) {
      return Actions.invoke(
        context!,
        UpdateSelectionIntent(
            state._value, collapse(selection), SelectionChangedCause.keyboard),
      );
    }

    final _TextBoundary textBoundary = getTextBoundariesForIntent(intent);
    final TextSelection textBoundarySelection =
        textBoundary.textEditingValue.selection;
    if (!textBoundarySelection.isValid) {
      return null;
    }
    if (!textBoundarySelection.isCollapsed &&
        !ignoreNonCollapsedSelection &&
        collapseSelection) {
      return Actions.invoke(
        context!,
        UpdateSelectionIntent(state._value, collapse(textBoundarySelection),
            SelectionChangedCause.keyboard),
      );
    }

    TextPosition extent = textBoundarySelection.extent;

    // If continuesAtWrap is true extent and is at the relevant wordwrap, then
    // move it just to the other side of the wordwrap.
    if (intent.continuesAtWrap) {
      if (intent.forward && _isAtWordwrapUpstream(extent)) {
        extent = TextPosition(
          offset: extent.offset,
        );
      } else if (!intent.forward && _isAtWordwrapDownstream(extent)) {
        extent = TextPosition(
          offset: extent.offset,
          affinity: TextAffinity.upstream,
        );
      }
    }

    final TextPosition newExtent = intent.forward
        ? textBoundary.getTrailingTextBoundaryAt(extent)
        : textBoundary.getLeadingTextBoundaryAt(extent);

    final TextSelection newSelection = collapseSelection
        ? TextSelection.fromPosition(newExtent)
        : textBoundarySelection.extendTo(newExtent);

    // If collapseAtReversal is true and would have an effect, collapse it.
    if (!selection.isCollapsed &&
        intent.collapseAtReversal &&
        (selection.baseOffset < selection.extentOffset !=
            newSelection.baseOffset < newSelection.extentOffset)) {
      return Actions.invoke(
        context!,
        UpdateSelectionIntent(
          state._value,
          TextSelection.fromPosition(selection.base),
          SelectionChangedCause.keyboard,
        ),
      );
    }

    return Actions.invoke(
      context!,
      UpdateSelectionIntent(textBoundary.textEditingValue, newSelection,
          SelectionChangedCause.keyboard),
    );
  }

  @override
  bool get isActionEnabled => state._value.selection.isValid;
}

class _ExtendSelectionOrCaretPositionAction extends ContextAction<
    ExtendSelectionToNextWordBoundaryOrCaretLocationIntent> {
  _ExtendSelectionOrCaretPositionAction(
      this.state, this.getTextBoundariesForIntent);

  final MongolEditableTextState state;
  final _TextBoundary Function(
          ExtendSelectionToNextWordBoundaryOrCaretLocationIntent intent)
      getTextBoundariesForIntent;

  @override
  Object? invoke(ExtendSelectionToNextWordBoundaryOrCaretLocationIntent intent,
      [BuildContext? context]) {
    final TextSelection selection = state._value.selection;
    assert(selection.isValid);

    final _TextBoundary textBoundary = getTextBoundariesForIntent(intent);
    final TextSelection textBoundarySelection =
        textBoundary.textEditingValue.selection;
    if (!textBoundarySelection.isValid) {
      return null;
    }

    final TextPosition extent = textBoundarySelection.extent;
    final TextPosition newExtent = intent.forward
        ? textBoundary.getTrailingTextBoundaryAt(extent)
        : textBoundary.getLeadingTextBoundaryAt(extent);

    final TextSelection newSelection =
        (newExtent.offset - textBoundarySelection.baseOffset) *
                    (textBoundarySelection.extentOffset -
                        textBoundarySelection.baseOffset) <
                0
            ? textBoundarySelection.copyWith(
                extentOffset: textBoundarySelection.baseOffset,
                affinity: textBoundarySelection.extentOffset >
                        textBoundarySelection.baseOffset
                    ? TextAffinity.downstream
                    : TextAffinity.upstream,
              )
            : textBoundarySelection.extendTo(newExtent);

    return Actions.invoke(
      context!,
      UpdateSelectionIntent(textBoundary.textEditingValue, newSelection,
          SelectionChangedCause.keyboard),
    );
  }

  @override
  bool get isActionEnabled =>
      state.widget.selectionEnabled && state._value.selection.isValid;
}

class _UpdateTextSelectionToAdjacentLineAction<
    T extends DirectionalCaretMovementIntent> extends ContextAction<T> {
  _UpdateTextSelectionToAdjacentLineAction(this.state);

  final MongolEditableTextState state;

  HorizontalCaretMovementRun? _horizontalMovementRun;
  TextSelection? _runSelection;

  void stopCurrentVerticalRunIfSelectionChanges() {
    final TextSelection? runSelection = _runSelection;
    if (runSelection == null) {
      assert(_horizontalMovementRun == null);
      return;
    }
    _runSelection = state._value.selection;
    final TextSelection currentSelection = state.widget.controller.selection;
    final bool continueCurrentRun = currentSelection.isValid &&
        currentSelection.isCollapsed &&
        currentSelection.baseOffset == runSelection.baseOffset &&
        currentSelection.extentOffset == runSelection.extentOffset;
    if (!continueCurrentRun) {
      _horizontalMovementRun = null;
      _runSelection = null;
    }
  }

  @override
  void invoke(T intent, [BuildContext? context]) {
    assert(state._value.selection.isValid);

    final bool collapseSelection =
        intent.collapseSelection || !state.widget.selectionEnabled;
    final TextEditingValue value = state._textEditingValueForTextLayoutMetrics;
    if (!value.selection.isValid) {
      return;
    }

    if (_horizontalMovementRun?.isValid == false) {
      _horizontalMovementRun = null;
      _runSelection = null;
    }

    final HorizontalCaretMovementRun currentRun = _horizontalMovementRun ??
        state.renderEditable.startHorizontalCaretMovement(
            state.renderEditable.selection!.extent);

    final bool shouldMove =
        intent.forward ? currentRun.moveNext() : currentRun.movePrevious();
    final TextPosition newExtent = shouldMove
        ? currentRun.current
        : (intent.forward
            ? TextPosition(offset: state._value.text.length)
            : const TextPosition(offset: 0));
    final TextSelection newSelection = collapseSelection
        ? TextSelection.fromPosition(newExtent)
        : value.selection.extendTo(newExtent);

    Actions.invoke(
      context!,
      UpdateSelectionIntent(
          value, newSelection, SelectionChangedCause.keyboard),
    );
    if (state._value.selection == newSelection) {
      _horizontalMovementRun = currentRun;
      _runSelection = newSelection;
    }
  }

  @override
  bool get isActionEnabled => state._value.selection.isValid;
}

class _SelectAllAction extends ContextAction<SelectAllTextIntent> {
  _SelectAllAction(this.state);

  final MongolEditableTextState state;

  @override
  Object? invoke(SelectAllTextIntent intent, [BuildContext? context]) {
    return Actions.invoke(
      context!,
      UpdateSelectionIntent(
        state._value,
        TextSelection(baseOffset: 0, extentOffset: state._value.text.length),
        intent.cause,
      ),
    );
  }

  @override
  bool get isActionEnabled => state.widget.selectionEnabled;
}

class _CopySelectionAction extends ContextAction<CopySelectionTextIntent> {
  _CopySelectionAction(this.state);

  final MongolEditableTextState state;

  @override
  void invoke(CopySelectionTextIntent intent, [BuildContext? context]) {
    if (intent.collapseSelection) {
      state.cutSelection(intent.cause);
    } else {
      state.copySelection(intent.cause);
    }
  }

  @override
  bool get isActionEnabled =>
      state._value.selection.isValid && !state._value.selection.isCollapsed;
}

/// A void function that takes a [TextEditingValue].
@visibleForTesting
typedef TextEditingValueCallback = void Function(TextEditingValue value);

/// Provides undo/redo capabilities for text editing.
///
/// Listens to [controller] as a [ValueNotifier] and saves relevant values for
/// undoing/redoing. The cadence at which values are saved is a best
/// approximation of the native behaviors of a hardware keyboard on Flutter's
/// desktop platforms, as there are subtle differences between each of these
/// platforms.
///
/// Listens to keyboard undo/redo shortcuts and calls [onTriggered] when a
/// shortcut is triggered that would affect the state of the [controller].
class _TextEditingHistory extends StatefulWidget {
  /// Creates an instance of [_TextEditingHistory].
  const _TextEditingHistory({
    required this.child,
    required this.controller,
    required this.onTriggered,
  });

  /// The child widget of [_TextEditingHistory].
  final Widget child;

  /// The [TextEditingController] to save the state of over time.
  final TextEditingController controller;

  /// Called when an undo or redo causes a state change.
  ///
  /// If the state would still be the same before and after the undo/redo, this
  /// will not be called. For example, receiving a redo when there is nothing
  /// to redo will not call this method.
  ///
  /// It is also not called when the controller is changed for reasons other
  /// than undo/redo.
  final TextEditingValueCallback onTriggered;

  @override
  State<_TextEditingHistory> createState() => _TextEditingHistoryState();
}

class _TextEditingHistoryState extends State<_TextEditingHistory> {
  final _UndoStack<TextEditingValue> _stack = _UndoStack<TextEditingValue>();
  late final _Throttled<TextEditingValue> _throttledPush;
  Timer? _throttleTimer;

  // This duration was chosen as a best fit for the behavior of Mac, Linux,
  // and Windows undo/redo state save durations, but it is not perfect for any
  // of them.
  static const Duration _kThrottleDuration = Duration(milliseconds: 500);

  void _undo(UndoTextIntent intent) {
    _update(_stack.undo());
  }

  void _redo(RedoTextIntent intent) {
    _update(_stack.redo());
  }

  void _update(TextEditingValue? nextValue) {
    if (nextValue == null) {
      return;
    }
    if (nextValue.text == widget.controller.text) {
      return;
    }
    widget.onTriggered(widget.controller.value.copyWith(
      text: nextValue.text,
      selection: nextValue.selection,
    ));
  }

  void _push() {
    if (widget.controller.value == TextEditingValue.empty) {
      return;
    }

    // Gboard on Android puts non-CJK words in composing regions. Keep Android
    // behavior unchanged and coalesce composing text there; other platforms
    // skip composing text in history coalescing.
    if (defaultTargetPlatform != TargetPlatform.android &&
        !widget.controller.value.composing.isCollapsed) {
      return;
    }

    _throttleTimer = _throttledPush(widget.controller.value);
  }

  @override
  void initState() {
    super.initState();
    _throttledPush = _throttle<TextEditingValue>(
      duration: _kThrottleDuration,
      function: _stack.push,
    );
    _push();
    widget.controller.addListener(_push);
  }

  @override
  void didUpdateWidget(_TextEditingHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _stack.clear();
      oldWidget.controller.removeListener(_push);
      widget.controller.addListener(_push);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_push);
    _throttleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        UndoTextIntent: Action<UndoTextIntent>.overridable(
            context: context,
            defaultAction: CallbackAction<UndoTextIntent>(onInvoke: _undo)),
        RedoTextIntent: Action<RedoTextIntent>.overridable(
            context: context,
            defaultAction: CallbackAction<RedoTextIntent>(onInvoke: _redo)),
      },
      child: widget.child,
    );
  }
}

/// A data structure representing a chronological list of states that can be
/// undone and redone.
class _UndoStack<T> {
  /// Creates an instance of [_UndoStack].
  _UndoStack();

  final List<T> _list = <T>[];

  // The index of the current value, or null if the list is empty.
  late int _index;

  /// Returns the current value of the stack.
  T? get currentValue => _list.isEmpty ? null : _list[_index];

  /// Add a new state change to the stack.
  ///
  /// Pushing identical objects will not create multiple entries.
  void push(T value) {
    if (_list.isEmpty) {
      _index = 0;
      _list.add(value);
      return;
    }

    assert(_index < _list.length && _index >= 0);

    if (value == currentValue) {
      return;
    }

    // If anything has been undone in this stack, remove those irrelevant states
    // before adding the new one.
    if (_index != _list.length - 1) {
      _list.removeRange(_index + 1, _list.length);
    }
    _list.add(value);
    _index = _list.length - 1;
  }

  /// Returns the current value after an undo operation.
  ///
  /// An undo operation moves the current value to the previously pushed value,
  /// if any.
  ///
  /// Iff the stack is completely empty, then returns null.
  T? undo() {
    if (_list.isEmpty) {
      return null;
    }

    assert(_index < _list.length && _index >= 0);

    if (_index != 0) {
      _index = _index - 1;
    }

    return currentValue;
  }

  /// Returns the current value after a redo operation.
  ///
  /// A redo operation moves the current value to the value that was last
  /// undone, if any.
  ///
  /// Iff the stack is completely empty, then returns null.
  T? redo() {
    if (_list.isEmpty) {
      return null;
    }

    assert(_index < _list.length && _index >= 0);

    if (_index < _list.length - 1) {
      _index = _index + 1;
    }

    return currentValue;
  }

  /// Remove everything from the stack.
  void clear() {
    _list.clear();
    _index = -1;
  }

  @override
  String toString() {
    return '_UndoStack $_list';
  }
}

/// A function that can be throttled with the throttle function.
typedef _Throttleable<T> = void Function(T currentArg);

/// A function that has been throttled by [_throttle].
typedef _Throttled<T> = Timer Function(T currentArg);

/// Returns a _Throttled that will call through to the given function only a
/// maximum of once per duration.
///
/// Only works for functions that take exactly one argument and return void.
_Throttled<T> _throttle<T>({
  required Duration duration,
  required _Throttleable<T> function,
  // If true, calls at the start of the timer.
  bool leadingEdge = false,
}) {
  Timer? timer;
  bool calledDuringTimer = false;
  late T arg;

  return (T currentArg) {
    arg = currentArg;
    if (timer != null) {
      calledDuringTimer = true;
      return timer!;
    }
    if (leadingEdge) {
      function(arg);
    }
    calledDuringTimer = false;
    timer = Timer(duration, () {
      if (!leadingEdge || calledDuringTimer) {
        function(arg);
      }
      timer = null;
    });
    return timer!;
  };
}

/// The start and end glyph widths (when in vertical orientation) of some
/// range of text.
@immutable
class _GlyphWidths {
  const _GlyphWidths({
    required this.start,
    required this.end,
  });

  /// The glyph width of the first line.
  final double start;

  /// The glyph width of the last line.
  final double end;
}
