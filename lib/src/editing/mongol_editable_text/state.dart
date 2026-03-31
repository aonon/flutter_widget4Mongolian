part of '../mongol_editable_text.dart';

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

  /// Returns true if stylus/scribble handwriting is currently in progress.
  ///
  /// Uses try-catch because the relevant getter (`stylusHandwritingInProgress`
  /// / `scribbleInProgress`) may not exist in every Flutter SDK version.
  bool _isHandwritingInProgress() {
    final dynamic conn = _textInputConnection;
    if (conn == null) return false;
    try {
      return (conn.stylusHandwritingInProgress as bool?) ?? false;
    } on NoSuchMethodError {
      // getter absent in this SDK version – fall through.
    }
    try {
      return (conn.scribbleInProgress as bool?) ?? false;
    } on NoSuchMethodError {
      // getter absent in this SDK version – fall through.
    }
    return false;
  }

  /// Schedules [bringIntoView] for the current selection extent after the next
  /// frame. Used by toolbar actions that mutate text (cut, paste) because the
  /// renderEditable hasn't updated yet when the action runs.
  void _bringSelectionIntoViewAfterLayout() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        bringIntoView(textEditingValue.selection.extent);
      }
    });
  }

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
      widget.cursorColor.withValues(alpha: _cursorBlinkOpacityController.value);

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

      if (!isApplePlatform(defaultTargetPlatform) &&
          !isDesktopPlatform(defaultTargetPlatform)) {
        // Android / Fuchsia: collapse the selection and hide toolbar+handles.
        userUpdateTextEditingValue(
          TextEditingValue(
            text: textEditingValue.text,
            selection:
                TextSelection.collapsed(offset: textEditingValue.selection.end),
          ),
          SelectionChangedCause.toolbar,
        );
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
      _bringSelectionIntoViewAfterLayout();
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
      _bringSelectionIntoViewAfterLayout();
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
      if (isDesktopPlatform(defaultTargetPlatform)) {
        hideToolbar();
      }
      if (!isApplePlatform(defaultTargetPlatform)) {
        bringIntoView(textEditingValue.selection.extent);
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

  /// Returns the [ContextMenuButtonItem]s for the given [MongolToolbarOptions].
  @Deprecated(
    'Use `contextMenuBuilder` instead of `toolbarOptions`. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  List<ContextMenuButtonItem>? buttonItemsForToolbarOptions(
      [TargetPlatform? targetPlatform]) {
    final MongolToolbarOptions toolbarOptions = widget.toolbarOptions;
    if (toolbarOptions == MongolToolbarOptions.empty) {
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
    final bool newTickerEnabled = TickerMode.valuesOf(context).enabled;
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
    final bool canPaste = pasteEnabled;
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
          _isHandwritingInProgress()
              ? SelectionChangedCause.stylusHandwriting
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

  bool get _isDesktop => !kIsWeb && isDesktopPlatform(defaultTargetPlatform);
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
      case SelectionChangedCause.stylusHandwriting:
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
        if (selectionBoxes.isEmpty) {
          rectToReveal = targetOffset.rect;
        } else {
          rectToReveal = selection.baseOffset < selection.extentOffset
              ? selectionBoxes.last
              : selectionBoxes.first;
        }
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
    if (_lastBottomViewInset != View.of(context).viewInsets.bottom) {
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        _selectionOverlay?.updateForScroll();
      });
      if (_lastBottomViewInset < View.of(context).viewInsets.bottom) {
        // Because the metrics change signal from engine will come here every frame
        // (on both iOS and Android). So we don't need to show caret with animation.
        _scheduleShowCaretOnScreen(withAnimation: false);
      }
    }
    _lastBottomViewInset = View.of(context).viewInsets.bottom;
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
    renderEditable.cursorColor = widget.cursorColor
        .withValues(alpha: _cursorBlinkOpacityController.value);
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
      _lastBottomViewInset = View.of(context).viewInsets.bottom;
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
    return widget.selectionEnabled && _hasFocus && copyEnabled
        ? () {
            copySelection(SelectionChangedCause.toolbar);
          }
        : null;
  }

  VoidCallback? _semanticsOnCut(TextSelectionControls? controls) {
    return widget.selectionEnabled && _hasFocus && cutEnabled
        ? () {
            cutSelection(SelectionChangedCause.toolbar);
          }
        : null;
  }

  VoidCallback? _semanticsOnPaste(TextSelectionControls? controls) {
    return widget.selectionEnabled &&
            _hasFocus &&
            pasteEnabled &&
            (clipboardStatus == null ||
                clipboardStatus!.value == ClipboardStatus.pasteable)
        ? () {
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
