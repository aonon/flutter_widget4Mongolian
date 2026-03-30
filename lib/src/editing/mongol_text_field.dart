// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package

import 'package:flutter/cupertino.dart' show CupertinoTheme;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide EditableTextState;
import 'package:flutter/material.dart'
    show
        InputCounterWidgetBuilder,
        Theme,
        Feedback,
        InputDecoration,
        MaterialLocalizations,
        ThemeData,
        debugCheckHasMaterial,
        debugCheckHasMaterialLocalizations,
        TextSelectionThemeData,
        iOSHorizontalOffset,
        MaterialStateProperty,
        MaterialState;
import 'package:mongol/src/base/mongol_text_align.dart';

import 'alignment.dart';
import 'mongol_editable_text.dart';
import 'mongol_input_decorator.dart';
import 'mongol_mouse_cursors.dart';
import 'platform_utils.dart';
import 'text_selection/mongol_text_selection.dart';
import 'text_selection/mongol_text_selection_controls.dart';

/// 文本选择手势检测器构建器，用于处理垂直蒙古文文本字段的手势操作
class _TextFieldSelectionGestureDetectorBuilder
    extends MongolTextSelectionGestureDetectorBuilder {
  /// 创建文本选择手势检测器构建器
  ///
  /// [state]：文本字段的状态对象
  _TextFieldSelectionGestureDetectorBuilder({
    required _TextFieldState state,
  })  : _state = state,
        super(delegate: state);

  /// 文本字段的状态对象
  final _TextFieldState _state;

  TargetPlatform get _platform => Theme.of(_state.context).platform;

  bool get _isApplePlatform {
    switch (_platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  void _showToolbarOnWebIfSelectionActive() {
    if ((!kIsWeb && !isDesktopPlatform(defaultTargetPlatform)) ||
        !delegate.selectionEnabled) {
      return;
    }

    final TextSelection selection = editableText.textEditingValue.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return;
    }

    editableText.hideToolbar(false);
    editableText.showToolbar();
  }

  /// 处理强制按压开始事件
  ///
  /// 当用户在支持3D Touch的设备上用力按压时触发
  @override
  void onForcePressStart(ForcePressDetails details) {
    super.onForcePressStart(details);
    if (delegate.selectionEnabled && shouldShowSelectionToolbar) {
      editableText.showToolbar();
    }
  }

  /// 处理强制按压结束事件
  ///
  /// 此方法为空实现，因为不需要特殊处理
  @override
  void onForcePressEnd(ForcePressDetails details) {
    // Not required.
  }

  /// 处理长按移动更新事件
  ///
  /// 根据不同平台的行为，选择不同的文本选择方式
  @override
  void onSingleLongTapMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }

    if (_isApplePlatform) {
      // 在 iOS/macOS 上，长按拖动直接更新到手势位置。
      renderEditable.selectPositionAt(
        from: details.globalPosition,
        cause: SelectionChangedCause.longPress,
      );
    } else {
      // 其他平台按原行为选择从起点到当前点的词范围。
      renderEditable.selectWordsInRange(
        from: details.globalPosition - details.offsetFromOrigin,
        to: details.globalPosition,
        cause: SelectionChangedCause.longPress,
      );
    }

    _showToolbarOnWebIfSelectionActive();
  }

  /// 处理单击抬起事件
  ///
  /// 触发键盘请求并调用用户定义的点击回调
  @override
  void onSingleTapUp(TapDragUpDetails details) {
    super.onSingleTapUp(details);
    _state._requestKeyboard();
    _state.widget.onTap?.call();
  }

  @override
  void onSingleLongTapEnd(LongPressEndDetails details) {
    super.onSingleLongTapEnd(details);
    _showToolbarOnWebIfSelectionActive();
  }

  @override
  void onDragSelectionEnd(TapDragEndDetails details) {
    super.onDragSelectionEnd(details);
    _showToolbarOnWebIfSelectionActive();
  }

  /// 处理鼠标右键点击事件。
  ///
  /// 在 Web 上，显式显示工具栏以避免与浏览器右键菜单时序冲突。
  @override
  void onSecondaryTap() {
    if (!delegate.selectionEnabled) {
      return;
    }

    if (kIsWeb || isDesktopPlatform(defaultTargetPlatform)) {
      if (!renderEditable.hasFocus) {
        renderEditable.selectPosition(cause: SelectionChangedCause.tap);
      }
      editableText.hideToolbar(false);
      editableText.showToolbar();
      return;
    }

    super.onSecondaryTap();
  }

  /// 处理长按开始事件
  ///
  /// 根据不同平台的行为，选择不同的文本选择方式
  @override
  void onSingleLongTapStart(LongPressStartDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }

    if (_isApplePlatform) {
      // 在 iOS/macOS 上，长按开始时直接定位光标。
      renderEditable.selectPositionAt(
        from: details.globalPosition,
        cause: SelectionChangedCause.longPress,
      );
    } else {
      // 其他平台沿用原行为：先选词并触发长按反馈。
      renderEditable.selectWord(cause: SelectionChangedCause.longPress);
      Feedback.forLongPress(_state.context);
    }

    _showToolbarOnWebIfSelectionActive();
  }
}

