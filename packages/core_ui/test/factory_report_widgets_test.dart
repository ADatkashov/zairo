import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: factoryLightTheme(),
  home: Scaffold(body: SingleChildScrollView(child: Center(child: SizedBox(width: 360, child: child)))),
);

void main() {
  group('FactoryDonutChart', () {
    testWidgets('shows the total in the ring and a legend row per positive slice', (tester) async {
      await tester.pumpWidget(
        _wrap(
        const FactoryDonutChart(
          centerLabel: '125 000',
          centerCaption: 'Revenue',
          segments: [
            FactoryChartSegment(label: 'Haircut', value: 80, valueLabel: '80 000'),
            FactoryChartSegment(label: 'Colour', value: 45, valueLabel: '45 000'),
            FactoryChartSegment(label: 'Refunded', value: 0, valueLabel: '0'),
          ],
        ),
        ),
      );

      expect(find.text('125 000'), findsOneWidget);
      expect(find.text('Revenue'), findsOneWidget);
      expect(find.text('Haircut'), findsOneWidget);
      expect(find.text('80 000'), findsOneWidget);
      expect(find.text('Colour'), findsOneWidget);
      expect(find.text('Refunded'), findsNothing);
    });

    testWidgets('with nothing to draw it still renders an empty track', (tester) async {
      await tester.pumpWidget(_wrap(const FactoryDonutChart(centerLabel: '0', segments: [])));

      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stacked puts the legend under the ring and does not overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FactoryDonutChart(
            centerLabel: '10',
            stacked: true,
            segments: [FactoryChartSegment(label: 'Only', value: 10, valueLabel: '10', color: Colors.teal)],
          ),
        ),
      );

      expect(find.text('Only'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FactoryFilterPanel', () {
    testWidgets('shows its title and fields, and Reset only when wired', (tester) async {
      await tester.pumpWidget(
        _wrap(const FactoryFilterPanel(title: 'Filters', children: [FactoryFilterField(label: 'Period', child: Text('Month'))])),
      );

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Period'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('Reset calls back', (tester) async {
      var resets = 0;
      await tester.pumpWidget(
        _wrap(FactoryFilterPanel(title: 'Filters', resetLabel: 'Reset', onReset: () => resets++, children: const [])),
      );

      await tester.tap(find.text('Reset'));

      expect(resets, 1);
    });
  });
}
