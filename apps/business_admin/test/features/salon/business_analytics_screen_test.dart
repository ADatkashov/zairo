import 'package:business_admin/features/campaigns/presentation/providers/campaign_providers.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/models/business_analytics.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/features/salon/presentation/screens/business_analytics_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _provider = AdminProvider(id: 'p-1', ownerUserId: 'o-1', name: 'Zen Spa', vertical: 'beauty', status: 'ACTIVE');

BusinessAnalyticsOverview _overview({double? utilization = 0.62}) => BusinessAnalyticsOverview(
  totalBookings: 40,
  completedBookings: 31,
  upcomingBookings: 5,
  cancelledBookings: 3,
  noShowBookings: 1,
  cancellationRate: 0.075,
  noShowRate: 0.025,
  totalRevenue: 125000,
  averageBookingValue: 4000,
  currency: 'KZT',
  utilization: utilization,
  returningCustomerRate: 0.4,
  revenueRecovered: 18000,
  revenueRecoveredCurrency: 'KZT',
);

Future<void> _pump(
  WidgetTester tester,
  BusinessAnalyticsOverview overview,
  Size size, {
  BusinessAnalyticsRevenue? revenue,
  BusinessAnalyticsBookings? bookings,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Future<T> unavailable<T>() => Future<T>.error(StateError('not under test'));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessAnalyticsOverviewProvider.overrideWith((ref, key) async => overview),
        businessAnalyticsActionsProvider.overrideWith((ref, id) => unavailable()),
        businessAnalyticsRevenueProvider.overrideWith(
          (ref, key) => revenue == null ? unavailable() : Future.value(revenue),
        ),
        businessAnalyticsBookingsProvider.overrideWith(
          (ref, key) => bookings == null ? unavailable() : Future.value(bookings),
        ),
        businessAnalyticsSmartFillProvider.overrideWith((ref, key) => unavailable()),
        businessAnalyticsCustomersProvider.overrideWith((ref, key) => unavailable()),
        smartActionsProvider.overrideWith((ref, id) => unavailable()),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BusinessAnalyticsScreen(provider: _provider),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('overview leads with revenue and shows the rates as rings', (tester) async {
    await _pump(tester, _overview(), const Size(390, 1600));

    expect(find.text('Revenue'), findsWidgets);
    // Four rates: utilization, returning, cancellation, no-show.
    expect(find.byType(FactoryProgressRing), findsNWidgets(4));
    expect(find.text('62%'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
  });

  testWidgets('unavailable utilization is a plain figure, not an empty ring', (tester) async {
    await _pump(tester, _overview(utilization: null), const Size(390, 1600));

    expect(find.byType(FactoryProgressRing), findsNWidgets(3));
  });

  testWidgets('overview does not overflow on a narrow phone', (tester) async {
    await _pump(tester, _overview(), const Size(320, 1600));

    expect(tester.takeException(), isNull);
  });

  BusinessAnalyticsRevenue revenueOf(List<DailyAmount> days) => BusinessAnalyticsRevenue(
    totalRevenue: 0,
    currency: 'KZT',
    revenueByDay: days,
    revenueByService: const [],
    revenueByStaff: const [],
    revenueRecovered: 0,
  );

  testWidgets('revenue by day gets a sparkline once there are two or more days', (tester) async {
    await _pump(
      tester,
      _overview(),
      const Size(390, 2400),
      revenue: revenueOf([
        DailyAmount(date: DateTime(2026, 1, 3), amount: 30),
        DailyAmount(date: DateTime(2026, 1, 1), amount: 10),
        DailyAmount(date: DateTime(2026, 1, 2), amount: 20),
      ]),
    );

    expect(find.byType(FactorySparkline), findsOneWidget);
  });

  testWidgets('a single day of revenue draws no sparkline', (tester) async {
    await _pump(
      tester,
      _overview(),
      const Size(390, 2400),
      revenue: revenueOf([DailyAmount(date: DateTime(2026, 1, 1), amount: 10)]),
    );

    expect(find.byType(FactorySparkline), findsNothing);
  });

  BusinessAnalyticsBookings bookingsOf(List<DailyBookingCount> days) => BusinessAnalyticsBookings(
    totalBookings: 40,
    completedBookings: 31,
    upcomingBookings: 5,
    cancelledBookings: 3,
    noShowBookings: 1,
    cancellationRate: 0.075,
    noShowRate: 0.025,
    repeatBookingRate: 0.3,
    trend: days,
  );

  DailyBookingCount day(int d, {int completed = 1, int cancelled = 0}) => DailyBookingCount(
    date: DateTime(2026, 1, d),
    total: completed + cancelled,
    completed: completed,
    cancelled: cancelled,
    noShow: 0,
  );

  testWidgets('completed and cancelled cards draw a daily trend once there are two or more days', (tester) async {
    await _pump(
      tester,
      _overview(),
      const Size(390, 2400),
      bookings: bookingsOf([day(3, completed: 5), day(1, completed: 2), day(2, completed: 3, cancelled: 1)]),
    );

    // One line each on the Completed and Cancelled cards.
    expect(find.byType(FactorySparkline), findsNWidgets(2));
  });

  testWidgets('a single day of bookings draws no card trend', (tester) async {
    await _pump(tester, _overview(), const Size(390, 2400), bookings: bookingsOf([day(1)]));

    expect(find.byType(FactorySparkline), findsNothing);
  });
}
