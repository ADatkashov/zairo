import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/campaigns/data/models/campaign.dart';
import 'package:business_admin/features/campaigns/presentation/widgets/campaign_card.dart';
import 'package:business_admin/l10n/app_localizations.dart';

CampaignDto _campaign({
  CampaignStatus status = CampaignStatus.active,
  CampaignNextAction nextAction = CampaignNextAction.waitingForResponse,
  double? recoveredRevenue,
}) {
  return CampaignDto(
    id: 'campaign-1',
    type: CampaignType.smartFill,
    status: status,
    rawStatus: 'NOTIFYING',
    triggerReason: CampaignTriggerReason.bookingCancelled,
    providerId: 'provider-1',
    serviceId: 'service-1',
    serviceTitle: 'Haircut',
    employeeId: 'employee-1',
    employeeName: 'Aigerim',
    candidateCount: 4,
    notifiedCount: 2,
    viewedCount: 1,
    acceptedCount: 0,
    recoveredRevenue: recoveredRevenue,
    currency: 'KZT',
    slotStartsAt: DateTime(2026, 9, 14, 15, 0),
    slotEndsAt: DateTime(2026, 9, 14, 15, 30),
    createdAt: DateTime(2026, 9, 13, 9, 0),
    updatedAt: DateTime(2026, 9, 13, 9, 5),
    outcome: CampaignOutcome.pending,
    nextAction: nextAction,
    availableActions: const [CampaignActionType.pause, CampaignActionType.cancel],
  );
}

Widget _wrap(Widget child) => MaterialApp(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('shows service, staff, status badge, progress and next action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(CampaignCard(campaign: _campaign(), onTap: () => tapped = true)));
    await tester.pumpAndSettle();

    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('Aigerim'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('2/4 notified'), findsOneWidget);
    expect(find.text('Waiting for a candidate to respond'), findsOneWidget);

    await tester.tap(find.byType(CampaignCard));
    expect(tapped, isTrue);
  });

  testWidgets('omits recovered-revenue row when nothing was recovered yet', (tester) async {
    await tester.pumpWidget(_wrap(CampaignCard(campaign: _campaign(), onTap: () {})));
    await tester.pumpAndSettle();

    expect(find.textContaining('Recovered'), findsNothing);
  });

  testWidgets('shows the recovered-revenue amount once a slot is recovered', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CampaignCard(
          campaign: _campaign(status: CampaignStatus.completed, nextAction: CampaignNextAction.viewRecoveredBooking, recoveredRevenue: 15000),
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Recovered'), findsOneWidget);
    expect(find.textContaining('15 000'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });
}