/// 用于垂直蒙古文的Material设计文本字段
///
/// 文本字段允许用户输入文本，可以使用硬件键盘或屏幕键盘
///
/// 当用户更改字段中的文本时，文本字段会调用[onChanged]回调。如果用户表示
/// 他们已完成在字段中输入（例如，通过按下软键盘上的按钮），文本字段会
/// 调用[onSubmitted]回调。
///
/// 要控制显示在文本字段中的文本，请使用[controller]。例如，要设置文本字段的初始值，
/// 使用已经包含一些文本的[controller]。[controller]还可以控制选择和组合区域
/// （并观察文本、选择和组合区域的变化）。
///
/// 默认情况下，文本字段有一个[decoration]，在文本字段的右侧绘制一个分隔线。
/// 您可以使用[decoration]属性来控制装饰，例如添加标签或图标。如果将[decoration]
/// 属性设置为null，装饰将被完全移除，包括装饰为节省标签空间而引入的额外填充。
///
/// 如果[decoration]不为null（默认情况），文本字段需要其祖先之一是[Material]部件。
///
/// 要将[MongolTextField]与其他[FormField]部件集成到[Form]中，请考虑使用[MongolTextFormField]。
///
/// 当不再需要[TextEditingController]时，请记得调用其[dispose]方法。这将确保
/// 我们释放该对象使用的任何资源。
///
/// {@tool snippet}
/// 此示例显示如何创建一个会隐藏输入的[MongolTextField]。
/// [InputDecoration]使用[OutlineInputBorder]在字段周围添加边框并添加标签。
///
/// ![](https://flutter.github.io/assets-for-api-docs/assets/material/text_field.png)
///
/// ```dart
/// MongolTextField(
///   obscureText: true,
///   decoration: InputDecoration(
///     border: OutlineInputBorder(),
///     labelText: 'Password',
///   ),
/// )
/// ```
/// {@end-tool}
///
/// ## 读取值
///
/// 从MongolTextField读取值的常用方法是使用[onSubmitted]回调。
/// 当用户完成编辑时，此回调会应用于文本字段的当前值。
///
/// 对于大多数应用程序，[onSubmitted]回调足以响应用户输入。
///
/// [onEditingComplete]回调也会在用户完成编辑时运行。
/// 它与[onSubmitted]不同，因为它有一个默认值，该值会更新文本控制器并释放键盘焦点。
/// 需要不同行为的应用程序可以覆盖默认的[onEditingComplete]回调。
///
/// 请记住，您始终可以使用[TextEditingController.text]从MongolTextField的
/// [TextEditingController]中读取当前字符串。
///
/// ## 处理表情符号和其他复杂字符
///
/// 在上面的实时Dartpad示例中，尝试输入表情符号👨‍👩‍👦并提交。
/// 因为示例代码使用`value.characters.length`测量长度，
/// 所以表情符号被正确计数为单个字符。
///
/// 另请参阅：
///
///  * [MongolTextFormField]，它与[Form]部件集成。
///  * [InputDecorator]，它显示围绕实际文本编辑部件的标签和其他视觉元素。
///  * [MongolEditableText]，它是[MongolTextField]核心的原始文本编辑控件。
///    除非您正在实现完全不同的设计语言（例如Cupertino），否则很少直接使用[MongolEditableText]部件。
class MongolTextField extends StatefulWidget {
  /// 创建用于垂直蒙古文的Material Design文本字段
  ///
  /// 如果[decoration]不为null（默认情况），文本字段需要其祖先之一是[Material]部件
  ///
  /// 要完全移除装饰（包括装饰为节省标签空间而引入的额外填充），请将[decoration]设置为null
  ///
  /// [maxLines]属性可以设置为null以移除对行数的限制。默认情况下，它为1，
  /// 意味着这是一个单行文本字段。[maxLines]不能为零
  ///
  /// [maxLength]属性默认设置为null，这意味着文本字段中允许的字符数不受限制。
  /// 如果设置了[maxLength]，将在字段右侧显示一个字符计数器，显示已输入的字符数。
  /// 如果该值设置为正整数，它还将显示允许输入的最大字符数。
  /// 如果该值设置为[TextField.noMaxLength]，则仅显示当前长度
  ///
  /// 输入[maxLength]个字符后，除非[maxLengthEnforcement]设置为
  /// [MaxLengthEnforcement.none]，否则忽略额外的输入
  /// 文本字段使用[LengthLimitingTextInputFormatter]强制执行长度限制，
  /// 该格式化程序在提供的[inputFormatters]（如果有）之后评估
  /// [maxLength]值必须为null或大于零
  ///
  /// 如果[showCursor]为false，或者[showCursor]为null（默认值）且[readOnly]为true，
  /// 则不显示文本光标
  ///
  /// [textAlign]、[autofocus]、[obscureText]、[readOnly]、[autocorrect]、
  /// [scrollPadding]、[maxLines]、[maxLength]和[enableSuggestions]参数不能为空
  ///
  /// 另请参阅：
  ///
  ///  * [maxLength]，它讨论了"字符数"的精确含义以及它可能与直观含义的不同之处
  const MongolTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    TextInputType? keyboardType,
    this.textInputAction,
    this.style,
    this.textAlign = MongolTextAlign.top,
    this.textAlignHorizontal,
    this.readOnly = false,
    ToolbarOptions? toolbarOptions,
    this.showCursor,
    this.autofocus = false,
    this.onTapOutside,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onAppPrivateCommand,
    this.inputFormatters,
    this.enabled,
    this.cursorHeight = 2.0,
    this.cursorWidth,
    this.cursorRadius,
    this.cursorColor,
    this.keyboardAppearance,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableInteractiveSelection = true,
    this.enableWebReadOnlyInputConnection = true,
    this.selectionControls,
    this.onTap,
    this.mouseCursor,
    this.buildCounter,
    this.scrollController,
    this.scrollPhysics,
    this.autofillHints,
    this.restorationId,
    this.contentInsertionConfiguration,
    this.contextMenuBuilder,
  })  : assert(obscuringCharacter.length == 1),
        assert(maxLines == null || maxLines > 0),
        assert(minLines == null || minLines > 0),
        assert(
          (maxLines == null) || (minLines == null) || (maxLines >= minLines),
          "minLines can't be greater than maxLines",
        ),
        assert(
          !expands || (maxLines == null && minLines == null),
          'minLines and maxLines must be null when expands is true.',
        ),
        assert(!obscureText || maxLines == 1,
            'Obscured fields cannot be multiline.'),
        assert(maxLength == null ||
            maxLength == MongolTextField.noMaxLength ||
            maxLength > 0),
        // Assert the following instead of setting it directly to avoid surprising the user by silently changing the value they set.
        assert(
            !identical(textInputAction, TextInputAction.newline) ||
                maxLines == 1 ||
                !identical(keyboardType, TextInputType.text),
            'Use keyboardType TextInputType.multiline when using TextInputAction.newline on a multiline TextField.'),
        keyboardType = keyboardType ??
            (maxLines == 1 ? TextInputType.text : TextInputType.multiline),
        toolbarOptions = toolbarOptions ??
            (obscureText
                ? const ToolbarOptions(
                    selectAll: true,
                    paste: true,
                  )
                : const ToolbarOptions(
                    copy: true,
                    cut: true,
                    selectAll: true,
                    paste: true,
                  ));

  /// 控制正在编辑的文本
  ///
  /// 如果为null，此部件将创建自己的[TextEditingController]
  final TextEditingController? controller;

  /// 定义此部件的键盘焦点
  ///
  /// [focusNode]是一个长期存在的对象，通常由[StatefulWidget]父部件管理。
  /// 有关更多信息，请参阅[FocusNode]
  ///
  /// 要为此部件提供键盘焦点，请提供一个[focusNode]，然后使用当前的[FocusScope]来请求焦点：
  ///
  /// ```dart
  /// FocusScope.of(context).requestFocus(myFocusNode);
  /// ```
  ///
  /// 当部件被点击时，这会自动发生
  ///
  /// 要在部件获得或失去焦点时收到通知，请向[focusNode]添加一个监听器：
  ///
  /// ```dart
  /// focusNode.addListener(() { print(myFocusNode.hasFocus); });
  /// ```
  ///
  /// 如果为null，此部件将创建自己的[FocusNode]
  ///
  /// ## 键盘
  ///
  /// 请求焦点通常会导致键盘显示（如果尚未显示）
  ///
  /// 在Android上，用户可以使用系统返回按钮隐藏键盘而不更改焦点。
  /// 他们可以通过点击文本字段来恢复键盘的可见性。用户可能会隐藏键盘并
  /// 切换到物理键盘，或者他们可能只是需要暂时让它不挡住视线，以暴露它
  /// 遮挡的内容。在这种情况下，再次请求焦点不会导致焦点改变，也不会使键盘可见
  ///
  /// 此部件构建一个[MongolEditableText]，并通过调用[MongolEditableTextState.requestKeyboard()]
  /// 确保在点击时显示键盘
  final FocusNode? focusNode;

  /// 显示在文本字段周围的装饰
  ///
  /// 默认情况下，在文本字段右侧绘制一条垂直线，但可以配置为显示图标、标签、提示文本和错误文本
  ///
  /// 指定null以完全移除装饰（包括装饰为节省标签空间而引入的额外填充）
  final InputDecoration? decoration;

  /// 用于编辑文本的键盘类型
  ///
  /// 如果[maxLines]为1，则默认为[TextInputType.text]，否则默认为[TextInputType.multiline]
  final TextInputType keyboardType;

  /// 键盘使用的操作按钮类型
  ///
  /// 如果[keyboardType]是[TextInputType.multiline]，则默认为[TextInputAction.newline]，
  /// 否则默认为[TextInputAction.done]
  final TextInputAction? textInputAction;

  /// 用于正在编辑的文本的样式
  ///
  /// 此文本样式也用作[decoration]的基础样式
  ///
  /// 如果为null，默认为当前[Theme]中的`subtitle1`文本样式
  final TextStyle? style;

  /// 文本应如何垂直对齐
  ///
  /// 默认为[MongolTextAlign.top]
  final MongolTextAlign textAlign;

  /// 垂直蒙古文在输入框内的水平对齐方式
  final TextAlignHorizontal? textAlignHorizontal;

  /// 如果没有其他部件已经获得焦点，此文本字段是否应该自动获得焦点
  ///
  /// 如果为true，当此文本字段获得焦点时，键盘将立即打开。
  /// 否则，只有在用户点击文本字段后才会显示键盘
  ///
  /// 默认为false
  final bool autofocus;

  /// 当用户点击文本字段外部时调用的回调
  final TapRegionCallback? onTapOutside;

  /// 如果[obscureText]为true，则用于隐藏文本的字符
  ///
  /// 必须只有一个字符
  ///
  /// 默认为字符U+2022 BULLET (•)
  final String obscuringCharacter;

  /// 是否隐藏正在编辑的文本（例如，用于密码）
  ///
  /// 当设置为true时，文本字段中的所有字符都将被[obscuringCharacter]替换
  ///
  /// 默认为false
  final bool obscureText;

  /// 是否启用自动更正
  ///
  /// 默认为true
  final bool autocorrect;

  /// 是否在用户输入时显示输入建议
  ///
  /// 此标志仅影响Android。在iOS上，建议直接与[autocorrect]相关联，
  /// 因此只有当[autocorrect]为true时才会显示建议。在Android上，自动更正和建议是分开控制的
  ///
  /// 默认为true
  ///
  /// 另请参阅：
  ///
  ///  * <https://developer.android.com/reference/android/text/InputType.html#TYPE_TEXT_FLAG_NO_SUGGESTIONS>
  final bool enableSuggestions;

  /// 文本要跨越的最大行数，必要时换行
  ///
  /// 如果为1（默认值），文本将不会换行，而是会垂直滚动
  ///
  /// 如果为null，则行数没有限制，文本容器将从一行的足够水平空间开始，
  /// 并随着输入的增加自动增长以容纳更多行
  ///
  /// 如果不为null，该值必须大于零，它将锁定输入到给定的行数，并占用足够的垂直空间
  /// 以容纳该数量的行。同时设置[minLines]允许输入在指定的范围内增长
  ///
  /// [minLines]和[maxLines]可能的完整行为集如下。这些示例同样适用于`MongolTextField`、
  /// `MongolTextFormField`和`MongolEditableText`
  ///
  /// 占用单行并根据需要垂直滚动的输入：
  /// ```dart
  /// MongolTextField()
  /// ```
  ///
  /// 宽度从一行增长到输入文本所需的任意多行的输入。如果其父部件施加宽度限制，
  /// 当宽度达到该限制时，它将水平滚动：
  /// ```dart
  /// MongolTextField(maxLines: null)
  /// ```
  ///
  /// 输入的宽度足够容纳给定的行数。如果输入额外的行，输入将水平滚动：
  /// ```dart
  /// MongolTextField(maxLines: 2)
  /// ```
  ///
  /// 宽度在最小和最大之间随内容增长的输入。使用`maxLines: null`可以实现无限最大值：
  /// ```dart
  /// MongolTextField(minLines: 2, maxLines: 4)
  /// ```
  final int? maxLines;

  /// 当内容跨越少行时要占用的最小行数
  ///
  /// 如果为null（默认值），文本容器开始时具有一行的足够水平空间，
  /// 并随着输入的增加自动增长以容纳更多行
  ///
  /// 这可以与[maxLines]结合使用，以实现各种行为
  ///
  /// 如果设置了该值，它必须大于零。如果该值大于1，[maxLines]也应设置为null或大于此值
  ///
  /// 当同时设置[maxLines]时，宽度将在指定的行数范围内增长。
  /// 当[maxLines]为null时，它将从[minLines]开始，根据需要增长到任意宽度
  ///
  /// [minLines]和[maxLines]可能的行为示例如下。
  /// 这些同样适用于`MongolTextField`、`MongolTextFormField`和`MongolEditableText`
  ///
  /// 始终至少占用2行且最大行数无限的输入。根据需要水平扩展：
  /// ```dart
  /// MongolTextField(minLines: 2)
  /// ```
  ///
  /// 宽度从2行开始增长到4行，此时达到宽度限制。如果输入额外的行，它将水平滚动：
  /// ```dart
  /// MongolTextField(minLines:2, maxLines: 4)
  /// ```
  ///
  /// 有关[maxLines]和[minLines]如何交互以产生各种行为的完整情况，请参阅[maxLines]中的示例
  ///
  /// 默认为null
  final int? minLines;

  /// 此部件的宽度是否将调整为填充其父部件
  ///
  /// 如果设置为true并包装在[Expanded]或[SizedBox]等父部件中，输入将扩展以填充父部件
  ///
  /// 当设置为true时，[maxLines]和[minLines]都必须为null，否则会抛出错误
  ///
  /// 默认为false
  ///
  /// 有关[maxLines]、[minLines]和[expands]如何交互以产生各种行为的完整情况，
  /// 请参阅[maxLines]中的示例
  ///
  /// 与父部件宽度匹配的输入：
  /// ```dart
  /// Expanded(
  ///   child: MongolTextField(maxLines: null, expands: true),
  /// )
  /// ```
  final bool expands;

  /// 文本是否可以更改
  ///
  /// 当设置为true时，文本不能通过任何快捷方式或键盘操作修改。文本仍然可以选择
  ///
  /// 默认为false
  final bool readOnly;

  /// 工具栏选项的配置
  ///
  /// 如果未设置，默认启用全选和粘贴。如果[obscureText]为true，则禁用复制和剪切。
  /// 如果[readOnly]为true，则无论如何都禁用粘贴和剪切
  final ToolbarOptions toolbarOptions;

  /// 是否显示光标
  ///
  /// 光标是指[MongolEditableText]获得焦点时的闪烁插入符
  ///
  /// 另请参阅：
  ///
  ///  * [showSelectionHandles]，它控制选择手柄的可见性
  final bool? showCursor;

  /// 如果[maxLength]设置为此值，则仅显示字符计数器的"当前输入长度"部分
  static const int noMaxLength = -1;

  /// 文本字段中允许的最大字符数（Unicode标量值）
  ///
  /// 如果设置，将在字段右侧显示一个字符计数器，显示已输入的字符数。
  /// 如果设置为大于0的数字，它还将显示允许的最大字符数。
  /// 如果设置为[MongolTextField.noMaxLength]，则仅显示当前字符计数
  ///
  /// 输入[maxLength]个字符后，除非[maxLengthEnforcement]设置为
  /// [MaxLengthEnforcement.none]，否则忽略额外的输入
  ///
  /// 文本字段使用[LengthLimitingTextInputFormatter]强制执行长度限制，
  /// 该格式化程序在提供的[inputFormatters]（如果有）之后评估
  ///
  /// 该值必须为null、[MongolTextField.noMaxLength]或大于0。
  /// 如果为null（默认值），则对可以输入的字符数没有限制。
  /// 如果设置为[MongolTextField.noMaxLength]，则不会强制执行限制，但仍会显示已输入的字符数
  ///
  /// 空白字符（例如换行符、空格、制表符）包含在字符计数中
  ///
  /// 如果[maxLengthEnforcement]是[MaxLengthEnforcement.none]，则可以输入超过[maxLength]
  /// 的字符，但当超过限制时，错误计数器和分隔线将切换到[decoration]的[InputDecoration.errorStyle]
  ///
  /// ## 字符
  ///
  /// 有关什么被视为字符的具体定义，请参阅Pub上的[characters](https://pub.dev/packages/characters)包，
  /// 这是Flutter用于划分字符的包。通常，即使是复杂的字符如代理对和扩展字形集群，
  /// Flutter也会正确地将它们解释为每个都是单个用户感知的字符
  ///
  /// 例如，字符"ö"可以表示为'\u{006F}\u{0308}'，即字母"o"后跟组合变音符号"¨"，
  /// 或者可以表示为'\u{00F6}'，即Unicode标量值"LATIN SMALL LETTER O WITH DIAERESIS"。
  /// 在这两种情况下，它都将被计数为单个字符
  ///
  /// 同样，一些表情符号由多个标量值表示。Unicode"THUMBS UP SIGN + MEDIUM SKIN TONE MODIFIER"，
  /// "👍🏽"被计数为单个字符，即使它是两个Unicode标量值'\u{1F44D}\u{1F3FD}'的组合
  final int? maxLength;

  /// 确定应如何强制执行[maxLength]限制
  final MaxLengthEnforcement? maxLengthEnforcement;

  /// 当用户启动对MongolTextField值的更改时调用：当他们插入或删除文本时
  ///
  /// 当通过MongolTextField的[controller]以编程方式更改MongolTextField的文本时，
  /// 此回调不会运行。通常不需要通知此类更改，因为它们是由应用程序本身启动的
  ///
  /// 要收到MongolTextField的文本、光标和选择的所有更改的通知，
  /// 可以使用[TextEditingController.addListener]向其[controller]添加监听器
  ///
  /// ## 处理表情符号和其他复杂字符
  ///
  /// 当处理可能包含复杂字符的用户输入文本时，始终使用[characters](https://pub.dev/packages/characters)包非常重要。
  /// 这将确保扩展字形集群和代理对被视为单个字符，就像它们在用户看来一样
  ///
  /// 例如，当查找某些用户输入的长度时，使用`string.characters.length`。
  /// 不要使用`string.length`甚至`string.runes.length`。对于复杂字符"👨‍👩‍👦"，
  /// 它在用户看来是单个字符，`string.characters.length`直观地返回1。
  /// 另一方面，`string.length`返回8，`string.runes.length`返回5！
  ///
  /// 另请参阅：
  ///
  ///  * [inputFormatters]，它们在[onChanged]运行之前被调用，可以验证和更改（"格式化"）输入值
  ///  * [onEditingComplete]、[onSubmitted]：更专门的输入更改通知
  final ValueChanged<String>? onChanged;

  /// 当用户提交可编辑内容时调用（例如，用户按下键盘上的"完成"按钮）
  ///
  /// [onEditingComplete]的默认实现根据情况执行两种不同的行为：
  ///
  ///  - 当按下完成操作（如"完成"、"前往"、"发送"或"搜索"）时，用户的内容被提交到[controller]，然后放弃焦点
  ///
  ///  - 当按下非完成操作（如"下一个"或"上一个"）时，用户的内容被提交到[controller]，
  ///    但不放弃焦点，因为开发人员可能希望在[onSubmitted]中立即将焦点移动到另一个输入部件
  ///
  /// 提供[onEditingComplete]会阻止上述默认行为
  final VoidCallback? onEditingComplete;

  /// 当用户表示他们已完成编辑字段中的文本时调用
  ///
  /// 另请参阅：
  ///
  ///  * [TextInputAction.next]和[TextInputAction.previous]，它们在用户完成编辑时
  ///    自动将焦点转移到下一个/上一个可聚焦项目
  final ValueChanged<String>? onSubmitted;

  /// 用于接收来自输入方法的私有命令
  ///
  /// 当收到[TextInputClient.performPrivateCommand]的结果时调用
  ///
  /// 这可用于提供仅在某些输入方法及其客户端之间已知的特定于域的功能
  ///
  /// 另请参阅：
  ///   * [https://developer.android.com/reference/android/view/inputmethod/InputConnection#performPrivateCommand(java.lang.String,%20android.os.Bundle)]，
  ///     这是Android的performPrivateCommand文档，用于从输入方法发送命令
  ///   * [https://developer.android.com/reference/android/view/inputmethod/InputMethodManager#sendAppPrivateCommand]，
  ///     这是Android的sendAppPrivateCommand文档，用于向输入方法发送命令
  final AppPrivateCommandCallback? onAppPrivateCommand;

  /// 可选的输入验证和格式化覆盖
  ///
  /// 当文本输入更改时，格式化程序按提供的顺序运行。当此参数更改时，
  /// 新的格式化程序将不会应用，直到用户下次插入或删除文本
  final List<TextInputFormatter>? inputFormatters;

  /// 如果为false，文本字段被"禁用"：它忽略点击，其[decoration]以灰色渲染
  ///
  /// 如果非null，此属性会覆盖[decoration]的[InputDecoration.enabled]属性
  final bool? enabled;

  /// 光标的宽度
  ///
  /// 如果此属性为null，将使用[MongolRenderEditable.preferredLineWidth]
  final double? cursorWidth;

  /// 光标的厚度
  ///
  /// 默认为2.0
  ///
  /// 光标将在文本上方绘制。光标高度将从字符之间的边界向下延伸。
  /// 这对应于相对于所选位置向下游延伸。可以使用负值来反转此行为
  final double cursorHeight;

  /// 光标的角应该有多圆
  ///
  /// 默认情况下，光标没有圆角
  final Radius? cursorRadius;

  /// 光标的颜色
  ///
  /// 光标指示字段中文本插入点的当前位置
  ///
  /// 如果为null，它将默认为环境[TextSelectionThemeData.cursorColor]。
  /// 如果该值为null，且[ThemeData.platform]是[TargetPlatform.iOS]或[TargetPlatform.macOS]，
  /// 它将使用[CupertinoThemeData.primaryColor]。否则，它将使用[ThemeData.colorScheme]的[ColorScheme.primary]值
  final Color? cursorColor;

  /// 键盘的外观
  ///
  /// 此设置仅在iOS设备上有效
  ///
  /// 如果未设置，默认为[ThemeData.brightness]
  final Brightness? keyboardAppearance;

  /// 配置当MongolTextField滚动到视图中时围绕[Scrollable]的边缘的填充
  ///
  /// 当此部件获得焦点且未完全可见时（例如，部分滚动出屏幕或被键盘覆盖），
  /// 它将尝试通过滚动周围的[Scrollable]（如果存在）来使自己可见。
  /// 此值控制滚动后MongolTextField将定位在[Scrollable]边缘多远的位置
  ///
  /// 默认为EdgeInsets.all(20.0)
  final EdgeInsets scrollPadding;

  /// 是否启用以更改文本选择的用户界面功能
  ///
  /// 例如，将此设置为true将启用长按MongolTextField以选择文本并显示
  /// 剪切/复制/粘贴菜单，以及点击移动文本插入符等功能
  ///
  /// 当此为false时，用户无法调整文本选择，无法复制文本，
  /// 且用户无法从剪贴板粘贴到文本字段
  final bool enableInteractiveSelection;

  /// 是否允许只读字段在 Web 上建立输入连接。
  ///
  /// 默认为 true，以保留浏览器原生的复制、全选和键盘选区行为。
  /// 将其设为 false 可避免只读字段在 Web 上创建输入连接。
  final bool enableWebReadOnlyInputConnection;

  /// 用于构建文本选择手柄和工具栏的可选委托
  ///
  /// 单独使用的[MongolEditableText]部件不会自行触发选择工具栏的显示。
  /// 工具栏是通过响应适当的用户事件调用[EditableTextState.showToolbar]来显示的
  ///
  /// 另请参阅：
  ///
  ///  * [MongolTextField]，[MongolEditableText]的Material Design主题包装器，
  ///    它根据用户平台设置在[ThemeData.platform]中，在适当的用户事件时显示选择工具栏
  ///
  final TextSelectionControls? selectionControls;

  /// 上下文菜单构建器，用于自定义长按/右键时显示的选择菜单。
  ///
  /// 若为 null，则使用平台默认的 [toolbarOptions] 工具栏。
  final MongolEditableTextContextMenuBuilder? contextMenuBuilder;

  /// 确定如何处理拖动开始行为
  ///
  /// 如果设置为[DragStartBehavior.start]，滚动拖动行为将在检测到拖动手势时开始。
  /// 如果设置为[DragStartBehavior.down]，它将在首次检测到按下事件时开始
  ///
  /// 一般来说，将此设置为[DragStartBehavior.start]将使拖动动画更平滑，
  /// 而将其设置为[DragStartBehavior.down]将使拖动行为感觉稍微更具响应性
  ///
  /// 默认情况下，拖动开始行为是[DragStartBehavior.start]
  ///
  /// 另请参阅：
  ///
  ///  * [DragGestureRecognizer.dragStartBehavior]，它给出了不同行为的示例
  final DragStartBehavior dragStartBehavior;

  /// 与[enableInteractiveSelection]相同
  ///
  /// 此 getter 主要是为了与[MongolRenderEditable.selectionEnabled]保持一致
  bool get selectionEnabled => enableInteractiveSelection;

  /// 为每次不同的点击调用，除了双击的第二次点击
  ///
  /// 文本字段构建一个[GestureDetector]来处理输入事件，如点击、触发焦点请求、
  /// 移动插入符、调整选择等。通过用竞争的GestureDetector包装文本字段来处理其中一些事件是有问题的
  ///
  /// 要无条件处理点击，而不干扰文本字段的内部手势检测器，请提供此回调
  ///
  /// 如果文本字段使用[enabled] false创建，则不会识别点击
  ///
  /// 要在文本字段获得或失去焦点时收到通知，请提供一个[focusNode]并向其添加监听器
  ///
  /// 要在不与文本字段的内部手势检测器竞争的情况下监听任意指针事件，请使用[Listener]
  final GestureTapCallback? onTap;

  /// 鼠标指针进入或悬停在部件上时的光标
  ///
  /// 如果[mouseCursor]是[MaterialStateProperty<MouseCursor>]，
  /// [MaterialStateProperty.resolve]将用于以下[MaterialState]：
  ///
  ///  * [MaterialState.error]
  ///  * [MaterialState.hovered]
  ///  * [MaterialState.focused]
  ///  * [MaterialState.disabled]
  ///
  /// 如果此属性为null，将使用适合竖排文本的水平I形光标
  ///
  /// [mouseCursor]是[MongolTextField]中唯一控制鼠标指针外观的属性。
  /// 所有其他与"cursor"相关的属性都代表文本光标，通常是编辑位置的闪烁水平线
  final MouseCursor? mouseCursor;

  /// 生成自定义[InputDecoration.counter]部件的回调
  ///
  /// 有关传入参数的解释，请参阅[InputCounterWidgetBuilder]。
  /// 返回的部件将放置在行下方，替代指定[InputDecoration.counterText]时构建的默认部件
  ///
  /// 返回的部件将包装在[Semantics]部件中以实现可访问性，
  /// 但它本身也需要是可访问的。例如，如果返回MongolText部件，
  /// 请设置[MongolText.semanticsLabel]属性
  ///
  /// {@tool snippet}
  /// ```dart
  /// Widget counter(
  ///   BuildContext context,
  ///   {
  ///     required int currentLength,
  ///     required int? maxLength,
  ///     required bool isFocused,
  ///   }
  /// ) {
  ///   return MongolText(
  ///     '$currentLength of $maxLength characters',
  ///     semanticsLabel: 'character count',
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// 如果buildCounter返回null，则不会创建计数器和Semantics部件
  final InputCounterWidgetBuilder? buildCounter;

  /// 水平滚动输入时使用的[ScrollPhysics]
  ///
  /// 如果未指定，它将根据当前平台表现
  ///
  /// 请参阅[Scrollable.physics]
  final ScrollPhysics? scrollPhysics;

  /// 水平滚动输入时使用的[ScrollController]
  ///
  /// 如果为null，它将实例化一个新的ScrollController
  ///
  /// 请参阅[Scrollable.controller]
  final ScrollController? scrollController;

  /// 帮助自动填充服务识别此文本输入类型的字符串列表
  ///
  /// 当设置为null或空时，此文本输入将不会向平台发送其自动填充信息，
  /// 从而防止它参与由不同[AutofillClient]触发的自动填充，即使它们在同一个[AutofillScope]中。
  /// 此外，在Android和Web上，将此设置为null或空将禁用此文本字段的自动填充
  ///
  /// 支持自动填充的最低平台SDK版本是Android的API级别26和iOS的10.0
  ///
  /// ### 设置iOS自动填充：
  ///
  /// 要提供最佳用户体验并确保您的应用完全支持iOS上的密码自动填充，请按照以下步骤操作：
  ///
  /// * 设置iOS应用的[关联域](https://developer.apple.com/documentation/safariservices/supporting_associated_domains_in_your_app)
  /// * 某些自动填充提示仅适用于特定的[keyboardType]。例如，
  ///   [AutofillHints.name]需要[TextInputType.name]，[AutofillHints.email]仅适用于[TextInputType.emailAddress]。
  ///   确保输入字段具有兼容的[keyboardType]。根据经验，[TextInputType.name]可以很好地适用于iOS上预定义的许多自动填充提示
  ///
  /// ### 故障排除自动填充
  ///
  /// 自动填充服务提供商严重依赖[autofillHints]。确保[autofillHints]中的条目
  /// 受当前使用的自动填充服务支持（服务名称通常可以在移动设备的系统设置中找到）
  ///
  /// #### 当我点击文本字段时，自动填充UI拒绝显示
  ///
  /// 检查设备的系统设置，确保自动填充已打开，并且自动填充服务中存储了可用的凭据
  ///
  /// * iOS密码自动填充：转到设置 -> 密码，打开"自动填充密码"，
  ///   并通过按右上角的"+"按钮添加用于测试的新密码。如果您的应用未设置关联域，
  ///   请使用任意"网站"。只要至少存储了一个密码，当密码相关字段获得焦点时，
  ///   您应该能够在软键盘的快速输入栏中看到一个钥匙形状的图标
  ///
  /// * iOS联系信息自动填充：iOS似乎从当前与设备关联的Apple ID中提取联系信息。
  ///   转到设置 -> Apple ID（通常是第一个条目，或者如果您尚未在设备上设置，则为"登录到您的iPhone"），
  ///   并填写相关字段。如果您希望测试更多联系信息类型，请尝试在联系人 -> 我的名片中添加它们
  ///
  /// * Android自动填充：转到设置 -> 系统 -> 语言和输入 -> 自动填充服务。
  ///   启用您选择的自动填充服务，并确保有与您的应用关联的可用凭据
  ///
  /// #### 我调用了`TextInput.finishAutofillContext`但自动填充保存提示没有显示
  ///
  /// * iOS：iOS在保存用户密码时可能不会显示提示或任何其他视觉指示。
  ///   转到设置 -> 密码，检查您的新密码是否已保存。
  ///   如果未正确设置应用中的关联域，保存密码和自动生成强密码都不起作用。
  ///   要设置关联域，请按照<https://developer.apple.com/documentation/safariservices/supporting_associated_domains_in_your_app>中的说明操作
  ///
  /// 为获得最佳效果，提示字符串需要被平台的自动填充服务理解。
  /// 提示字符串的常见值可以在[AutofillHints]中找到，以及它们在不同平台上的可用性
  ///
  /// 如果可自动填充的输入字段需要使用在不同平台上转换为不同字符串的自定义提示，
  /// 实现此目的的最简单方法是根据[defaultTargetPlatform]的值返回不同的提示字符串
  ///
  /// 列表中的每个提示（如果未被忽略）将被转换为平台的自动填充服务理解的平台自动填充提示类型：
  ///
  /// * 在iOS上，仅考虑列表中的第一个提示。该提示将被转换为
  ///   [UITextContentType](https://developer.apple.com/documentation/uikit/uitextcontenttype)
  ///
  /// * 在Android上，列表中的所有提示都被转换为Android提示字符串
  ///
  /// * 在Web上，仅考虑第一个提示，并将其转换为"autocomplete"字符串
  ///
  /// 提供平台上预定义的自动填充提示并不自动授予输入字段自动填充的资格。
  /// 最终，由当前负责的自动填充服务决定输入字段是否适合自动填充以及自动填充候选项是什么
  ///
  /// 另请参阅：
  ///
  /// * [AutofillHints]，在至少一个平台上预定义的自动填充提示字符串列表
  ///
  /// * [UITextContentType](https://developer.apple.com/documentation/uikit/uitextcontenttype)，
  ///   iOS等效项
  ///
  /// * Android [autofillHints](https://developer.android.com/reference/android/view/View#setAutofillHints(java.lang.String...))，
  ///   Android等效项
  ///
  /// * [autocomplete](https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes/autocomplete)属性，
  ///   Web等效项
  final Iterable<String>? autofillHints;

  /// 用于保存和恢复文本字段状态的恢复ID
  ///
  /// 如果非null，文本字段将持久化并恢复其当前滚动偏移量，
  /// 并且 - 如果未提供[controller] - 文本字段的内容。
  /// 如果提供了[controller]，则由该控制器的所有者负责持久化和恢复它，
  /// 例如通过使用[RestorableTextEditingController]
  ///
  /// 此部件的状态保存在从周围[RestorationScope]获取的[RestorationBucket]中，
  /// 使用提供的恢复ID
  ///
  /// 另请参阅：
  ///
  ///  * [RestorationManager]，它解释了Flutter中的状态恢复如何工作
  final String? restorationId;

  /// 内容插入配置
  final ContentInsertionConfiguration? contentInsertionConfiguration;

  /// 创建此部件的状态对象
  @override
  State<MongolTextField> createState() => _TextFieldState();

  /// 向诊断树添加属性
  ///
  /// 用于在调试模式下显示部件的属性信息
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TextEditingController>(
        'controller', controller,
        defaultValue: null));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode,
        defaultValue: null));
    properties
        .add(DiagnosticsProperty<bool>('enabled', enabled, defaultValue: null));
    properties.add(DiagnosticsProperty<InputDecoration>(
        'decoration', decoration,
        defaultValue: const InputDecoration()));
    properties.add(DiagnosticsProperty<TextInputType>(
        'keyboardType', keyboardType,
        defaultValue: TextInputType.text));
    properties.add(
        DiagnosticsProperty<TextStyle>('style', style, defaultValue: null));
    properties.add(
        DiagnosticsProperty<bool>('autofocus', autofocus, defaultValue: false));
    properties.add(DiagnosticsProperty<String>(
        'obscuringCharacter', obscuringCharacter,
        defaultValue: '•'));
    properties.add(DiagnosticsProperty<bool>('obscureText', obscureText,
        defaultValue: false));
    properties.add(DiagnosticsProperty<bool>('autocorrect', autocorrect,
        defaultValue: true));
    properties.add(DiagnosticsProperty<bool>(
        'enableSuggestions', enableSuggestions,
        defaultValue: true));
    properties.add(IntProperty('maxLines', maxLines, defaultValue: 1));
    properties.add(IntProperty('minLines', minLines, defaultValue: null));
    properties.add(
        DiagnosticsProperty<bool>('expands', expands, defaultValue: false));
    properties.add(IntProperty('maxLength', maxLength, defaultValue: null));
    properties.add(EnumProperty<MaxLengthEnforcement>(
        'maxLengthEnforcement', maxLengthEnforcement,
        defaultValue: null));
    properties.add(EnumProperty<TextInputAction>(
        'textInputAction', textInputAction,
        defaultValue: null));
    properties.add(EnumProperty<MongolTextAlign>('textAlign', textAlign,
        defaultValue: MongolTextAlign.top));
    properties.add(DiagnosticsProperty<TextAlignHorizontal>(
        'textAlignHorizontal', textAlignHorizontal,
        defaultValue: null));
    properties
        .add(DoubleProperty('cursorWidth', cursorWidth, defaultValue: null));
    properties
        .add(DoubleProperty('cursorHeight', cursorHeight, defaultValue: 2.0));
    properties.add(DiagnosticsProperty<Radius>('cursorRadius', cursorRadius,
        defaultValue: null));
    properties
        .add(ColorProperty('cursorColor', cursorColor, defaultValue: null));
    properties.add(DiagnosticsProperty<Brightness>(
        'keyboardAppearance', keyboardAppearance,
        defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>(
        'scrollPadding', scrollPadding,
        defaultValue: const EdgeInsets.all(20.0)));
    properties.add(FlagProperty('selectionEnabled',
        value: selectionEnabled,
        defaultValue: true,
        ifFalse: 'selection disabled'));
    properties.add(DiagnosticsProperty<TextSelectionControls>(
        'selectionControls', selectionControls,
        defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollController>(
        'scrollController', scrollController,
        defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollPhysics>(
        'scrollPhysics', scrollPhysics,
        defaultValue: null));
    properties.add(DiagnosticsProperty<List<String>>('contentCommitMimeTypes',
        contentInsertionConfiguration?.allowedMimeTypes ?? const <String>[],
        defaultValue: contentInsertionConfiguration == null
            ? const <String>[]
            : kDefaultContentInsertionMimeTypes));
  }
}

/// MongolTextField的状态类
class _TextFieldState extends State<MongolTextField>
    with RestorationMixin
    implements MongolTextSelectionGestureDetectorBuilderDelegate {
  /// 可恢复的文本编辑控制器
  RestorableTextEditingController? _controller;

  /// 获取有效的文本编辑控制器
  ///
  /// 如果用户提供了控制器，则使用用户提供的；否则使用本地创建的
  TextEditingController get _effectiveController =>
      widget.controller ?? _controller!.value;

  /// 焦点节点
  FocusNode? _focusNode;

  /// 获取有效的焦点节点
  ///
  /// 如果用户提供了焦点节点，则使用用户提供的；否则创建一个新的
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_focusNode ??= FocusNode());

  /// 获取有效的最大长度强制执行策略
  MaxLengthEnforcement get _effectiveMaxLengthEnforcement =>
      widget.maxLengthEnforcement ??
      LengthLimitingTextInputFormatter.getDefaultMaxLengthEnforcement(
          Theme.of(context).platform);

  /// 是否悬停
  bool _isHovering = false;

  /// 是否需要计数器
  bool get needsCounter =>
      widget.maxLength != null &&
      widget.decoration != null &&
      widget.decoration!.counterText == null;

  /// 是否显示选择手柄
  bool _showSelectionHandles = false;

  /// 文本选择手势检测器构建器
  late _TextFieldSelectionGestureDetectorBuilder
      _selectionGestureDetectorBuilder;

  // MongolTextSelectionGestureDetectorBuilderDelegate API
  @override
  late bool forcePressEnabled;

  @override
  final GlobalKey<MongolEditableTextState> editableTextKey =
      GlobalKey<MongolEditableTextState>();

  @override
  bool get selectionEnabled => widget.selectionEnabled;
  // End of MongolTextSelectionGestureDetectorBuilderDelegate API

  /// 文本字段是否启用
  bool get _isEnabled => widget.enabled ?? widget.decoration?.enabled ?? true;

  /// 当前文本长度
  int get _currentLength => _effectiveController.value.text.characters.length;

  /// 是否有内在错误（字符数超过限制）
  bool get _hasIntrinsicError =>
      widget.maxLength != null &&
      widget.maxLength! > 0 &&
      _effectiveController.value.text.characters.length > widget.maxLength!;

  /// 是否有错误
  bool get _hasError =>
      widget.decoration?.errorText != null || _hasIntrinsicError;

  /// 获取有效的装饰
  ///
  /// 根据当前状态和配置，计算出最终使用的装饰
  InputDecoration _getEffectiveDecoration() {
    final localizations = MaterialLocalizations.of(context);
    final themeData = Theme.of(context);
    final effectiveDecoration = (widget.decoration ?? const InputDecoration())
        .applyDefaults(themeData.inputDecorationTheme)
        .copyWith(
          enabled: _isEnabled,
          hintMaxLines: widget.decoration?.hintMaxLines ?? widget.maxLines,
        );

    // 如果直接提供了计数器或计数器文本，则不需要构建任何东西
    if (effectiveDecoration.counter != null ||
        effectiveDecoration.counterText != null) {
      return effectiveDecoration;
    }

    // 如果提供了buildCounter，则使用它生成计数器部件
    Widget? counter;
    final currentLength = _currentLength;
    if (effectiveDecoration.counter == null &&
        effectiveDecoration.counterText == null &&
        widget.buildCounter != null) {
      final isFocused = _effectiveFocusNode.hasFocus;
      final builtCounter = widget.buildCounter!(
        context,
        currentLength: currentLength,
        maxLength: widget.maxLength,
        isFocused: isFocused,
      );
      // 如果buildCounter返回null，则不向字段添加计数器部件
      if (builtCounter != null) {
        counter = Semantics(
          container: true,
          liveRegion: isFocused,
          child: builtCounter,
        );
      }
      return effectiveDecoration.copyWith(counter: counter);
    }

    final maxLength = widget.maxLength;
    if (maxLength == null) {
      return effectiveDecoration; // 没有计数器部件
    }

    var counterText = '$currentLength';
    var semanticCounterText = '';

    // 处理真实的maxLength（正数）
    if (maxLength > 0) {
      // 在计数器中显示maxLength
      counterText += '/$maxLength';
      final remaining = (maxLength - currentLength).clamp(0, maxLength);
      semanticCounterText =
          localizations.remainingTextFieldCharacterCount(remaining);
    }

    if (_hasIntrinsicError) {
      return effectiveDecoration.copyWith(
        errorText: effectiveDecoration.errorText ?? '',
        counterStyle: effectiveDecoration.errorStyle ??
            themeData.textTheme.bodySmall!
                .copyWith(color: themeData.colorScheme.error),
        counterText: counterText,
        semanticCounterText: semanticCounterText,
      );
    }

    return effectiveDecoration.copyWith(
      counterText: counterText,
      semanticCounterText: semanticCounterText,
    );
  }

  /// 初始化状态
  @override
  void initState() {
    super.initState();
    _selectionGestureDetectorBuilder =
        _TextFieldSelectionGestureDetectorBuilder(state: this);
    if (widget.controller == null) {
      _createLocalController();
    }
    _effectiveFocusNode.canRequestFocus = _isEnabled;
  }

  /// 是否可以请求焦点
  bool get _canRequestFocus {
    final mode = MediaQuery.maybeOf(context)?.navigationMode ??
        NavigationMode.traditional;
    switch (mode) {
      case NavigationMode.traditional:
        return _isEnabled;
      case NavigationMode.directional:
        return true;
    }
  }

  /// 依赖项更改时调用
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _effectiveFocusNode.canRequestFocus = _canRequestFocus;
  }

  /// 部件更新时调用
  @override
  void didUpdateWidget(MongolTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && oldWidget.controller != null) {
      _createLocalController(oldWidget.controller!.value);
    } else if (widget.controller != null && oldWidget.controller == null) {
      unregisterFromRestoration(_controller!);
      _controller!.dispose();
      _controller = null;
    }
    _effectiveFocusNode.canRequestFocus = _canRequestFocus;
    if (_effectiveFocusNode.hasFocus &&
        widget.readOnly != oldWidget.readOnly &&
        _isEnabled) {
      if (_effectiveController.selection.isCollapsed) {
        _showSelectionHandles = !widget.readOnly;
      }
    }
  }

  /// 恢复状态
  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    if (_controller != null) {
      _registerController();
    }
  }

  /// 注册控制器
  void _registerController() {
    assert(_controller != null);
    registerForRestoration(_controller!, 'controller');
  }

  /// 创建本地控制器
  void _createLocalController([TextEditingValue? value]) {
    assert(_controller == null);
    _controller = value == null
        ? RestorableTextEditingController()
        : RestorableTextEditingController.fromValue(value);
    if (!restorePending) {
      _registerController();
    }
  }

  /// 获取恢复ID
  @override
  String? get restorationId => widget.restorationId;

  /// 释放资源
  @override
  void dispose() {
    _focusNode?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  /// 获取可编辑文本状态
  MongolEditableTextState? get _editableText => editableTextKey.currentState;

  /// 请求键盘
  void _requestKeyboard() {
    _editableText?.requestKeyboard();
  }

  bool _supportsMouseDrivenSelectionUi(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return false;
    }
  }

  /// 是否应该显示选择手柄
  bool _shouldShowSelectionHandles(SelectionChangedCause? cause) {
    if ((kIsWeb ||
            _supportsMouseDrivenSelectionUi(Theme.of(context).platform)) &&
        _effectiveController.selection.isValid &&
        !_effectiveController.selection.isCollapsed) {
      return true;
    }

    // 当文本字段被不触发选择覆盖层的东西激活时，我们也不应该显示手柄
    if (!_selectionGestureDetectorBuilder.shouldShowSelectionToolbar) {
      return false;
    }

    if (cause == SelectionChangedCause.keyboard) return false;

    if (widget.readOnly && _effectiveController.selection.isCollapsed) {
      return false;
    }

    if (!_isEnabled) return false;

    if (cause == SelectionChangedCause.longPress) return true;

    return _effectiveController.text.isNotEmpty;
  }

  /// 处理选择更改
  void _handleSelectionChanged(
      TextSelection selection, SelectionChangedCause? cause) {
    final willShowSelectionHandles = _shouldShowSelectionHandles(cause);
    if (willShowSelectionHandles != _showSelectionHandles) {
      setState(() {
        _showSelectionHandles = willShowSelectionHandles;
      });
    }

    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        if (cause == SelectionChangedCause.longPress) {
          _editableText?.bringIntoView(selection.base);
        }
        return;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      // Do nothing.
    }
  }

  /// 当选择手柄被点击时切换工具栏
  void _handleSelectionHandleTapped() {
    if (_effectiveController.selection.isCollapsed) {
      _editableText!.toggleToolbar();
    }
  }

  /// 处理悬停
  void _handleHover(bool hovering) {
    if (hovering != _isHovering) {
      setState(() {
        _isHovering = hovering;
      });
    }
  }

  /// 构建部件
  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    assert(debugCheckHasMaterialLocalizations(context));
    assert(
      !(widget.style != null &&
          widget.style!.inherit == false &&
          (widget.style!.fontSize == null ||
              widget.style!.textBaseline == null)),
      'inherit false style must supply fontSize and textBaseline',
    );

    final ThemeData theme = Theme.of(context);
    final DefaultSelectionStyle selectionStyle =
        DefaultSelectionStyle.of(context);
    final TextStyle style = theme.textTheme.titleMedium!.merge(widget.style);
    final Brightness keyboardAppearance =
        widget.keyboardAppearance ?? theme.brightness;
    final TextEditingController controller = _effectiveController;
    final FocusNode focusNode = _effectiveFocusNode;
    final List<TextInputFormatter> formatters = <TextInputFormatter>[
      ...?widget.inputFormatters,
      if (widget.maxLength != null)
        LengthLimitingTextInputFormatter(
          widget.maxLength,
          maxLengthEnforcement: _effectiveMaxLengthEnforcement,
        ),
    ];

    var textSelectionControls = widget.selectionControls;
    final bool cursorOpacityAnimates;
    Offset? cursorOffset;
    var cursorColor = widget.cursorColor;
    final Color selectionColor;
    var cursorRadius = widget.cursorRadius;

    switch (theme.platform) {
      case TargetPlatform.iOS:
        final cupertinoTheme = CupertinoTheme.of(context);
        forcePressEnabled = true;
        textSelectionControls ??= mongolTextSelectionControls;
        cursorOpacityAnimates = true;
        cursorColor = widget.cursorColor ??
            selectionStyle.cursorColor ??
            cupertinoTheme.primaryColor;
        selectionColor = selectionStyle.selectionColor ??
            cupertinoTheme.primaryColor.withOpacity(0.40);
        cursorRadius ??= const Radius.circular(2.0);
        cursorOffset = Offset(
            iOSHorizontalOffset / MediaQuery.of(context).devicePixelRatio, 0);
        break;

      case TargetPlatform.macOS:
        final cupertinoTheme = CupertinoTheme.of(context);
        forcePressEnabled = false;
        textSelectionControls ??= mongolTextSelectionControls;
        cursorOpacityAnimates = true;
        cursorColor = widget.cursorColor ??
            selectionStyle.cursorColor ??
            cupertinoTheme.primaryColor;
        selectionColor = selectionStyle.selectionColor ??
            cupertinoTheme.primaryColor.withOpacity(0.40);
        cursorRadius ??= const Radius.circular(2.0);
        cursorOffset = Offset(
            iOSHorizontalOffset / MediaQuery.of(context).devicePixelRatio, 0);
        break;

      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        forcePressEnabled = false;
        textSelectionControls ??= mongolTextSelectionControls;
        cursorOpacityAnimates = false;
        cursorColor = widget.cursorColor ??
            selectionStyle.cursorColor ??
            theme.colorScheme.primary;
        selectionColor = selectionStyle.selectionColor ??
            theme.colorScheme.primary.withOpacity(0.40);
        break;

      case TargetPlatform.linux:
      case TargetPlatform.windows:
        forcePressEnabled = false;
        textSelectionControls ??= mongolTextSelectionControls;
        cursorOpacityAnimates = false;
        cursorColor = widget.cursorColor ??
            selectionStyle.cursorColor ??
            theme.colorScheme.primary;
        selectionColor = selectionStyle.selectionColor ??
            theme.colorScheme.primary.withOpacity(0.40);
        break;
    }

    Widget child = RepaintBoundary(
      child: UnmanagedRestorationScope(
        bucket: bucket,
        child: MongolEditableText(
          key: editableTextKey,
          readOnly: widget.readOnly || !_isEnabled,
          toolbarOptions: widget.toolbarOptions,
          showCursor: widget.showCursor,
          showSelectionHandles: _showSelectionHandles,
          controller: controller,
          focusNode: focusNode,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          style: style,
          textAlign: widget.textAlign,
          autofocus: widget.autofocus,
          onTapOutside: widget.onTapOutside,
          obscuringCharacter: widget.obscuringCharacter,
          obscureText: widget.obscureText,
          autocorrect: widget.autocorrect,
          enableSuggestions: widget.enableSuggestions,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          expands: widget.expands,
          selectionColor: selectionColor,
          selectionControls:
              widget.selectionEnabled ? textSelectionControls : null,
          onChanged: widget.onChanged,
          onSelectionChanged: _handleSelectionChanged,
          onEditingComplete: widget.onEditingComplete,
          onSubmitted: widget.onSubmitted,
          onAppPrivateCommand: widget.onAppPrivateCommand,
          onSelectionHandleTapped: _handleSelectionHandleTapped,
          inputFormatters: formatters,
          rendererIgnoresPointer: true,
          mouseCursor:
              MouseCursor.defer, // MongolTextField will handle the cursor
          cursorWidth: widget.cursorWidth,
          cursorHeight: widget.cursorHeight,
          cursorRadius: cursorRadius,
          cursorColor: cursorColor,
          cursorOpacityAnimates: cursorOpacityAnimates,
          cursorOffset: cursorOffset,
          scrollPadding: widget.scrollPadding,
          keyboardAppearance: keyboardAppearance,
          enableInteractiveSelection: widget.enableInteractiveSelection,
          enableWebReadOnlyInputConnection:
              widget.enableWebReadOnlyInputConnection,
          dragStartBehavior: widget.dragStartBehavior,
          scrollController: widget.scrollController,
          scrollPhysics: widget.scrollPhysics,
          autofillHints: widget.autofillHints,
          restorationId: 'editable',
          contentInsertionConfiguration: widget.contentInsertionConfiguration,
          contextMenuBuilder: widget.contextMenuBuilder,
        ),
      ),
    );

    if (widget.decoration != null) {
      child = AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[focusNode, controller]),
        builder: (BuildContext context, Widget? child) {
          return MongolInputDecorator(
            decoration: _getEffectiveDecoration(),
            baseStyle: widget.style,
            textAlign: widget.textAlign,
            textAlignHorizontal: widget.textAlignHorizontal,
            isHovering: _isHovering,
            isFocused: focusNode.hasFocus,
            isEmpty: controller.value.text.isEmpty,
            expands: widget.expands,
            child: child,
          );
        },
        child: child,
      );
    }
    final effectiveMouseCursor = MaterialStateProperty.resolveAs<MouseCursor>(
      widget.mouseCursor ?? mongolVerticalTextCursor,
      <MaterialState>{
        if (!_isEnabled) MaterialState.disabled,
        if (_isHovering) MaterialState.hovered,
        if (focusNode.hasFocus) MaterialState.focused,
        if (_hasError) MaterialState.error,
      },
    );

    final int? semanticsMaxValueLength;
    if (_effectiveMaxLengthEnforcement != MaxLengthEnforcement.none &&
        widget.maxLength != null &&
        widget.maxLength! > 0) {
      semanticsMaxValueLength = widget.maxLength;
    } else {
      semanticsMaxValueLength = null;
    }

    return TextFieldTapRegion(
      child: MouseRegion(
        cursor: effectiveMouseCursor,
        onEnter: (PointerEnterEvent event) => _handleHover(true),
        onExit: (PointerExitEvent event) => _handleHover(false),
        child: IgnorePointer(
          ignoring: !_isEnabled,
          child: AnimatedBuilder(
            animation: controller, // changes the _currentLength
            builder: (BuildContext context, Widget? child) {
              return Semantics(
                maxValueLength: semanticsMaxValueLength,
                currentValueLength: _currentLength,
                onTap: widget.readOnly
                    ? null
                    : () {
                        if (!_effectiveController.selection.isValid) {
                          _effectiveController.selection =
                              TextSelection.collapsed(
                                  offset: _effectiveController.text.length);
                        }
                        _requestKeyboard();
                      },
                child: child,
              );
            },
            child: _selectionGestureDetectorBuilder.buildGestureDetector(
              behavior: HitTestBehavior.translucent,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
