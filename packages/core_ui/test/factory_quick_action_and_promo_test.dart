import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {double width = 400}) => MaterialApp(
  theme: factoryLightTheme(),
  home: Scaffold(
    body: Center(child: SizedBox(width: width, child: child)),
  ),
);

List<FactoryQuickAction> _actions(int count, {void Function(String)? onTap}) => [
  for (var i = 0; i < count; i++)
    FactoryQuickAction(
      icon: Icons.star_rounded,
      label: 'Action $i',
      badge: i == 0 ? 'NEW' : null,
      onTap: () => onTap?.call('Action $i'),
    ),
];

void main() {
  group('FactoryQuickActionGrid', () {
    testWidgets('lays eight actions out as two rows of four', (tester) async {
      await tester.pumpWidget(_wrap(FactoryQuickActionGrid(actions: _actions(8))));

      final first = tester.getTopLeft(find.text('Action 0'));
      final fourth = tester.getTopLeft(find.text('Action 3'));
      final fifth = tester.getTopLeft(find.text('Action 4'));
      expect(fourth.dy, first.dy);
      expect(fifth.dy, greaterThan(first.dy));
      expect(fifth.dx, closeTo(first.dx, 20));
    });

    testWidgets('a short last row keeps the column grid', (tester) async {
      await tester.pumpWidget(_wrap(FactoryQuickActionGrid(actions: _actions(5))));

      expect(find.text('Action 4'), findsOneWidget);
      // The lone tile of row two sits in column one, under Action 0.
      expect(
        tester.getCenter(find.text('Action 4')).dx,
        closeTo(tester.getCenter(find.text('Action 0')).dx, 1),
      );
    });

    testWidgets('tapping a tile calls only its own callback', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _wrap(FactoryQuickActionGrid(actions: _actions(4, onTap: taps.add))),
      );

      await tester.tap(find.text('Action 2'));
      expect(taps, ['Action 2']);
    });

    testWidgets('shows the badge only on the tile that has one', (tester) async {
      await tester.pumpWidget(_wrap(FactoryQuickActionGrid(actions: _actions(4))));

      expect(find.text('NEW'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Action 0, NEW'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Action 1'), findsOneWidget);
    });

    testWidgets('honours a custom column count', (tester) async {
      await tester.pumpWidget(
        _wrap(FactoryQuickActionGrid(actions: _actions(4), columns: 2)),
      );

      expect(
        tester.getTopLeft(find.text('Action 2')).dy,
        greaterThan(tester.getTopLeft(find.text('Action 0')).dy),
      );
    });

    testWidgets('long labels wrap instead of overflowing on a narrow screen', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FactoryQuickActionGrid(
            actions: [
              for (var i = 0; i < 4; i++)
                FactoryQuickAction(icon: Icons.star_rounded, label: 'A fairly long action label $i', onTap: () {}),
            ],
          ),
          width: 320,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

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
