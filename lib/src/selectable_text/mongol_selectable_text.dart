// Copyright 2014 The Flutter Authors.
// Copyright 2020 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../base/mongol_text_align.dart';
import '../editing/mongol_editable_text.dart'
    show MongolEditableTextContextMenuBuilder, MongolEditableTextState;
import '../editing/mongol_mouse_cursors.dart';
import '../editing/mongol_text_field.dart';

/// 垂直可选择的蒙古文文本组件
///
/// 该组件基于只读 [MongolTextField] 实现，因此会复用系统文本选择与复制菜单。
/// 支持长按选择、全选、复制，并能正确将“当前选区”复制到剪切板。
///
/// 示例：
/// ```dart
/// MongolSelectableText(
///   'Hello, World!',
///   style: TextStyle(fontSize: 20),
/// )
/// ```
///
/// 与 [MongolText] 不同，此组件允许用户与文本交互和选择。
/// 与 [MongolTextField] 不同，此组件是只读的。
class MongolSelectableText extends StatefulWidget {
  /// 创建一个可选择的蒙古文文本组件
  const MongolSelectableText(
    String this.data, {
    super.key,
    this.textAlign = MongolTextAlign.top,
    this.style,
    this.textScaleFactor = 1.0,
    this.maxLines,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.rotateCJK = true,
    this.selectionColor = const Color.fromARGB(64, 66, 133, 244),
    this.controller,
    this.onSelectionChanged,
    this.contextMenuBuilder,
  }) : textSpan = null;

  /// 创建一个具有富文本（TextSpan）的可选择蒙古文文本组件
  const MongolSelectableText.rich(
    TextSpan this.textSpan, {
    super.key,
    this.textAlign = MongolTextAlign.top,
    this.style,
    this.textScaleFactor = 1.0,
    this.maxLines,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.rotateCJK = true,
    this.selectionColor = const Color.fromARGB(64, 66, 133, 244),
    this.controller,
    this.onSelectionChanged,
    this.contextMenuBuilder,
  }) : data = null;

  /// 要显示的文本内容（简单文本）
  final String? data;

  /// 要显示的富文本内容（TextSpan）
  final TextSpan? textSpan;

  /// 文本样式
  final TextStyle? style;

  /// 文本垂直对齐方式
  final MongolTextAlign textAlign;

  /// 文本缩放因子
  final double textScaleFactor;

  /// 最大行数
  final int? maxLines;

  /// 是否在软换行処换行
  final bool softWrap;

  /// 溢出时的处理方式
  final TextOverflow overflow;

  /// CJK字符是否旋转90度
  final bool rotateCJK;

  /// 选区高亮颜色
  final Color selectionColor;

  /// 外部文本控制器。
  ///
  /// 若不提供，组件会根据 [data] / [textSpan] 创建内部控制器。
  final TextEditingController? controller;

  /// 选择改变时的回调
  final SelectionChangedCallback? onSelectionChanged;

  /// 自定义上下文菜单构建器（长按/右键时显示的菜单）。
  ///
  /// 若为 null，默认显示带"全选"和"复制"按钮的平台自适应工具栏。
  final MongolEditableTextContextMenuBuilder? contextMenuBuilder;

  @override
  State<MongolSelectableText> createState() => _MongolSelectableTextState();
}

