import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mongol/src/base/mongol_paragraph.dart';
import 'package:mongol/src/base/mongol_text_align.dart';

MongolParagraph _getParagraph(String text, double height) {
  final paragraphStyle = ui.ParagraphStyle();
  final paragraphBuilder = MongolParagraphBuilder(
    paragraphStyle,
    textAlign: MongolTextAlign.top,
    maxLines: null,
  );
  paragraphBuilder.addText(text);
  final constraints = MongolParagraphConstraints(height: height);
  final paragraph = paragraphBuilder.build();
  paragraph.layout(constraints);
  return paragraph;
}

void main() {
  test('does not split long word without breaks', () {
    // A long 'word' without spaces should not be split across runs
    // when individual graphemes fit within the max line length.
    const word = 'AAAAAAAAAAAAAAAAAAAA';
    // Choose a small height so total run width > height, but each grapheme
    // is smaller than height (typical glyph height ~14 in this test env).
    final paragraph = _getParagraph(word, 14.0);

    final boxes = paragraph.getBoxesForRange(0, word.length);
    // Expect a single bounding box for the whole run (no split).
    expect(boxes.length, 1);
  });

  test('forces split when single grapheme exceeds max line length', () {
    // Use a character that typically has larger intrinsic width (emoji/CJK).
    const wide = '\u{1F4A9}'; // emoji (pile of poo) — typically wide
    const text = '$wide$wide$wide$wide';

    // Use very small height to force condition where a single grapheme
    // is wider than maxLineLength and therefore must be split.
    final paragraph = _getParagraph(text, 2.0);

    final boxes = paragraph.getBoxesForRange(0, text.length);
    // Expect multiple boxes because graphemes were forced to split.
    expect(boxes.length, greaterThan(1));
  });
}
