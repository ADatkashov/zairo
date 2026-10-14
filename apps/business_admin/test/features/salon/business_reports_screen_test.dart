import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/models/business_analytics.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/features/salon/presentation/screens/business_reports_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _provider = AdminProvider(id: 'p-1', ownerUserId: 'o-1', name: 'Zen Spa', vertical: 'beauty', status: 'ACTIVE');

BusinessAnalyticsRevenue _revenue({int services = 2}) => BusinessAnalyticsRevenue(
  totalRevenue: 125000,
  currency: 'KZT',
  revenueByDay: [
    DailyAmount(date: DateTime(2026, 10, 2), amount: 40000),
    DailyAmount(date: DateTime(2026, 10, 1), amount: 25000),
    DailyAmount(date: DateTime(2026, 10, 3), amount: 60000),
  ],
  revenueByService: [
    for (var i = 0; i < services; i++)
      RevenueByService(serviceId: 's$i', title: 'Service $i', amount: 1000.0 * (services - i), bookingCount: 3),
  ],
  revenueByStaff: const [],
  revenueRecovered: 0,
);

const _bookings = BusinessAnalyticsBookings(
  totalBookings: 40,
  completedBookings: 31,
  upcomingBookings: 5,
  cancelledBookings: 3,
  noShowBookings: 1,
  cancellationRate: 0.075,
  noShowRate: 0.025,
  repeatBookingRate: 0.3,
  trend: [],
);

Future<List<AnalyticsRange>> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 2400),
  BusinessAnalyticsRevenue? revenue,
  BusinessAnalyticsBookings? bookings = _bookings,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final requested = <AnalyticsRange>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessAnalyticsRevenueProvider.overrideWith((ref, key) {
          requested.add(key.$2);
          return revenue == null ? Future.error(StateError('no revenue')) : Future.value(revenue);
        }),
        businessAnalyticsBookingsProvider.overrideWith(
          (ref, key) => bookings == null ? Future.error(StateError('no bookings')) : Future.value(bookings),
        ),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BusinessReportsScreen(provider: _provider),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return requested;
}

void main() {
  testWidgets('draws the revenue line, the service donut and the status bars', (tester) async {
    await _pump(tester, revenue: _revenue());

    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.byType(FactorySparkline), findsOneWidget);
    expect(find.byType(FactoryDonutChart), findsOneWidget);
    expect(find.text('Service 0'), findsOneWidget);
    expect(find.text('Bookings by status'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
  });

  testWidgets('services beyond the top five are folded into "Other"', (tester) async {
    await _pump(tester, revenue: _revenue(services: 8));

    expect(find.text('Service 4'), findsOneWidget);
    expect(find.text('Service 5'), findsNothing);
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('changing the period refetches for the new window and Reset restores it', (tester) async {
    final requested = await _pump(tester, revenue: _revenue());
    final monthRange = requested.last;
    expect(find.text('Reset'), findsNothing);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(requested.last, isNot(monthRange));
    expect(find.text('Reset'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(requested.last, monthRange);
    expect(find.text('Reset'), findsNothing);
  });

  testWidgets('empty periods say so instead of drawing empty charts', (tester) async {
    const emptyBookings = BusinessAnalyticsBookings(
      totalBookings: 0,
      completedBookings: 0,
      upcomingBookings: 0,
      cancelledBookings: 0,
      noShowBookings: 0,
      cancellationRate: 0,
      noShowRate: 0,
      repeatBookingRate: 0,
      trend: [],
    );
    await _pump(
      tester,
      revenue: const BusinessAnalyticsRevenue(
        totalRevenue: 0,
        revenueByDay: [],
        revenueByService: [],
        revenueByStaff: [],
        revenueRecovered: 0,
      ),
      bookings: emptyBookings,
    );

    expect(find.text('No revenue in this period yet.'), findsNWidgets(2));
    expect(find.byType(FactoryDonutChart), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('a failed load shows a retryable error on that card only', (tester) async {
    await _pump(tester, revenue: null);

    expect(find.byType(FactoryErrorState), findsNWidgets(2)); // both revenue cards
    expect(find.byType(LinearProgressIndicator), findsNWidgets(4)); // bookings still drew
  });

  testWidgets('on a wide screen the filters sit beside the charts without overflowing', (tester) async {
    await _pump(tester, size: const Size(1280, 900), revenue: _revenue());

    expect(tester.getTopLeft(find.byType(FactoryFilterPanel)).dx, lessThan(tester.getTopLeft(find.byType(FactoryDonutChart)).dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow on a narrow phone', (tester) async {
    await _pump(tester, size: const Size(320, 2400), revenue: _revenue());

    expect(tester.takeException(), isNull);
  });
}
