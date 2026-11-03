import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

Map<String, Object?> _metrics({int businessesTotal = 12}) => {
  'users': {'total': 1200},
  'businesses': {'total': businessesTotal, 'active': 9, 'pendingModeration': 1, 'blocked': 2},
  'subscriptions': {'free': 7, 'pro': 5, 'active': 5, 'pastDue': 1, 'cancelled': 2},
  'bookings': {'today': 14, 'thisWeek': 90, 'thisMonth': 350, 'completed': 800, 'cancelled': 40},
  'payments': {'succeeded': 700, 'failed': 12, 'pending': 5, 'refunded': 20, 'refundFailed': 1},
  'revenue': {'mrr': 150000, 'currency': 'KZT', 'platformCommission': 42000, 'platformCommissionCurrency': 'KZT'},
  'reviews': {'reportedOpen': 0},
};

Map<String, Object?> _trends(List<int> counts) => {
  'bookingsCreated': [
    for (var i = 0; i < counts.length; i++) {'date': '2026-10-${(i + 1).toString().padLeft(2, '0')}', 'count': counts[i]},
  ],
};

void main() {
  group('headline numbers', () {
    testWidgets('revenue, commission, bookings and users, formatted for the locale', (tester) async {
      await pumpConsole(tester, backend: defaultBackend());

      expect(find.widgetWithText(FactoryKpiCard, 'Subscriptions'), findsOneWidget);
      expect(find.text('₸150,000'), findsOneWidget);
      expect(find.widgetWithText(FactoryKpiCard, 'Commission'), findsOneWidget);
      expect(find.text('₸42,000'), findsOneWidget);
      expect(find.widgetWithText(FactoryKpiCard, 'Users'), findsOneWidget);
      expect(find.text('1,200'), findsOneWidget);
      expect(find.text('Subscriptions and ZAIRO’s commission are separate lines.'), findsOneWidget);
    });

    testWidgets('without trend history bookings show this week, with no chip or line', (tester) async {
      await pumpConsole(tester, backend: defaultBackend());

      expect(find.widgetWithText(FactoryKpiCard, 'This week'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.byType(FactoryTrendBadge), findsNothing);
      expect(find.byType(FactorySparkline), findsNothing);
    });

    testWidgets('two weeks of history give the trend line and the change against the week before', (tester) async {
      final backend = defaultBackend()
        ..reply('GET', '/platform/dashboard/trends', _trends([for (var i = 1; i <= 14; i++) i]));
      await pumpConsole(tester, backend: backend);

      expect(find.text('Bookings, last 14 days'), findsOneWidget);
      expect(find.text('105'), findsOneWidget);
      expect(find.byType(FactorySparkline), findsOneWidget);
      expect(find.text('▲ +175%'), findsOneWidget, reason: '77 this week vs 28 the week before');
      expect(find.text('vs previous 7 days'), findsOneWidget);
    });

    testWidgets('a short history still draws the trend, but makes no week-on-week claim', (tester) async {
      final backend = defaultBackend()..reply('GET', '/platform/dashboard/trends', _trends([1, 2, 3, 4, 5]));
      await pumpConsole(tester, backend: backend);

      expect(find.text('Bookings, last 5 days'), findsOneWidget);
      expect(find.byType(FactorySparkline), findsOneWidget);
      expect(find.byType(FactoryTrendBadge), findsNothing);
      expect(find.text('vs previous 7 days'), findsNothing);
    });

    testWidgets('money without a currency shows a dash, not a made-up amount', (tester) async {
      final data = _metrics();
      data['revenue'] = {'mrr': 0, 'currency': null, 'platformCommission': 0, 'platformCommissionCurrency': null};
      final backend = defaultBackend()..reply('GET', '/platform/dashboard', data);
      await pumpConsole(tester, backend: backend);

      expect(find.text('—'), findsNWidgets(2));
    });
  });

  group('breakdown rings', () {
    testWidgets('businesses by status, with the total', (tester) async {
      await pumpConsole(tester, backend: defaultBackend());

      expect(find.text('Total: 12'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Awaiting approval'), findsOneWidget);
      expect(find.text('Suspended'), findsOneWidget);
      expect(find.text('Other'), findsNothing, reason: '9 + 1 + 2 is every business');
    });

    testWidgets('businesses in a state the dashboard does not name are shown as Other', (tester) async {
      final backend = defaultBackend()..reply('GET', '/platform/dashboard', _metrics(businessesTotal: 15));
      await pumpConsole(tester, backend: backend);

      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('bookings, payments and subscriptions are summarised', (tester) async {
      await pumpConsole(tester, backend: defaultBackend());

      expect(find.text('Today 14 · This week 90 · This month 350'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsWidgets);
      expect(find.text('Succeeded'), findsOneWidget);
      expect(find.text('Refund failed'), findsOneWidget);
      expect(find.text('Pro plan'), findsOneWidget);
      expect(find.text('Free plan'), findsOneWidget);
      expect(find.text('Active 5 · Past due 1 · Cancelled 2'), findsOneWidget);
    });

    testWidgets('a legend row with a list behind it opens it; plain rows do nothing', (tester) async {
      await pumpConsole(tester, backend: defaultBackend(), size: const Size(1400, 1400));

      await tester.tap(find.text('Succeeded'));
      await tester.pumpAndSettle();
      expect(find.text('Succeeded'), findsOneWidget, reason: 'still on the dashboard');

      await tester.tap(find.text('Refund failed'));
      await tester.pumpAndSettle();
      expect(find.text('Provider timeout'), findsWidgets, reason: 'the refunds tab of Finance');
    });

    testWidgets('the cards of a row are the same height, side by side on a wide screen', (tester) async {
      await pumpConsole(tester, backend: defaultBackend(), size: const Size(1400, 1400));

      Finder card(String text) => find.ancestor(of: find.text(text), matching: find.byType(FactoryCard)).first;
      final businesses = card('Total: 12');
      final bookings = card('Today 14 · This week 90 · This month 350');
      expect(tester.getTopLeft(businesses).dy, tester.getTopLeft(bookings).dy);
      expect(tester.getSize(businesses).height, tester.getSize(bookings).height);
      expect(tester.getTopLeft(bookings).dx, greaterThan(tester.getTopRight(businesses).dx));
    });

    testWidgets('on a phone they stack', (tester) async {
      await pumpConsole(tester, backend: defaultBackend(), size: const Size(360, 3000));

      Finder card(String text) => find.ancestor(of: find.text(text), matching: find.byType(FactoryCard)).first;
      expect(
        tester.getTopLeft(card('Today 14 · This week 90 · This month 350')).dy,
        greaterThan(tester.getBottomLeft(card('Total: 12')).dy),
      );
    });

    testWidgets('fits a 320 px phone with a 2x font (legends move under the rings)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpConsole(tester, backend: defaultBackend(), size: const Size(320, 6000));

      expect(tester.takeException(), isNull);
      expect(find.text('Awaiting approval'), findsOneWidget);
    });

    testWidgets('an empty platform draws empty rings, not an error', (tester) async {
      final backend = defaultBackend()
        ..reply('GET', '/platform/dashboard', {
          'users': {},
          'businesses': {},
          'subscriptions': {},
          'bookings': {},
          'payments': {},
          'revenue': {},
        });
      await pumpConsole(tester, backend: backend);

      expect(tester.takeException(), isNull);
      expect(find.text('Total: 0'), findsOneWidget);
    });
  });
}
