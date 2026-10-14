import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: factoryLightTheme(),
  home: Scaffold(body: Center(child: SizedBox(width: 200, child: child))),
);

void main() {
  group('FactoryKpiCard', () {
    testWidgets('shows only the label and value when there is no history', (tester) async {
      await tester.pumpWidget(_wrap(const FactoryKpiCard(label: 'Bookings', value: '128')));

      expect(find.text('Bookings'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      expect(find.byType(FactoryTrendBadge), findsNothing);
      expect(find.byType(FactorySparkline), findsNothing);
    });

    testWidgets('shows the change chip and the trend line when given', (tester) async {
      await tester.pumpWidget(
        _wrap(const FactoryKpiCard(label: 'Revenue', value: '7 450 000', delta: 23, trend: [1, 3, 2, 5])),
      );

      expect(find.byType(FactoryTrendBadge), findsOneWidget);
      expect(find.byType(FactorySparkline), findsOneWidget);
    });

    testWidgets('a trend with fewer than two points is skipped', (tester) async {
      await tester.pumpWidget(_wrap(const FactoryKpiCard(label: 'Revenue', value: '1', trend: [4])));

      expect(find.byType(FactorySparkline), findsNothing);
    });

    testWidgets('warn paints the value in the error colour', (tester) async {
      await tester.pumpWidget(_wrap(const FactoryKpiCard(label: 'Failed', value: '3', warn: true)));

      final value = tester.widget<Text>(find.text('3'));
      expect(value.style?.color, FactoryColors.light.error);
    });

    testWidgets('onTap turns the card into a link; without it nothing reacts', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(FactoryKpiCard(label: 'Pending', value: '3', onTap: () => taps++)));
      await tester.tap(find.text('Pending'));
      expect(taps, 1);

      await tester.pumpWidget(_wrap(const FactoryKpiCard(label: 'Pending', value: '3')));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('renders the icon when given', (tester) async {
      await tester.pumpWidget(_wrap(const FactoryKpiCard(label: 'Leads', value: '9', icon: Icons.person_rounded)));

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });
  });

  group('FactoryBadge showDot', () {
    testWidgets('draws a leading dot only when asked', (tester) async {
      await tester.pumpWidget(_wrap(const FactoryBadge(label: 'Active')));
      final withoutDot = find.descendant(of: find.byType(FactoryBadge), matching: find.byType(DecoratedBox)).evaluate().length;

      await tester.pumpWidget(_wrap(const FactoryBadge(label: 'Active', showDot: true)));
      final withDot = find.descendant(of: find.byType(FactoryBadge), matching: find.byType(DecoratedBox)).evaluate().length;

      expect(withDot, withoutDot + 1);
    });
  });
}
