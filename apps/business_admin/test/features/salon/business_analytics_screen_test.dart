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

const _provider = AdminProvider(
  id: 'p-1',
  ownerUserId: 'o-1',
  name: 'Zen Spa',
  vertical: 'beauty',
  status: 'ACTIVE',
);

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

Future<void> _pump(WidgetTester tester, BusinessAnalyticsOverview overview, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Future<T> unavailable<T>() => Future<T>.error(StateError('not under test'));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessAnalyticsOverviewProvider.overrideWith((ref, key) async => overview),
        businessAnalyticsActionsProvider.overrideWith((ref, id) => unavailable()),
        businessAnalyticsRevenueProvider.overrideWith((ref, key) => unavailable()),
        businessAnalyticsBookingsProvider.overrideWith((ref, key) => unavailable()),
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
}
