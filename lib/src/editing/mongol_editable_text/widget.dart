part of '../mongol_editable_text.dart';

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
    MongolToolbarOptions? toolbarOptions,
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
        toolbarOptions = resolveEditableToolbarOptions(
          toolbarOptions: toolbarOptions,
          readOnly: readOnly,
          obscureText: obscureText,
          selectionControls: selectionControls,
        ),
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
  final MongolToolbarOptions toolbarOptions;

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
