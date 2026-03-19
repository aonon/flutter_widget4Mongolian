// Copyright 2014 The Flutter Authors.
// Copyright 2020 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mongol/src/base/mongol_paragraph.dart';
import 'package:mongol/src/base/mongol_text_align.dart';
import 'package:mongol/src/base/mongol_text_metrics.dart';
import 'package:mongol/src/base/mongol_text_painter.dart';

void main() {
  // Helper to build a laid-out MongolParagraph from plain text
  MongolParagraph buildParagraph(String text, double height) {
    final paragraphStyle = ui.ParagraphStyle();
    final paragraphBuilder = MongolParagraphBuilder(
      paragraphStyle,
      textAlign: MongolTextAlign.top,
    );
    paragraphBuilder.addText(text);
    final paragraph = paragraphBuilder.build();
    paragraph.layout(MongolParagraphConstraints(height: height));
    return paragraph;
  }

  group('CaretMetrics sealed class hierarchy', () {
    test('LineCaretMetrics stores offset and fullWidth', () {
      const metrics = LineCaretMetrics(
        offset: Offset(10.0, 20.0),
        fullWidth: 14.0,
      );
      expect(metrics.offset, const Offset(10.0, 20.0));
      expect(metrics.fullWidth, 14.0);
      expect(metrics, isA<CaretMetrics>());
    });

    test('EmptyLineCaretMetrics stores lineHorizontalOffset', () {
      const metrics = EmptyLineCaretMetrics(lineHorizontalOffset: 5.0);
      expect(metrics.lineHorizontalOffset, 5.0);
      expect(metrics, isA<CaretMetrics>());
    });

    test('pattern matching works on CaretMetrics subtypes', () {
      const CaretMetrics line = LineCaretMetrics(
        offset: Offset(1.0, 2.0),
        fullWidth: 3.0,
      );
      const CaretMetrics empty = EmptyLineCaretMetrics(
        lineHorizontalOffset: 4.0,
      );

      final lineResult = switch (line) {
        LineCaretMetrics(:final double fullWidth) => fullWidth,
        EmptyLineCaretMetrics() => -1.0,
      };
      expect(lineResult, 3.0);

      final emptyResult = switch (empty) {
        LineCaretMetrics() => -1.0,
        EmptyLineCaretMetrics(:final double lineHorizontalOffset) =>
          lineHorizontalOffset,
      };
      expect(emptyResult, 4.0);
    });
  });

  group('CaretMetricsCalculator', () {
    group('basic text', () {
      test('returns LineCaretMetrics for offset 0 of non-empty text', () {
        final calculator = CaretMetricsCalculator();
        const text = TextSpan(text: 'ABC');
        final paragraph = buildParagraph('ABC', 1000);

        final result = calculator.compute(
          const TextPosition(offset: 0),
          'ABC',
          paragraph,
          text,
        );
        expect(result, isA<LineCaretMetrics>());
      });

      test('returns LineCaretMetrics for middle offset', () {
        final calculator = CaretMetricsCalculator();
        const text = TextSpan(text: 'ABC');
        final paragraph = buildParagraph('ABC', 1000);

        final result = calculator.compute(
          const TextPosition(offset: 1),
          'ABC',
          paragraph,
          text,
        );
        expect(result, isA<LineCaretMetrics>());
      });

      test('returns LineCaretMetrics for end of text', () {
        final calculator = CaretMetricsCalculator();
        const text = TextSpan(text: 'ABC');
        final paragraph = buildParagraph('ABC', 1000);

        final result = calculator.compute(
          const TextPosition(offset: 3),
          'ABC',
          paragraph,
          text,
        );
        expect(result, isA<LineCaretMetrics>());
      });

      test('caret y-offset increases with character position', () {
        final calculator = CaretMetricsCalculator();
        const text = TextSpan(text: 'ABCDE');
        final paragraph = buildParagraph('ABCDE', 1000);

        final result0 = calculator.compute(
          const TextPosition(offset: 0),
          'ABCDE',
          paragraph,
          text,
        ) as LineCaretMetrics;

        final result3 = calculator.compute(
          const TextPosition(offset: 3),
          'ABCDE',
          paragraph,
          text,
        ) as LineCaretMetrics;

        expect(result3.offset.dy, greaterThan(result0.offset.dy));
      });
    });

    group('empty text', () {
      test('returns EmptyLineCaretMetrics for empty plainText', () {
        final calculator = CaretMetricsCalculator();
        const text = TextSpan(text: '');
        final paragraph = buildParagraph('', 1000);

        final result = calculator.compute(
          const TextPosition(offset: 0),
          '',
          paragraph,
          text,
        );
        expect(result, isA<EmptyLineCaretMetrics>());
      });
    });

    group('newline handling', () {
      test('returns valid CaretMetrics when caret is after trailing newline', () {
        final calculator = CaretMetricsCalculator();
        const text = TextSpan(text: 'A\n');
        final paragraph = buildParagraph('A\n', 1000);

        // offset 2 is after the newline
        final result = calculator.compute(
          const TextPosition(offset: 2),
          'A\n',
          paragraph,
          text,
        );
        expect(result, isA<CaretMetrics>());
      });

      test('returns LineCaretMetrics before newline character', () {
        final calculator = CaretMetricsCalculator();
        const text = TextSpan(text: 'A\nB');
        final paragraph = buildParagraph('A\nB', 1000);

        // offset 0 is before 'A'
        final result = calculator.compute(
          const TextPosition(offset: 0),
          'A\nB',
          paragraph,
          text,
        );
        expect(result, isA<LineCaretMetrics>());
      });

      test('handles multiple consecutive newlines', () {
        final calculator = CaretMetricsCalculator();
        const plainText = '\n\n';
        const text = TextSpan(text: plainText);
        final paragraph = buildParagraph(plainText, 1000);

        // Between the two newlines
        final result = calculator.compute(
          const TextPosition(offset: 1),
          plainText,
          paragraph,
          text,
        );
        // Valid caret metrics are returned
        expect(result, isA<CaretMetrics>());
      });

      test('caret at start of text with leading newline', () {
        final calculator = CaretMetricsCalculator();
        const plainText = '\nABC';
        const text = TextSpan(text: plainText);
        final paragraph = buildParagraph(plainText, 1000);

        final result = calculator.compute(
          const TextPosition(offset: 0),
          plainText,
          paragraph,
          text,
        );
        // Before newline, using downstream
        expect(result, isA<CaretMetrics>());
      });
    });

    group('caching', () {
      test('returns same result for repeated same position', () {
        final calculator = CaretMetricsCalculator();
        const text = TextSpan(text: 'ABC');
        final paragraph = buildParagraph('ABC', 1000);
        const position = TextPosition(offset: 1);

        final result1 = calculator.compute(position, 'ABC', paragraph, text);
        final result2 = calculator.compute(position, 'ABC', paragraph, text);

        // Should return cached (identical) result
        expect(identical(result1, result2), isTrue);
      });

      test('returns different result for different positions', () {
        final calculator = CaretMetricsCalculator();
        const text = TextSpan(text: 'ABCDE');
        final paragraph = buildParagraph('ABCDE', 1000);

        final result0 = calculator.compute(
          const TextPosition(offset: 0),
          'ABCDE',
          paragraph,
          text,
        );

        final result3 = calculator.compute(
          const TextPosition(offset: 3),
          'ABCDE',
          paragraph,
          text,
        );

        // Different positions should yield different metrics
        expect(identical(result0, result3), isFalse);
      });
    });

    group('affinity', () {
      test('upstream and downstream produce results for valid position', () {
        final calculator1 = CaretMetricsCalculator();
        final calculator2 = CaretMetricsCalculator();
        const text = TextSpan(text: 'ABCDE');
        final paragraph = buildParagraph('ABCDE', 1000);

        final upstream = calculator1.compute(
          const TextPosition(offset: 2, affinity: TextAffinity.upstream),
          'ABCDE',
          paragraph,
          text,
        );

        final downstream = calculator2.compute(
          const TextPosition(offset: 2, affinity: TextAffinity.downstream),
          'ABCDE',
          paragraph,
          text,
        );

        // Both should produce valid metrics
        expect(upstream, isA<CaretMetrics>());
        expect(downstream, isA<CaretMetrics>());
      });
    });

    group('surrogate pairs', () {
      test('handles surrogate pair characters', () {
        final calculator = CaretMetricsCalculator();
        const plainText = 'A\u{1F600}B'; // A + emoji + B
        const text = TextSpan(text: plainText);
        final paragraph = buildParagraph(plainText, 1000);

        // Before the emoji (offset 1)
        final result1 = calculator.compute(
          const TextPosition(offset: 1),
          plainText,
          paragraph,
          text,
        );
        expect(result1, isA<CaretMetrics>());

        // After the emoji (offset 3, since emoji is 2 code units)
        final result3 = calculator.compute(
          const TextPosition(offset: 3),
          plainText,
          paragraph,
          text,
        );
        expect(result3, isA<CaretMetrics>());
      });
    });

    group('offset out of range', () {
      test('returns EmptyLineCaretMetrics for offset beyond text length', () {
        final calculator = CaretMetricsCalculator();
        const text = TextSpan(text: 'AB');
        final paragraph = buildParagraph('AB', 1000);

        // offset 10 is way beyond text length of 2
        final result = calculator.compute(
          const TextPosition(offset: 10),
          'AB',
          paragraph,
          text,
        );
        // Both upstream and downstream should fail, yielding empty
        expect(result, isA<EmptyLineCaretMetrics>());
      });
    });

    group('integration with MongolTextPainter', () {
      test('getOffsetForCaret uses CaretMetricsCalculator correctly', () {
        final painter = MongolTextPainter(
          text: const TextSpan(text: 'ABC'),
        );
        painter.layout();

        // Should not throw and should return valid offset
        final offset = painter.getOffsetForCaret(
          const TextPosition(offset: 0),
          Rect.zero,
        );
        expect(offset.dy, 0.0);
      });

      test('getOffsetForCaret caret position increases with offset', () {
        final painter = MongolTextPainter(
          text: const TextSpan(text: 'ABCDE'),
        );
        painter.layout();

        final offset0 = painter.getOffsetForCaret(
          const TextPosition(offset: 0),
          Rect.zero,
        );
        final offset5 = painter.getOffsetForCaret(
          const TextPosition(offset: 5),
          Rect.zero,
        );
        expect(offset5.dy, greaterThan(offset0.dy));
      });

      test('getOffsetForCaret returns 0 offset for negative position', () {
        final painter = MongolTextPainter(
          text: const TextSpan(text: 'ABC'),
        );
        painter.layout();

        final offset = painter.getOffsetForCaret(
          const TextPosition(offset: -1),
          Rect.zero,
        );
        expect(offset.dx, 0.0);
      });

      test('getFullWidthForCaret returns null for negative position', () {
        final painter = MongolTextPainter(
          text: const TextSpan(text: 'ABC'),
        );
        painter.layout();

        final width = painter.getFullWidthForCaret(
          const TextPosition(offset: -1),
          Rect.zero,
        );
        expect(width, isNull);
      });

      test('getFullWidthForCaret returns non-null for valid position', () {
        final painter = MongolTextPainter(
          text: const TextSpan(text: 'A'),
        );
        painter.layout();

        final width = painter.getFullWidthForCaret(
          const TextPosition(offset: 0),
          Rect.zero,
        );
        expect(width, isNotNull);
        expect(width, greaterThan(0));
      });

      test('getFullWidthForCaret returns value after trailing newline', () {
        final painter = MongolTextPainter(
          text: const TextSpan(text: 'A\n'),
        );
        painter.layout();

        // offset 2 = after the newline
        final width = painter.getFullWidthForCaret(
          const TextPosition(offset: 2),
          Rect.zero,
        );
        // The downstream search finds the newline glyph, so width is not null
        expect(width, isNotNull);
      });

      test('handles newline-only text properly', () {
        final painter = MongolTextPainter(
          text: const TextSpan(text: '\n'),
        );
        painter.layout();

        // At offset 0, before the newline
        final offset0 = painter.getOffsetForCaret(
          const TextPosition(offset: 0),
          Rect.zero,
        );
        expect(offset0, isNotNull);

        // At offset 1, after the newline = empty second line
        final offset1 = painter.getOffsetForCaret(
          const TextPosition(offset: 1),
          Rect.zero,
        );
        expect(offset1, isNotNull);
      });
    });
  });
}
