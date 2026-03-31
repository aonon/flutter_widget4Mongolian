part of '../mongol_text_field.dart';

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
    return isDesktopPlatform(platform);
  }

  /// 是否应该显示选择手柄
  bool _shouldShowSelectionHandles(SelectionChangedCause? cause) {
    final TextSelection selection = _effectiveController.selection;
    final bool supportsMouseUi =
        kIsWeb || _supportsMouseDrivenSelectionUi(Theme.of(context).platform);
    if (supportsMouseUi && selection.isValid && !selection.isCollapsed) {
      return true;
    }

    // 当文本字段被不触发选择覆盖层的东西激活时，我们也不应该显示手柄
    if (!_selectionGestureDetectorBuilder.shouldShowSelectionToolbar) {
      return false;
    }

    if (cause == SelectionChangedCause.keyboard) {
      return false;
    }

    if (widget.readOnly && selection.isCollapsed) {
      return false;
    }

    if (!_isEnabled) {
      return false;
    }

    if (cause == SelectionChangedCause.longPress) {
      return true;
    }

    return _effectiveController.text.isNotEmpty;
  }

  /// 处理选择更改
  void _handleSelectionChanged(
      TextSelection selection, SelectionChangedCause? cause) {
    final bool willShowSelectionHandles = _shouldShowSelectionHandles(cause);
    if (willShowSelectionHandles != _showSelectionHandles) {
      setState(() {
        _showSelectionHandles = willShowSelectionHandles;
      });
    }

    if (cause == SelectionChangedCause.longPress &&
        isApplePlatform(Theme.of(context).platform)) {
      _editableText?.bringIntoView(selection.base);
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

  _TextFieldPlatformVisualConfig _resolvePlatformVisualConfig(
    ThemeData theme,
    DefaultSelectionStyle selectionStyle,
  ) {
    if (isApplePlatform(theme.platform)) {
      final cupertinoTheme = CupertinoTheme.of(context);
      final Color primaryColor = cupertinoTheme.primaryColor;
      final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      return _TextFieldPlatformVisualConfig(
        forcePressEnabled: theme.platform == TargetPlatform.iOS,
        cursorOpacityAnimates: true,
        cursorOffset: Offset(iOSHorizontalOffset / devicePixelRatio, 0),
        cursorColor:
            widget.cursorColor ?? selectionStyle.cursorColor ?? primaryColor,
        selectionColor: selectionStyle.selectionColor ??
            primaryColor.withValues(alpha: 0.40),
        cursorRadius: widget.cursorRadius ?? const Radius.circular(2.0),
      );
    }

    final Color primaryColor = theme.colorScheme.primary;
    return _TextFieldPlatformVisualConfig(
      forcePressEnabled: false,
      cursorOpacityAnimates: false,
      cursorOffset: null,
      cursorColor:
          widget.cursorColor ?? selectionStyle.cursorColor ?? primaryColor,
      selectionColor:
          selectionStyle.selectionColor ?? primaryColor.withValues(alpha: 0.40),
      cursorRadius: widget.cursorRadius,
    );
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

    final _TextFieldPlatformVisualConfig visualConfig =
        _resolvePlatformVisualConfig(theme, selectionStyle);

    forcePressEnabled = visualConfig.forcePressEnabled;
    final TextSelectionControls textSelectionControls =
        widget.selectionControls ?? mongolTextSelectionControls;
    final bool cursorOpacityAnimates = visualConfig.cursorOpacityAnimates;
    final Offset? cursorOffset = visualConfig.cursorOffset;
    final Color cursorColor = visualConfig.cursorColor;
    final Color selectionColor = visualConfig.selectionColor;
    final Radius? cursorRadius = visualConfig.cursorRadius;

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
    final effectiveMouseCursor = WidgetStateProperty.resolveAs<MouseCursor>(
      widget.mouseCursor ?? mongolVerticalTextCursor,
      <WidgetState>{
        if (!_isEnabled) WidgetState.disabled,
        if (_isHovering) WidgetState.hovered,
        if (focusNode.hasFocus) WidgetState.focused,
        if (_hasError) WidgetState.error,
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

class _TextFieldPlatformVisualConfig {
  const _TextFieldPlatformVisualConfig({
    required this.forcePressEnabled,
    required this.cursorOpacityAnimates,
    required this.cursorOffset,
    required this.cursorColor,
    required this.selectionColor,
    required this.cursorRadius,
  });

  final bool forcePressEnabled;
  final bool cursorOpacityAnimates;
  final Offset? cursorOffset;
  final Color cursorColor;
  final Color selectionColor;
  final Radius? cursorRadius;
}
