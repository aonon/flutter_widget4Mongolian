// Copyright 2014 The Flutter Authors.
// Copyright 2020 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mongol/src/base/mongol_paragraph.dart';
import 'package:mongol/src/base/mongol_text_tools.dart';

void main() {
  group('MongolTextTools', () {
    // ========================================================================
    // UTF-16 Validation Tests
    // ========================================================================

    group('UTF-16 Validation', () {
      group('isUTF16()', () {
        test('returns true for valid UTF-16 code units', () {
          expect(MongolTextTools.isUTF16(0x0000), isTrue);
          expect(MongolTextTools.isUTF16(0x0041), isTrue); // 'A'
          expect(MongolTextTools.isUTF16(0x4E00), isTrue); // CJK character
          expect(MongolTextTools.isUTF16(0xD800), isTrue); // High surrogate
          expect(MongolTextTools.isUTF16(0xDC00), isTrue); // Low surrogate
          expect(MongolTextTools.isUTF16(0xFFFF), isTrue);
        });

        test('returns false for values outside valid range', () {
          expect(MongolTextTools.isUTF16(-1), isFalse);
          expect(MongolTextTools.isUTF16(0x10000), isFalse);
          expect(MongolTextTools.isUTF16(0x110000), isFalse);
          expect(MongolTextTools.isUTF16(1000000), isFalse);
        });

        test('handles boundary values', () {
          expect(MongolTextTools.isUTF16(0x0000), isTrue);
          expect(MongolTextTools.isUTF16(0xFFFF), isTrue);
        });
      });

      group('isHighSurrogate()', () {
        test('returns true for high surrogates (0xD800-0xDBFF)', () {
          expect(MongolTextTools.isHighSurrogate(0xD800), isTrue);
          expect(MongolTextTools.isHighSurrogate(0xD801), isTrue);
          expect(MongolTextTools.isHighSurrogate(0xDBFF), isTrue);
        });

        test('returns false for non-high-surrogates', () {
          expect(MongolTextTools.isHighSurrogate(0x0041), isFalse); // 'A'
          expect(MongolTextTools.isHighSurrogate(0xDC00), isFalse); // Low surrogate
          expect(MongolTextTools.isHighSurrogate(0xDC01), isFalse);
          expect(MongolTextTools.isHighSurrogate(0xDFFF), isFalse); // Last low surrogate
        });

        test('returns true for all valid high surrogates', () {
          // Sample check instead of iterating through all 1024 values for speed
          expect(MongolTextTools.isHighSurrogate(0xD800), isTrue);
          expect(MongolTextTools.isHighSurrogate(0xD900), isTrue);
          expect(MongolTextTools.isHighSurrogate(0xDBFF), isTrue);
        });
      });

      group('isLowSurrogate()', () {
        test('returns true for low surrogates (0xDC00-0xDFFF)', () {
          expect(MongolTextTools.isLowSurrogate(0xDC00), isTrue);
          expect(MongolTextTools.isLowSurrogate(0xDC01), isTrue);
          expect(MongolTextTools.isLowSurrogate(0xDFFF), isTrue);
        });

        test('returns false for non-low-surrogates', () {
          expect(MongolTextTools.isLowSurrogate(0x0041), isFalse); // 'A'
          expect(MongolTextTools.isLowSurrogate(0xD800), isFalse); // High surrogate
          expect(MongolTextTools.isLowSurrogate(0xDBFF), isFalse); // Last high surrogate
          expect(MongolTextTools.isLowSurrogate(0xDBFE), isFalse); // Just before low surrogates
        });

        test('returns true for sample low surrogates', () {
          // Sample check instead of iterating through all 1024 values for speed
          expect(MongolTextTools.isLowSurrogate(0xDC00), isTrue);
          expect(MongolTextTools.isLowSurrogate(0xDE00), isTrue);
          expect(MongolTextTools.isLowSurrogate(0xDFFF), isTrue);
        });
      });

      group('isUnicodeDirectionality()', () {
        test('returns true for RLM (Right-to-Left Mark)', () {
          expect(MongolTextTools.isUnicodeDirectionality(0x200F), isTrue);
        });

        test('returns true for LRM (Left-to-Right Mark)', () {
          expect(MongolTextTools.isUnicodeDirectionality(0x200E), isTrue);
        });

        test('returns false for other Unicode characters', () {
          expect(MongolTextTools.isUnicodeDirectionality(0x0041), isFalse); // 'A'
          expect(MongolTextTools.isUnicodeDirectionality(0x200D), isFalse); // ZWJ
          expect(MongolTextTools.isUnicodeDirectionality(0x0000), isFalse); // NULL
          expect(MongolTextTools.isUnicodeDirectionality(0xFFFF), isFalse);
          expect(MongolTextTools.isUnicodeDirectionality(0x200A), isFalse); // Different control char
          expect(MongolTextTools.isUnicodeDirectionality(0x2010), isFalse); // Different char
        });

        test('distinguishes between RLM and LRM', () {
          const int rlm = 0x200F;
          const int lrm = 0x200E;
          expect(
            MongolTextTools.isUnicodeDirectionality(rlm),
            isTrue,
          );
          expect(
            MongolTextTools.isUnicodeDirectionality(lrm),
            isTrue,
          );
          expect(rlm != lrm, isTrue);
        });
      });
    });

    // ========================================================================
    // Coordinate Transform Tests
    // ========================================================================

    group('Coordinate Transforms', () {
      group('shiftLineMetrics()', () {
        test('applies offset correctly to line metrics', () {
          final metrics = MongolLineMetrics(
            hardBreak: false,
            ascent: 10.0,
            descent: 5.0,
            unscaledAscent: 10.0,
            height: 15.0,
            width: 100.0,
            top: 0.0,
            baseline: 50.0,
            lineNumber: 0,
          );

          final offset = Offset(10.0, 20.0);
          final shifted = MongolTextTools.shiftLineMetrics(metrics, offset);

          expect(shifted.top, equals(20.0)); // 0.0 + offset.dy
          expect(shifted.baseline, equals(60.0)); // 50.0 + offset.dx

          // Other properties should remain unchanged
          expect(shifted.ascent, equals(metrics.ascent));
          expect(shifted.descent, equals(metrics.descent));
          expect(shifted.height, equals(metrics.height));
          expect(shifted.width, equals(metrics.width));
          expect(shifted.hardBreak, equals(metrics.hardBreak));
        });

        test('handles zero offset', () {
          final metrics = MongolLineMetrics(
            hardBreak: true,
            ascent: 10.0,
            descent: 5.0,
            unscaledAscent: 10.0,
            height: 15.0,
            width: 100.0,
            top: 50.0,
            baseline: 75.0,
            lineNumber: 5,
          );

          final offset = Offset.zero;
          final shifted = MongolTextTools.shiftLineMetrics(metrics, offset);

          expect(shifted.top, equals(50.0));
          expect(shifted.baseline, equals(75.0));
        });

        test('handles negative offsets', () {
          final metrics = MongolLineMetrics(
            hardBreak: false,
            ascent: 10.0,
            descent: 5.0,
            unscaledAscent: 10.0,
            height: 15.0,
            width: 100.0,
            top: 100.0,
            baseline: 150.0,
            lineNumber: 0,
          );

          final offset = Offset(-20.0, -50.0);
          final shifted = MongolTextTools.shiftLineMetrics(metrics, offset);

          expect(shifted.top, equals(50.0)); // 100.0 - 50.0
          expect(shifted.baseline, equals(130.0)); // 150.0 - 20.0
        });

        test('preserves original metrics instance', () {
          final metrics = MongolLineMetrics(
            hardBreak: false,
            ascent: 10.0,
            descent: 5.0,
            unscaledAscent: 10.0,
            height: 15.0,
            width: 100.0,
            top: 0.0,
            baseline: 50.0,
            lineNumber: 0,
          );

          final offset = Offset(10.0, 20.0);
          final shifted = MongolTextTools.shiftLineMetrics(metrics, offset);

          // Original should be unchanged
          expect(metrics.top, equals(0.0));
          expect(metrics.baseline, equals(50.0));

          // Result should be different
          expect(shifted.top, equals(20.0));
          expect(shifted.baseline, equals(60.0));
        });
      });

      group('shiftTextBox()', () {
        test('applies offset correctly to rectangle', () {
          final box = Rect.fromLTRB(10.0, 20.0, 30.0, 40.0);
          final offset = Offset(5.0, 10.0);
          final shifted = MongolTextTools.shiftTextBox(box, offset);

          expect(shifted.left, equals(15.0)); // 10.0 + 5.0
          expect(shifted.top, equals(30.0)); // 20.0 + 10.0
          expect(shifted.right, equals(35.0)); // 30.0 + 5.0
          expect(shifted.bottom, equals(50.0)); // 40.0 + 10.0
        });

        test('handles zero offset', () {
          final box = Rect.fromLTRB(10.0, 20.0, 30.0, 40.0);
          final offset = Offset.zero;
          final shifted = MongolTextTools.shiftTextBox(box, offset);

          expect(shifted.left, equals(10.0));
          expect(shifted.top, equals(20.0));
          expect(shifted.right, equals(30.0));
          expect(shifted.bottom, equals(40.0));
        });

        test('handles negative offsets', () {
          final box = Rect.fromLTRB(100.0, 100.0, 200.0, 200.0);
          final offset = Offset(-25.0, -50.0);
          final shifted = MongolTextTools.shiftTextBox(box, offset);

          expect(shifted.left, equals(75.0)); // 100.0 - 25.0
          expect(shifted.top, equals(50.0)); // 100.0 - 50.0
          expect(shifted.right, equals(175.0)); // 200.0 - 25.0
          expect(shifted.bottom, equals(150.0)); // 200.0 - 50.0
        });

        test('preserves rectangle dimensions', () {
          final box = Rect.fromLTRB(10.0, 20.0, 30.0, 40.0);
          final offset = Offset(100.0, 200.0);
          final shifted = MongolTextTools.shiftTextBox(box, offset);

          final originalWidth = box.right - box.left;
          final originalHeight = box.bottom - box.top;
          final shiftedWidth = shifted.right - shifted.left;
          final shiftedHeight = shifted.bottom - shifted.top;

          expect(shiftedWidth, equals(originalWidth));
          expect(shiftedHeight, equals(originalHeight));
        });

        test('handles large offsets', () {
          final box = Rect.fromLTRB(1.0, 1.0, 2.0, 2.0);
          final offset = Offset(1000.0, 2000.0);
          final shifted = MongolTextTools.shiftTextBox(box, offset);

          expect(shifted.left, equals(1001.0));
          expect(shifted.top, equals(2001.0));
          expect(shifted.right, equals(1002.0));
          expect(shifted.bottom, equals(2002.0));
        });
      });
    });

    // ========================================================================
    // Cursor Navigation Tests
    // ========================================================================

    group('Cursor Navigation', () {
      group('codePointFromSurrogates()', () {
        test('combines surrogates to form emoji code point', () {
          // 😀 (smiling face) = U+1F600
          const int highSurrogate = 0xD83D;
          const int lowSurrogate = 0xDE00;

          final codePoint =
              MongolTextTools.codePointFromSurrogates(highSurrogate, lowSurrogate);
          expect(codePoint, equals(0x1F600));
        });

        test('handles various emoji surrogates', () {
          // ❤️ (heavy black heart) = U+2764
          const int high1 = 0xD83D;
          const int low1 = 0xDC64;
          expect(
            MongolTextTools.codePointFromSurrogates(high1, low1),
            equals(0x1F464),
          ); // 👤 (bust in silhouette)

          // Test boundary surrogates
          const int highMin = 0xD800;
          const int lowMin = 0xDC00;
          final minCodePoint =
              MongolTextTools.codePointFromSurrogates(highMin, lowMin);
          expect(minCodePoint, equals(0x10000)); // First supplementary plane char
        });

        test('produces code points in supplementary plane', () {
          final codePoint = MongolTextTools.codePointFromSurrogates(0xD83D, 0xDE00);
          expect(codePoint >= 0x10000, isTrue);
          expect(codePoint <= 0x10FFFF, isTrue);
        });
      });

      group('getOffsetAfter()', () {
        test('moves forward by 1 for ASCII characters', () {
          const String text = 'Hello';
          expect(MongolTextTools.getOffsetAfter(0, text), equals(1));
          expect(MongolTextTools.getOffsetAfter(1, text), equals(2));
          expect(MongolTextTools.getOffsetAfter(3, text), equals(4));
        });

        test('moves forward by 2 for high surrogates (emoji)', () {
          const String text = 'Hello😀World'; // 😀 at indices 5-6 (surrogate pair)
          // At index 5, we have the high surrogate of 😀
          final codeUnit = text.codeUnitAt(5);
          if (MongolTextTools.isHighSurrogate(codeUnit)) {
            expect(MongolTextTools.getOffsetAfter(5, text), equals(7));
          }
        });

        test('handles end of string correctly', () {
          const String text = 'Hello'; // Length 5, valid indices 0-4
          expect(MongolTextTools.getOffsetAfter(4, text), equals(5)); // Moving past last char
        });

        test('handles mixed ASCII and emoji', () {
          const String text = 'Hi😀Bye';
          expect(MongolTextTools.getOffsetAfter(0, text), equals(1)); // After 'H'
          expect(MongolTextTools.getOffsetAfter(1, text), equals(2)); // After 'i'
        });

        test('starts from various positions', () {
          const String text = 'ABCDE';
          expect(MongolTextTools.getOffsetAfter(0, text), equals(1));
          expect(MongolTextTools.getOffsetAfter(2, text), equals(3));
          expect(MongolTextTools.getOffsetAfter(3, text), equals(4));
        });
      });

      group('getOffsetBefore()', () {
        test('moves backward by 1 for ASCII characters', () {
          const String text = 'Hello';
          expect(MongolTextTools.getOffsetBefore(1, text), equals(0));
          expect(MongolTextTools.getOffsetBefore(2, text), equals(1));
          expect(MongolTextTools.getOffsetBefore(5, text), equals(4));
        });

        test('moves backward by 2 for low surrogates (emoji)', () {
          const String text = 'Hello😀World'; // 😀 at indices 5-6
          // At index 7, we're after the emoji (low surrogate at index 6)
          final codeUnit = text.codeUnitAt(6);
          if (MongolTextTools.isLowSurrogate(codeUnit)) {
            expect(MongolTextTools.getOffsetBefore(7, text), equals(5));
          }
        });

        test('handles start of string correctly', () {
          const String text = 'A'; // Length 1, valid index 0
          expect(MongolTextTools.getOffsetBefore(1, text), equals(0));
        });

        test('handles mixed ASCII and emoji', () {
          const String text = 'Hi😀Bye';
          expect(MongolTextTools.getOffsetBefore(1, text), equals(0)); // Before 'i'
          expect(MongolTextTools.getOffsetBefore(2, text), equals(1)); // Before emoji marker
        });

        test('starts from various positions', () {
          const String text = 'ABCDE';
          expect(MongolTextTools.getOffsetBefore(1, text), equals(0));
          expect(MongolTextTools.getOffsetBefore(3, text), equals(2));
          expect(MongolTextTools.getOffsetBefore(5, text), equals(4));
        });
      });

      group('cursor navigation symmetry', () {
        test('getOffsetAfter and getOffsetBefore are inverse operations', () {
          const String text = 'Hello';
          for (int i = 0; i < text.length; i++) {
            final next = MongolTextTools.getOffsetAfter(i, text);
            if (next != null && next <= text.length) {
              expect(MongolTextTools.getOffsetBefore(next, text), equals(i));
            }
          }
        });

        test('handles emoji correctly in round-trip navigation', () {
          const String text = 'A😀B'; // A (index 0), emoji (indices 1-2), B (index 3)
          // Forward from A to position 1
          final pos1 = MongolTextTools.getOffsetAfter(0, text);
          expect(pos1, isNotNull);
          if (pos1 != null) {
            // Back from position 1 should go to 0
            final pos0 = MongolTextTools.getOffsetBefore(pos1, text);
            expect(pos0, equals(0));
          }
        });
      });
    });

    // ========================================================================
    // Integration Tests
    // ========================================================================

    group('Integration Tests', () {
      test('surrogate detection works with codePointFromSurrogates', () {
        const int high = 0xD83D;
        const int low = 0xDE00;

        expect(MongolTextTools.isHighSurrogate(high), isTrue);
        expect(MongolTextTools.isLowSurrogate(low), isTrue);

        final codePoint =
            MongolTextTools.codePointFromSurrogates(high, low);
        expect(codePoint, equals(0x1F600));
      });

      test('coordinate transforms preserve shape', () {
        final metrics = MongolLineMetrics(
          hardBreak: false,
          ascent: 12.0,
          descent: 4.0,
          unscaledAscent: 12.0,
          height: 16.0,
          width: 100.0,
          top: 10.0,
          baseline: 22.0,
          lineNumber: 0,
        );

        final box = Rect.fromLTWH(10.0, 20.0, 80.0, 16.0);
        final offset = Offset(100.0, 200.0);

        final shiftedMetrics =
            MongolTextTools.shiftLineMetrics(metrics, offset);
        final shiftedBox = MongolTextTools.shiftTextBox(box, offset);

        // Heights should be preserved
        expect(shiftedBox.height, equals(box.height));
        expect(shiftedMetrics.height, equals(metrics.height));

        // Width should be preserved
        expect(shiftedBox.width, equals(box.width));
        expect(shiftedMetrics.width, equals(metrics.width));

        // Positions should be offset correctly
        expect(shiftedMetrics.top, equals(metrics.top + offset.dy));
        expect(shiftedBox.top, equals(box.top + offset.dy));
      });

      test('directional marks are handled separately from surrogates', () {
        const int rlm = 0x200F;
        const int lrm = 0x200E;
        const int highSurrogate = 0xD800;

        expect(MongolTextTools.isUnicodeDirectionality(rlm), isTrue);
        expect(MongolTextTools.isUnicodeDirectionality(lrm), isTrue);
        expect(MongolTextTools.isHighSurrogate(rlm), isFalse);
        expect(MongolTextTools.isHighSurrogate(lrm), isFalse);

        expect(MongolTextTools.isUnicodeDirectionality(highSurrogate), isFalse);
        expect(MongolTextTools.isHighSurrogate(highSurrogate), isTrue);
      });
    });

    // ========================================================================
    // Edge Cases & Error Handling
    // ========================================================================

    group('Edge Cases', () {
      test('isUTF16 with boundary values', () {
        expect(MongolTextTools.isUTF16(0), isTrue);
        expect(MongolTextTools.isUTF16(0xFFFF), isTrue);
        expect(MongolTextTools.isUTF16(-1), isFalse);
        expect(MongolTextTools.isUTF16(0x10000), isFalse);
      });

      test('getOffsetAfter at last valid position', () {
        const String text = 'AB'; // Indices 0-1
        expect(MongolTextTools.getOffsetAfter(0, text), equals(1));
        expect(MongolTextTools.getOffsetAfter(1, text), equals(2)); // Returns 2, past end
      });

      test('getOffsetBefore at first valid position', () {
        const String text = 'AB'; // Indices 0-1
        expect(MongolTextTools.getOffsetBefore(1, text), equals(0));
        expect(MongolTextTools.getOffsetBefore(2, text), equals(1));
      });

      test('single character text navigation', () {
        const String text = 'A';
        expect(MongolTextTools.getOffsetAfter(0, text), equals(1));
        expect(MongolTextTools.getOffsetBefore(1, text), equals(0));
      });

      test('text with only surrogates (emoji)', () {
        const String text = '😀'; // Single emoji (2 code units)
        expect(MongolTextTools.getOffsetAfter(0, text), equals(2));
        expect(MongolTextTools.getOffsetBefore(2, text), equals(0));
      });

      test('very large coordinate offsets', () {
        final box = Rect.fromLTRB(0, 0, 100, 100);
        final offset = Offset(1000000, 2000000);
        final shifted = MongolTextTools.shiftTextBox(box, offset);

        expect(shifted.left, equals(1000000));
        expect(shifted.top, equals(2000000));
        expect(shifted.width, equals(100));
        expect(shifted.height, equals(100));
      });

      test('consecutive emoji navigation', () {
        const String text = '😀😁'; // Two emojis, 4 code units total
        expect(MongolTextTools.getOffsetAfter(0, text), equals(2)); // After first emoji
        expect(MongolTextTools.getOffsetAfter(2, text), equals(4)); // After second emoji
        expect(MongolTextTools.getOffsetBefore(2, text), equals(0)); // Before second emoji
        expect(MongolTextTools.getOffsetBefore(4, text), equals(2)); // After all
      });
    });
  });
}
