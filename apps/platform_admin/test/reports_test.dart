import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/app/routes.dart';
import 'package:platform_admin/features/reports/data/platform_report.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

Map<String, dynamic> _report({int days = 7, bool earned = true}) {
  final dates = [for (var i = 0; i < days; i++) '2026-10-${(i + 1).toString().padLeft(2, '0')}'];
  return {
    'from': dates.first,
    'to': dates.last,
    'bookingsCreated': [for (var i = 0; i < days; i++) {'date': dates[i], 'count': i + 1}],
    'commissionByDay': [for (var i = 0; i < days; i++) {'date': dates[i], 'amount': earned ? 1000 * (i + 1) : 0}],
    'commissionCurrency': earned ? 'KZT' : null,
    'subscriptionRevenueByDay': [for (var i = 0; i < days; i++) {'date': dates[i], 'amount': 0}],
    'subscriptionCurrency': null,
    'bookingsByStatus': {'pending': 2, 'confirmed': 3, 'completed': 10, 'cancelled': 4, 'noShow': 1},
  };
}

FakeBackend _backend({bool earned = true}) {
  final backend = defaultBackend();
  backend.on('GET', '/platform/reports', (request) {
    final days = request.queryParameters['days'] as int;
    return FakeReply(_report(days: days > 14 ? 14 : days, earned: earned));
  });
  return backend;
}

void main() {
  group('PlatformReport.fromJson', () {
    test('reads every series, the currencies and the status counts', () {
      final report = PlatformReport.fromJson(_report());

      expect(report.bookingsCreated.values, [1, 2, 3, 4, 5, 6, 7]);
      expect(report.bookingsCreated.total, 28);
      expect(report.commissionByDay.total, 28000);
      expect(report.commissionCurrency, 'KZT');
      expect(report.subscriptionCurrency, isNull);
      expect(report.bookingsByStatus.total, 20);
      expect(report.from, DateTime.parse('2026-10-01'));
    });

    test('missing sections are empty rather than errors', () {
      final report = PlatformReport.fromJson({'from': '2026-10-01', 'to': '2026-10-01'});

      expect(report.bookingsCreated, isEmpty);
      expect(report.bookingsByStatus.total, 0);
    });
  });

  testWidgets('the dashboard opens the reports and the back button returns', (tester) async {
    await pumpConsole(tester, backend: _backend());

    await tester.tap(find.byTooltip('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Marketplace commission'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Aida'), findsOneWidget);
  });

  testWidgets('shows commission, bookings and the status donut for the default 30-day window', (tester) async {
    final backend = _backend();
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.reports);

    expect(backend.calls('GET', '/platform/reports').single.queryParameters['days'], 30);
    expect(find.text('Marketplace commission'), findsOneWidget);
    expect(find.text('₸28,000'), findsOneWidget);
    expect(find.text('Bookings created'), findsWidgets);
    expect(find.byType(FactoryDonutChart), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    // Commission and bookings draw a line; subscription revenue is empty, so it does not.
    expect(find.byType(FactorySparkline), findsNWidgets(2));
    expect(find.text('Nothing in this period yet.'), findsOneWidget);
  });

  testWidgets('changing the window refetches, and Reset goes back to 30 days', (tester) async {
    final backend = _backend();
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.reports);
    expect(find.text('Reset'), findsNothing);

    await tester.tap(find.text('Last 7 days'));
    await tester.pumpAndSettle();
    expect(backend.calls('GET', '/platform/reports').last.queryParameters['days'], 7);
    expect(find.text('Reset'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(backend.calls('GET', '/platform/reports').last.queryParameters['days'], 30);
    expect(find.text('Reset'), findsNothing);
  });

  testWidgets('with no earnings the money cards say so instead of drawing a line', (tester) async {
    await pumpConsole(tester, backend: _backend(earned: false), location: ConsoleRoutes.reports);

    expect(find.text('Nothing in this period yet.'), findsNWidgets(2));
    expect(find.byType(FactorySparkline), findsOneWidget); // bookings only
  });

  testWidgets('a failed load shows a retry, not a blank page', (tester) async {
    final backend = defaultBackend()..reply('GET', '/platform/reports', {'message': 'boom'}, status: 500);
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.reports);

    expect(find.byType(FactoryErrorState), findsOneWidget);
  });

  testWidgets('a phone shows the filters above the charts without overflowing', (tester) async {
    await pumpConsole(tester, backend: _backend(), location: ConsoleRoutes.reports, size: const Size(390, 2400));

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Marketplace commission'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
