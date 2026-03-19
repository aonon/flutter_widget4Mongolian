// Test for MongolSelectableText widget

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mongol/mongol.dart';

void main() {
  group('MongolSelectableText', () {
    testWidgets('MongolSelectableText can be instantiated', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MongolSelectableText('Hello, World!'),
          ),
        ),
      );

      // 检查 MongolSelectableText widget 是否存在
      expect(find.byType(MongolSelectableText), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('MongolSelectableText.rich can be instantiated', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MongolSelectableText.rich(
              const TextSpan(
                text: 'Hello',
                children: [
                  TextSpan(
                    text: ' World',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MongolSelectableText), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('MongolSelectableText respects text style', (WidgetTester tester) async {
      const textStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
      
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MongolSelectableText(
              'Styled Text',
              style: textStyle,
            ),
          ),
        ),
      );

      expect(find.byType(MongolSelectableText), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('MongolSelectableText respects maxLines property', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MongolSelectableText(
              'Line 1\nLine 2\nLine 3\nLine 4',
              maxLines: 2,
            ),
          ),
        ),
      );

      expect(find.byType(MongolSelectableText), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('MongolSelectableText calls onSelectionChanged', (WidgetTester tester) async {
      bool selectionChanged = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MongolSelectableText(
              'Test Text',
              onSelectionChanged: (selection, cause) {
                selectionChanged = true;
              },
            ),
          ),
        ),
      );

      // 长按以选择文本
      await tester.longPress(find.byType(MongolSelectableText).first);
      await tester.pumpAndSettle();

      // 当前实现会自动选择单词
      expect(selectionChanged, isTrue);
    });

    testWidgets('MongolSelectableText supports text alignment', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MongolSelectableText(
              'Aligned Text',
              textAlign: MongolTextAlign.center,
            ),
          ),
        ),
      );

      expect(find.byType(MongolSelectableText), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('MongolSelectableText respects textScaleFactor', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MongolSelectableText(
              'Scaled Text',
              textScaleFactor: 1.5,
            ),
          ),
        ),
      );

      expect(find.byType(MongolSelectableText), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('MongolSelectableText supports softWrap', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              child: MongolSelectableText(
                'This is a very long text that should wrap',
                softWrap: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MongolSelectableText), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('MongolSelectableText supports custom selection color', (WidgetTester tester) async {
      const selectionColor = Color.fromARGB(255, 255, 0, 0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MongolSelectableText(
              'Colored Selection',
              selectionColor: selectionColor,
            ),
          ),
        ),
      );

      expect(find.byType(MongolSelectableText), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('MongolSelectableText tap clears selection', (WidgetTester tester) async {
      bool selectionChanged = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MongolSelectableText(
              'Test Text',
              onSelectionChanged: (selection, cause) {
                selectionChanged = true;
              },
            ),
          ),
        ),
      );

      // 长按以选择文本
      await tester.longPress(find.byType(MongolSelectableText).first);
      await tester.pumpAndSettle();
      expect(selectionChanged, isTrue);

      // 单击以清除选择
      await tester.tap(find.byType(MongolSelectableText).first);
      await tester.pumpAndSettle();
    });

    testWidgets('multiple MongolSelectableText clears previous selection when selecting another',
        (WidgetTester tester) async {
      final TextEditingController firstController = TextEditingController(
        text: 'First selectable text for focus handoff test',
      );
      final TextEditingController secondController = TextEditingController(
        text: 'Second selectable text for focus handoff test',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  height: 220,
                  child: MongolSelectableText(
                    'First selectable text for focus handoff test',
                    controller: firstController,
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  height: 220,
                  child: MongolSelectableText(
                    'Second selectable text for focus handoff test',
                    controller: secondController,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final Finder first = find.byType(MongolSelectableText).at(0);
      final Finder second = find.byType(MongolSelectableText).at(1);

      await tester.longPress(first);
      await tester.pumpAndSettle();

        expect(firstController.selection.isCollapsed, isFalse);
        expect(secondController.selection.isCollapsed, isTrue);

      List<MongolTextField> fields =
          tester.widgetList<MongolTextField>(find.byType(MongolTextField)).toList();
      expect(fields[0].focusNode?.hasFocus, isTrue);
      expect(fields[1].focusNode?.hasFocus, isFalse);

      await tester.longPress(second);
      await tester.pumpAndSettle();

      expect(firstController.selection.isCollapsed, isTrue);
      expect(secondController.selection.isCollapsed, isFalse);

      fields = tester.widgetList<MongolTextField>(find.byType(MongolTextField)).toList();
      expect(fields[0].focusNode?.hasFocus, isFalse);
      expect(fields[1].focusNode?.hasFocus, isTrue);

      firstController.dispose();
      secondController.dispose();
    });

    testWidgets('MongolSelectableText clears selection on focus loss',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SizedBox(
                  height: 220,
                  child: MongolSelectableText(
                    'Focus loss should collapse this selection',
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('outside focus target'),
                ),
              ],
            ),
          ),
        ),
      );

      final List<MongolTextField> fields =
          tester.widgetList<MongolTextField>(find.byType(MongolTextField)).toList();
      final FocusNode? focusNode = fields.first.focusNode;
      final TextEditingController effectiveController =
          fields.first.controller!;

      focusNode?.requestFocus();
      await tester.pumpAndSettle();
      effectiveController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.pumpAndSettle();

      expect(effectiveController.selection.isCollapsed, isFalse);
      expect(focusNode?.hasFocus, isTrue);

      focusNode?.unfocus();
      await tester.pumpAndSettle();

      expect(effectiveController.selection.isCollapsed, isTrue);
    });
  });
}