class _MongolSelectableTextState extends State<MongolSelectableText>
    with AutomaticKeepAliveClientMixin {
  static final ValueNotifier<Object?> _activeSelectionOwner =
      ValueNotifier<Object?>(null);
  static bool _webContextMenuDisabled = false;

  late final TextEditingController _internalController;
  late final FocusNode _focusNode;
  final Object _selectionOwnerToken = Object();
  TextSelection _lastSelection = const TextSelection.collapsed(offset: -1);
  TextSelection? _lastNonCollapsedSelection;

  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController;

  String get _initialText =>
      widget.textSpan?.toPlainText(includeSemanticsLabels: false) ??
      widget.data ??
      '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // On web, the browser page context menu may steal right-click events
    // before Flutter's editable selection menu can appear.
    if (kIsWeb && !_webContextMenuDisabled) {
      BrowserContextMenu.disableContextMenu();
      _webContextMenuDisabled = true;
    }

    _internalController = TextEditingController(text: _initialText);
    _focusNode = FocusNode(debugLabel: 'MongolSelectableText');
    _focusNode.addListener(_handleFocusChanged);
    _effectiveController.addListener(_handleControllerChanged);
    _activeSelectionOwner.addListener(_handleActiveSelectionOwnerChanged);
  }

  @override
  void didUpdateWidget(covariant MongolSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.removeListener(_handleControllerChanged);
      _effectiveController.addListener(_handleControllerChanged);
    }

    if (widget.controller == null) {
      final String next = _initialText;
      if (_internalController.text != next) {
        _internalController.value = _internalController.value.copyWith(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
          composing: TextRange.empty,
        );
      }
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_handleControllerChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _activeSelectionOwner.removeListener(_handleActiveSelectionOwnerChanged);
    if (identical(_activeSelectionOwner.value, _selectionOwnerToken)) {
      _activeSelectionOwner.value = null;
    }
    _focusNode.dispose();
    _internalController.dispose();
    super.dispose();
  }

  void _handleActiveSelectionOwnerChanged() {
    if (identical(_activeSelectionOwner.value, _selectionOwnerToken)) {
      return;
    }

    _collapseSelection();
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
  }

  void _handleFocusChanged() {
    // Match common text control behavior: blur clears the active selection.
    if (_focusNode.hasFocus) {
      return;
    }
    _collapseSelection();
    if (identical(_activeSelectionOwner.value, _selectionOwnerToken)) {
      _activeSelectionOwner.value = null;
    }
  }

  void _collapseSelection() {
    final TextSelection selection = _effectiveController.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return;
    }

    final int offset = selection.extentOffset.clamp(
      0,
      _effectiveController.text.length,
    );
    _effectiveController.selection = TextSelection.collapsed(offset: offset);
  }

  void _handleControllerChanged() {
    final TextSelection selection = _effectiveController.selection;
    if (selection == _lastSelection) {
      return;
    }

    // Keep the active selectable instance focused so copy/shortcut actions map
    // to the current selection when multiple MongolSelectableText widgets exist.
    if (selection.isValid &&
        !selection.isCollapsed &&
        !_focusNode.hasFocus &&
        !kIsWeb) {
      _focusNode.requestFocus();
    }

    if (selection.isValid && !selection.isCollapsed) {
      _lastNonCollapsedSelection = selection;
      _activeSelectionOwner.value = _selectionOwnerToken;
    } else if (identical(_activeSelectionOwner.value, _selectionOwnerToken)) {
      _activeSelectionOwner.value = null;
    }

    _lastSelection = selection;
    widget.onSelectionChanged?.call(selection, SelectionChangedCause.tap);
  }

  TextSelection? _normalizedSelection(
      TextSelection? selection, int textLength) {
    if (selection == null || !selection.isValid || selection.isCollapsed) {
      return null;
    }
    final int start = selection.start;
    final int end = selection.end;
    if (start < 0 || end < 0 || start > textLength || end > textLength) {
      return null;
    }
    return selection;
  }

  /// 默认的上下文菜单：显示"全选"和"复制"两个按钮。
  Widget _defaultContextMenuBuilder(
    BuildContext context,
    MongolEditableTextState editableTextState,
  ) {
    final MaterialLocalizations localizations =
        MaterialLocalizations.of(context);
    final List<ContextMenuButtonItem> items = <ContextMenuButtonItem>[];
    final String text = _effectiveController.text;
    final int textLength = text.length;
    final TextSelection selection = _effectiveController.selection;
    final TextSelection stateSelection =
        editableTextState.textEditingValue.selection;
    final TextSelection? effectiveSelection =
        _normalizedSelection(selection, textLength) ??
            _normalizedSelection(stateSelection, textLength) ??
            _normalizedSelection(_lastNonCollapsedSelection, textLength);

    if (text.isNotEmpty &&
        selection != TextSelection(baseOffset: 0, extentOffset: text.length)) {
      items.add(
        ContextMenuButtonItem(
          label: localizations.selectAllButtonLabel,
          onPressed: () {
            _effectiveController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: text.length,
            );
          },
        ),
      );
    }

    if (effectiveSelection != null) {
      items.add(
        ContextMenuButtonItem(
          label: localizations.copyButtonLabel,
          onPressed: () async {
            final TextSelection current = _normalizedSelection(
                  _effectiveController.selection,
                  _effectiveController.text.length,
                ) ??
                _normalizedSelection(
                  editableTextState.textEditingValue.selection,
                  _effectiveController.text.length,
                ) ??
                effectiveSelection;
            await Clipboard.setData(
              ClipboardData(
                  text: current.textInside(_effectiveController.text)),
            );
            editableTextState.hideToolbar(false);
          },
        ),
      );
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  TextStyle _effectiveStyle(BuildContext context) {
    final TextStyle base = widget.style ?? DefaultTextStyle.of(context).style;
    final List<String> fallback = <String>[
      'Noto Sans Mongolian',
      'Noto Sans CJK SC',
      'Microsoft YaHei',
      'PingFang SC',
      'SimSun',
      'sans-serif',
    ];
    return base
        .copyWith(
          fontFamilyFallback: (base.fontFamilyFallback == null ||
                  base.fontFamilyFallback!.isEmpty)
              ? fallback
              : base.fontFamilyFallback,
        )
        .apply(fontSizeFactor: widget.textScaleFactor);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ThemeData theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textSelectionTheme: theme.textSelectionTheme.copyWith(
          selectionColor: widget.selectionColor,
        ),
      ),
      child: MongolTextField(
        controller: _effectiveController,
        focusNode: _focusNode,
        readOnly: true,
        enableWebReadOnlyInputConnection: false,
        showCursor: false,
        enableInteractiveSelection: true,
        mouseCursor: mongolVerticalTextCursor,
        toolbarOptions: const ToolbarOptions(
          copy: true,
          cut: false,
          paste: false,
          selectAll: true,
        ),
        contextMenuBuilder:
            widget.contextMenuBuilder ?? _defaultContextMenuBuilder,
        style: _effectiveStyle(context),
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        minLines: 1,
        expands: false,
        obscureText: false,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
          counterText: '',
        ),
      ),
    );
  }
}
