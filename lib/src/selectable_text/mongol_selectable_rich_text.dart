// Copyright 2014 The Flutter Authors.
// Copyright 2020 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../base/mongol_text_align.dart';
import 'mongol_selectable_text.dart';

/// RichText selectable widget for vertical Mongolian layout.
///
/// This widget preserves TextSpan styling while reusing MongolSelectableText's
/// interaction pipeline (long press, drag selection, select all, copy,
/// platform context menu behavior).
class MongolSelectableRichText extends StatefulWidget {
  const MongolSelectableRichText.rich(
    this.textSpan, {
    super.key,
    this.textAlign = MongolTextAlign.top,
    this.style,
    this.textScaleFactor = 1.0,
    this.maxLines,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.rotateCJK = true,
    this.selectionColor = const Color.fromARGB(64, 66, 133, 244),
    this.onSelectionChanged,
  });

  final TextSpan textSpan;
  final TextStyle? style;
  final MongolTextAlign textAlign;
  final double textScaleFactor;
  final int? maxLines;
  final bool softWrap;
  final TextOverflow overflow;
  final bool rotateCJK;
  final Color selectionColor;
  final SelectionChangedCallback? onSelectionChanged;

  @override
  State<MongolSelectableRichText> createState() =>
      _MongolSelectableRichTextState();
}

class _MongolSelectableRichTextState extends State<MongolSelectableRichText> {
  late final _MongolRichTextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _MongolRichTextEditingController(widget.textSpan);
  }

  @override
  void didUpdateWidget(covariant MongolSelectableRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textSpan != widget.textSpan) {
      _controller.richText = widget.textSpan;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MongolSelectableText.rich(
      widget.textSpan,
      controller: _controller,
      textAlign: widget.textAlign,
      style: widget.style,
      textScaleFactor: widget.textScaleFactor,
      maxLines: widget.maxLines,
      softWrap: widget.softWrap,
      overflow: widget.overflow,
      rotateCJK: widget.rotateCJK,
      selectionColor: widget.selectionColor,
      onSelectionChanged: widget.onSelectionChanged,
    );
  }
}

class _MongolRichTextEditingController extends TextEditingController {
  _MongolRichTextEditingController(TextSpan span)
      : _richText = span,
        super(text: span.toPlainText(includeSemanticsLabels: false));

  TextSpan _richText;

  TextSpan get richText => _richText;

  set richText(TextSpan value) {
    _richText = value;
    final String plain = value.toPlainText(includeSemanticsLabels: false);
    final TextSelection current = selection;
    final int base = current.baseOffset.clamp(0, plain.length);
    final int extent = current.extentOffset.clamp(0, plain.length);
    this.value = TextEditingValue(
      text: plain,
      selection: TextSelection(baseOffset: base, extentOffset: extent),
      composing: TextRange.empty,
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return TextSpan(
      style: style,
      children: <InlineSpan>[_richText],
    );
  }
}
