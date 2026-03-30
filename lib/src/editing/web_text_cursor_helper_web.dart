// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

bool _injected = false;
const String _styleId = 'mongol-vertical-text-cursor-style';

/// Injects a CSS rule so that Flutter Web's hidden text-editing textarea
/// uses `cursor: vertical-text` instead of the browser default `cursor: text`.
void injectVerticalTextCursorStyle() {
  if (_injected) return;
  if (html.document.getElementById(_styleId) != null) {
    _injected = true;
    return;
  }

  final style = html.StyleElement()
    ..id = _styleId
    ..text = 'flt-text-editing-host textarea,'
        ' flt-text-editing-host input'
        ' { cursor: vertical-text !important; }';
  html.document.head?.append(style);
  _injected = true;
}
