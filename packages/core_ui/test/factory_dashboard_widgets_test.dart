import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {double width = 360, ThemeData? theme}) => MaterialApp(
  theme: theme ?? factoryLightTheme(),
  home: Scaffold(
    body: SingleChildScrollView(child: SizedBox(width: width, child: child)),
  ),
);

void main() {
  _largeFontShareListTest();
  group('FactoryKpiCard (dashboard look)', () {
    testWidgets('caption shows next to the change chip, or alone without one', (tester) async {
      await tester.pumpWidget(
        _wrap(const FactoryKpiCard(label: 'Revenue', value: '1', delta: 5, caption: 'vs prior 7 days')),
      );
      expect(find.text('vs prior 7 days'), findsOneWidget);
      expect(find.byType(FactoryTrendBadge), findsOneWidget);

      await tester.pumpWidget(_wrap(const FactoryKpiCard(label: 'Revenue', value: '1', caption: '2 visits today')));
      expect(find.text('2 visits today'), findsOneWidget);
      expect(find.byType(FactoryTrendBadge), findsNothing);
    });

    testWidgets('accent colours the icon and the trend line', (tester) async {
      const hue = Color(0xFFAA3366);
      await tester.pumpWidget(
        _wrap(
          const FactoryKpiCard(
            label: 'Revenue',
            value: '1',
            icon: Icons.payments_rounded,
            accent: hue,
            trend: [1, 2, 3],
          ),
        ),
      );
      expect(tester.widget<Icon>(find.byIcon(Icons.payments_rounded)).color, hue);
      expect(tester.widget<FactorySparkline>(find.byType(FactorySparkline)).color, hue);
    });

    testWidgets('a long figure shrinks to fit a narrow card instead of overflowing', (tester) async {
      await tester.pumpWidget(
        _wrap(const FactoryKpiCard(label: 'Revenue', value: '123 456 789 012 ₸'), width: 110),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('FactoryAlertPanel', () {
    testWidgets('lists every row with its figure and hint, and the count pill', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FactoryAlertPanel(
            title: 'Needs attention',
            count: 2,
            items: [
              FactoryAlertItem(label: 'Failed refunds', value: r'$870', actionLabel: 'Review', icon: Icons.error_outline, onTap: () {}),
              FactoryAlertItem(label: 'Pending approvals', onTap: () {}),
            ],
          ),
        ),
      );
      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Failed refunds'), findsOneWidget);
      expect(find.text(r'$870'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Pending approvals'), findsOneWidget);
    });

    testWidgets('tapping anywhere on a row runs its callback', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        _wrap(
          FactoryAlertPanel(
            title: 'Needs attention',
            items: [
              FactoryAlertItem(label: 'One', onTap: () => tapped.add('one')),
              FactoryAlertItem(label: 'Two', actionLabel: 'Open', onTap: () => tapped.add('two')),
            ],
          ),
        ),
      );
      await tester.tap(find.text('One'));
      await tester.tap(find.text('Open'));
      expect(tapped, ['one', 'two']);
    });

    testWidgets('without a count there is no pill', (tester) async {
      await tester.pumpWidget(
        _wrap(FactoryAlertPanel(title: 'Needs attention', items: [FactoryAlertItem(label: 'One', onTap: () {})])),
      );
      expect(find.text('1'), findsNothing);
    });

    testWidgets('allClear is a calm one-liner with no rows', (tester) async {
      await tester.pumpWidget(_wrap(const FactoryAlertPanel.allClear(title: 'All clear')));
      expect(find.text('All clear'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('fits a 320 px phone with a large font in the dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: factoryDarkTheme(),
          builder: (context, child) =>
              MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: FactoryAlertPanel(
                  title: 'Needs attention',
                  count: 3,
                  items: [
                    FactoryAlertItem(
                      label: 'Appointments need your decision at a long business name',
                      value: '12 400 ₸',
                      actionLabel: 'Review',
                      icon: Icons.event_busy_rounded,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('FactoryShareList', () {
    testWidgets('shows label, caption, figure and a percentage per row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FactoryShareList(
            items: [
              FactoryShareItem(label: 'Acme', caption: 'Consulting', valueLabel: '6 450 ₸', share: 0.272),
              FactoryShareItem(label: 'Hayes', valueLabel: '5 820 ₸', share: 1),
              FactoryShareItem(label: 'Nobody', valueLabel: '0 ₸', share: 0),
            ],
          ),
        ),
      );
      expect(find.text('Acme'), findsOneWidget);
      expect(find.text('Consulting'), findsOneWidget);
      expect(find.text('6 450 ₸'), findsOneWidget);
      expect(find.text('27.2%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('the bar is as wide as the share, clamped to 0–1', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FactoryShareList(
            items: [
              FactoryShareItem(label: 'Half', valueLabel: '1', share: 0.5),
              FactoryShareItem(label: 'Over', valueLabel: '2', share: 7),
            ],
          ),
        ),
      );
      final factors = tester.widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox)).map((w) => w.widthFactor);
      expect(factors, [0.5, 1.0]);
    });

    testWidgets('a row with onTap is a link; leading and custom colour are drawn', (tester) async {
      var taps = 0;
      const hue = Color(0xFF00AA55);
      await tester.pumpWidget(
        _wrap(
          FactoryShareList(
            items: [
              FactoryShareItem(
                label: 'Acme',
                valueLabel: '1',
                share: 0.4,
                color: hue,
                leading: const Icon(Icons.person_rounded),
                onTap: () => taps++,
              ),
              const FactoryShareItem(label: 'Plain', valueLabel: '2', share: 0.1),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Acme'));
      expect(taps, 1);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);
      final bar = tester.widget<ColoredBox>(
        find.descendant(of: find.byType(FractionallySizedBox).first, matching: find.byType(ColoredBox)),
      );
      expect(bar.color, hue);
    });
  });

  group('FactoryMetricGrid', () {
    test('columnsFor fits as many tiles as the width allows, within the limits', () {
      int cols(double w, {int max = 4}) => FactoryMetricGrid.columnsFor(w, minTileWidth: 150, maxColumns: max, spacing: 12);
      expect(cols(100), 1, reason: 'never fewer than one');
      expect(cols(288), 1);
      expect(cols(312), 2, reason: '2 × 150 + 12 gap');
      expect(cols(474), 3, reason: '3 × 150 + 2 × 12 gap');
      expect(cols(473), 2);
      expect(cols(2000), 4, reason: 'capped at maxColumns');
      expect(cols(2000, max: 3), 3);
    });

    testWidgets('an incomplete last row is widened to fill it', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FactoryMetricGrid(
            children: [for (final n in ['a', 'b', 'c']) SizedBox(key: Key(n), height: 20)],
          ),
          width: 360,
        ),
      );
      expect(tester.getSize(find.byKey(const Key('a'))).width, 174, reason: '(360 − 12) / 2');
      expect(tester.getSize(find.byKey(const Key('b'))).width, 174);
      expect(tester.getSize(find.byKey(const Key('c'))).width, 360, reason: 'a lone last card spans the row');
    });

    testWidgets('equalHeight stretches the cards of a row to the tallest and fills a short last row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FactoryMetricGrid(
            equalHeight: true,
            minTileWidth: 150,
            maxColumns: 2,
            children: [
              const SizedBox(key: Key('short'), height: 20),
              const SizedBox(key: Key('tall'), height: 80),
              Container(key: const Key('alone'), height: 30),
            ],
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('short'))).height, 80, reason: 'stretched to its neighbour');
      expect(tester.getSize(find.byKey(const Key('short'))).width, 174);
      expect(tester.getSize(find.byKey(const Key('alone'))).width, 360, reason: 'a lone last card spans the row');
      expect(tester.getTopLeft(find.byKey(const Key('alone'))).dy, 80 + 12, reason: 'a gap between rows');
    });

    testWidgets('a full grid keeps equal columns; no children draws nothing', (tester) async {
      await tester.pumpWidget(
        _wrap(FactoryMetricGrid(children: [for (final n in ['a', 'b', 'c', 'd']) SizedBox(key: Key(n), height: 20)])),
      );
      expect(tester.getSize(find.byKey(const Key('d'))).width, 174);

      await tester.pumpWidget(_wrap(const FactoryMetricGrid(children: [])));
      expect(tester.takeException(), isNull);
    });
  });
}

void _largeFontShareListTest() {
  testWidgets('FactoryShareList moves the figure under the name at a large font on a narrow screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryLightTheme(),
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
        home: const Scaffold(
          body: SizedBox(
            width: 210,
            child: FactoryShareList(
              items: [FactoryShareItem(label: 'A long customer name', caption: 'Hair', valueLabel: '1 250 000 ₸', share: 0.4)],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(find.text('1 250 000 ₸')).dy, greaterThan(tester.getBottomLeft(find.text('Hair')).dy - 1));
  });
}
