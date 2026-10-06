import 'package:business_admin/features/loyalty/data/models/loyalty_overview.dart';
import 'package:business_admin/features/loyalty/presentation/providers/loyalty_admin_providers.dart';
import 'package:business_admin/features/loyalty/presentation/screens/loyalty_overview_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, LoyaltyOverview overview, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [loyaltyOverviewProvider.overrideWith((ref, providerId) async => overview)],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: LoyaltyOverviewScreen(providerId: 'p-1')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('members lead; the active share is a ring and redeemed share a meter', (tester) async {
    await _pump(
      tester,
      const LoyaltyOverview(
        totalMembers: 80,
        activeMembers: 20,
        totalPointsIssued: 1000,
        totalPointsRedeemed: 250,
        outstandingPointsLiability: 750,
        rewardsRedeemed: 9,
      ),
      const Size(390, 900),
    );

    expect(find.text('80'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('1000'), findsOneWidget);
    expect(find.text('250'), findsOneWidget);
    expect(find.text('750'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.byType(FactoryProgressRing), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('a programme with no members yet shows zeros without dividing by zero', (tester) async {
    await _pump(
      tester,
      const LoyaltyOverview(
        totalMembers: 0,
        activeMembers: 0,
        totalPointsIssued: 0,
        totalPointsRedeemed: 0,
        outstandingPointsLiability: 0,
        rewardsRedeemed: 0,
      ),
      const Size(390, 900),
    );

    expect(find.text('0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow on a narrow phone', (tester) async {
    await _pump(
      tester,
      const LoyaltyOverview(
        totalMembers: 123456,
        activeMembers: 98765,
        totalPointsIssued: 99999999,
        totalPointsRedeemed: 55555555,
        outstandingPointsLiability: 44444444,
        rewardsRedeemed: 4321,
      ),
      const Size(320, 900),
    );

    expect(tester.takeException(), isNull);
  });
}
