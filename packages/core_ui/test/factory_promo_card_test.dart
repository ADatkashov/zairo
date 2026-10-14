import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {double width = 400}) => MaterialApp(
  theme: factoryLightTheme(),
  home: Scaffold(
    body: Center(child: SizedBox(width: width, child: child)),
  ),
);

void main() {
  group('FactoryPromoCard', () {
    testWidgets('renders title and subtitle and reacts to a tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          FactoryPromoCard(
            title: 'Earn rewards',
            subtitle: 'Every visit counts',
            icon: Icons.redeem_rounded,
            width: 240,
            onTap: () => taps++,
          ),
        ),
      );

      expect(find.text('Earn rewards'), findsOneWidget);
      expect(find.text('Every visit counts'), findsOneWidget);
      expect(find.byIcon(Icons.redeem_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.tap(find.text('Earn rewards'));
      expect(taps, 1);
    });

    testWidgets('omits the subtitle and icon when not given', (tester) async {
      await tester.pumpWidget(_wrap(const FactoryPromoCard(title: 'Just a title', width: 240)));

      expect(find.text('Just a title'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('the close button dismisses without triggering the card tap', (tester) async {
      var taps = 0;
      var dismissed = 0;
      await tester.pumpWidget(
        _wrap(
          FactoryPromoCard(
            title: 'What is this?',
            width: 240,
            onTap: () => taps++,
            onDismiss: () => dismissed++,
            dismissTooltip: 'Close',
          ),
        ),
      );

      await tester.tap(find.byTooltip('Close'));
      expect(dismissed, 1);
      expect(taps, 0);
    });
  });
}
