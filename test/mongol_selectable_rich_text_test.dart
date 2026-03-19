import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mongol/mongol.dart';

void main() {
  group('MongolSelectableRichText', () {
    testWidgets('can be instantiated', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MongolSelectableRichText.rich(
              const TextSpan(
                children: <TextSpan>[
                  TextSpan(text: 'ᠨᠢᠭᠡ '),
                  TextSpan(
                    text: 'ᠬᠣᠶᠠᠷ',
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MongolSelectableRichText), findsOneWidget);
    });

    testWidgets('multiple instances can be built',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: <Widget>[
                SizedBox(
                  height: 220,
                  child: MongolSelectableRichText.rich(
                    const TextSpan(text: 'first rich selectable content'),
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  height: 220,
                  child: MongolSelectableRichText.rich(
                    const TextSpan(text: 'second rich selectable content'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(MongolSelectableRichText), findsNWidgets(2));
    });
  });
}
