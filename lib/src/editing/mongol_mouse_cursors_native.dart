// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Returns the appropriate [MouseCursor] for vertical Mongolian text.
///
/// On Windows, the Flutter engine does not map `SystemMouseCursors.verticalText`
/// to a system cursor (falls back to arrow). This getter returns a custom
/// [MouseCursor] that creates a horizontal I-beam via the platform channel.
///
/// On macOS and Linux, [SystemMouseCursors.verticalText] is used directly.
MouseCursor get mongolVerticalTextCursor {
  if (Platform.isWindows) {
    return const _WindowsVerticalTextCursor();
  }
  return SystemMouseCursors.verticalText;
}

/// A custom [MouseCursor] that displays a horizontal I-beam on Windows
/// by using the `createCustomCursor/windows` platform channel.
class _WindowsVerticalTextCursor extends MouseCursor {
  const _WindowsVerticalTextCursor();

  static const String _name = 'mongol_vertical_text_ibeam';
  static bool _registered = false;
  static Future<void>? _registering;
  static Uint8List? _cachedBitmap;

  @override
  String get debugDescription => 'WindowsVerticalTextCursor()';

  @override
  MouseCursorSession createSession(int device) =>
      _WindowsVerticalTextCursorSession(this, device);

  /// Registers the custom cursor bitmap with the Windows platform once.
  static Future<void> _ensureRegistered() async {
    if (_registered) {
      return;
    }
    final Future<void>? inFlight = _registering;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    _registering = () async {
      final Uint8List bitmap = _cachedBitmap ??= _createHorizontalIBeamBitmap();
      try {
        await SystemChannels.mouseCursor.invokeMethod<String>(
          'createCustomCursor/windows',
          <String, dynamic>{
            'name': _name,
            'buffer': bitmap,
            'width': _kSize,
            'height': _kSize,
            'hotX': _kSize / 2.0,
            'hotY': _kSize / 2.0,
          },
        );
        _registered = true;
      } catch (_) {
        // If custom cursor creation fails (e.g. headless mode), silently
        // fall back; the system arrow cursor will be used instead.
      } finally {
        _registering = null;
      }
    }();

    await _registering;
  }

  // ---- Cursor bitmap generation ----

  static const int _kSize = 32;

  /// Creates a 32×32 BGRA bitmap of a horizontal I-beam cursor.
  ///
  /// The shape is a horizontal bar with short vertical serifs at each end,
  /// like a standard I-beam rotated 90°:
  /// ```
  ///   |               |
  ///   |               |
  ///   |───────────────|
  ///   |               |
  ///   |               |
  /// ```
  static Uint8List _createHorizontalIBeamBitmap() {
    final pixels = Uint8List(_kSize * _kSize * 4);

    // Define black pixels for the cursor shape.
    final blackPixels = <int>{};

    // Horizontal main bar: y=16, x=7..24
    for (int x = 7; x <= 24; x++) {
      blackPixels.add(16 * _kSize + x);
    }
    // Left serif: x=7, y=13..19
    for (int y = 13; y <= 19; y++) {
      blackPixels.add(y * _kSize + 7);
    }
    // Right serif: x=24, y=13..19
    for (int y = 13; y <= 19; y++) {
      blackPixels.add(y * _kSize + 24);
    }

    // Compute 1-pixel white outline around all black pixels.
    final whitePixels = <int>{};
    for (final idx in blackPixels) {
      final int cy = idx ~/ _kSize;
      final int cx = idx % _kSize;
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          final int nx = cx + dx;
          final int ny = cy + dy;
          if (nx >= 0 && nx < _kSize && ny >= 0 && ny < _kSize) {
            final int nIdx = ny * _kSize + nx;
            if (!blackPixels.contains(nIdx)) {
              whitePixels.add(nIdx);
            }
          }
        }
      }
    }

    // Fill white outline (BGRA).
    for (final idx in whitePixels) {
      final int off = idx * 4;
      pixels[off] = 255;
      pixels[off + 1] = 255;
      pixels[off + 2] = 255;
      pixels[off + 3] = 255;
    }
    // Fill black cursor body (BGRA).
    for (final idx in blackPixels) {
      final int off = idx * 4;
      pixels[off] = 0;
      pixels[off + 1] = 0;
      pixels[off + 2] = 0;
      pixels[off + 3] = 255;
    }

    return pixels;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _WindowsVerticalTextCursor;

  @override
  int get hashCode => runtimeType.hashCode;
}

class _WindowsVerticalTextCursorSession extends MouseCursorSession {
  _WindowsVerticalTextCursorSession(super.cursor, super.device);

  @override
  Future<void> activate() async {
    await _WindowsVerticalTextCursor._ensureRegistered();
    if (!_WindowsVerticalTextCursor._registered) {
      // Fallback: if custom cursor creation failed, use system text cursor.
      await SystemChannels.mouseCursor.invokeMethod<void>(
        'activateSystemCursor',
        <String, dynamic>{'device': device, 'kind': 'text'},
      );
      return;
    }
    await SystemChannels.mouseCursor.invokeMethod<void>(
      'setCustomCursor/windows',
      <String, dynamic>{'name': _WindowsVerticalTextCursor._name},
    );
  }

  @override
  void dispose() {
    // The custom cursor stays registered for the app's lifetime.
  }
}
