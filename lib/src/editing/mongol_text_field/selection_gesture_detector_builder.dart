part of '../mongol_text_field.dart';

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

  bool get _isApplePlatform => isApplePlatform(_platform);

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
