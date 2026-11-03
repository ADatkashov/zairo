import 'package:business_admin/features/campaigns/data/models/campaign.dart';
import 'package:business_admin/features/campaigns/presentation/screens/campaign_detail_screen.dart';
import 'package:business_admin/features/campaigns/presentation/widgets/campaign_card.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/pump_app.dart';

const _path = '/providers/p1/campaigns/SMART_FILL/c1';

Map<String, Object?> _campaign({
  String status = 'ACTIVE',
  String outcome = 'PENDING',
  String nextAction = 'WAITING_FOR_RESPONSE',
  List<String> actions = const ['PAUSE', 'CANCEL'],
  Object? failureReason,
  bool full = true,
}) =>
    {
      'id': 'c1',
      'type': 'SMART_FILL',
      'status': status,
      'rawStatus': 'NOTIFYING',
      'triggerReason': 'BOOKING_CANCELLED',
      'providerId': 'p1',
      'serviceId': 's1',
      'candidateCount': 10,
      'notifiedCount': 6,
      'viewedCount': 3,
      'acceptedCount': 1,
      'createdAt': '2026-10-12T10:00:00Z',
      'updatedAt': '2026-10-12T10:30:00Z',
      'outcome': outcome,
      'failureReason': failureReason,
      'nextAction': nextAction,
      'availableActions': actions,
      if (full) ...{
        'serviceTitle': 'Haircut',
        'employeeName': 'Aigerim',
        'slotStartsAt': '2026-10-13T10:00:00Z',
        'recoveredBookingId': 'booking-77',
        'recoveredRevenue': 5000,
        'currency': 'KZT',
        'completedAt': '2026-10-12T12:00:00Z',
      },
    };

Map<String, Object?> _timeline(List<Map<String, Object?>> events) =>
    {'providerId': 'p1', 'type': 'SMART_FILL', 'campaignId': 'c1', 'events': events};

FakeHttp _backend({Map<String, Object?>? campaign, Map<String, Object?>? timeline}) {
  final http = FakeHttp();
  http.reply('GET', _path, campaign ?? _campaign());
  http.reply('GET', '$_path/timeline', timeline ?? _timeline([]));
  return http;
}

Future<void> _open(WidgetTester tester, FakeHttp http) async {
  useTallScreen(tester);
  await tester.pumpWidget(appOn(
    http,
    const CampaignDetailScreen(providerId: 'p1', type: CampaignType.smartFill, campaignId: 'c1'),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the service as the title and every detail of a full campaign', (tester) async {
    await _open(tester, _backend());

    expect(find.text('Haircut'), findsWidgets); // app bar + service row
    expect(find.text(campaignTypeLabel(en, CampaignType.smartFill)), findsOneWidget);
    expect(find.text(campaignStatusLabel(en, CampaignStatus.active)), findsOneWidget);
    expect(find.text(campaignTriggerReasonLabel(en, CampaignTriggerReason.bookingCancelled)), findsOneWidget);
    expect(find.text('Aigerim'), findsOneWidget);
    expect(find.text(en.campaignDetailEmployeeLabel), findsOneWidget);
    expect(find.text(en.campaignDetailSlotLabel), findsOneWidget);
    expect(find.text(en.campaignDetailCompletedLabel), findsOneWidget);
  });

  testWidgets('does not show the engine-internal status next to the owner-facing one', (tester) async {
    await _open(tester, _backend());

    expect(find.text('Engine status'), findsNothing);
    expect(find.text('NOTIFYING'), findsNothing);
  });

  testWidgets('shows the progress counters', (tester) async {
    await _open(tester, _backend());

    for (final entry in {
      en.campaignDetailCandidatesLabel: '10',
      en.campaignDetailNotifiedLabel: '6',
      en.campaignDetailViewedLabel: '3',
      en.campaignDetailAcceptedLabel: '1',
    }.entries) {
      final tile = find.ancestor(of: find.text(entry.key), matching: find.byType(FactoryStatTile));
      expect(tile, findsOneWidget, reason: entry.key);
      expect(find.descendant(of: tile, matching: find.text(entry.value)), findsOneWidget, reason: entry.key);
    }
  });

  testWidgets('shows the outcome, the next step, the recovered revenue and the recovered booking', (tester) async {
    await _open(
      tester,
      _backend(campaign: _campaign(status: 'COMPLETED', outcome: 'RECOVERED', nextAction: 'VIEW_RECOVERED_BOOKING')),
    );

    expect(find.text(campaignOutcomeLabel(en, CampaignOutcome.recovered)), findsOneWidget);
    expect(find.text(campaignNextActionLabel(en, CampaignNextAction.viewRecoveredBooking)), findsOneWidget);
    expect(find.textContaining(en.campaignDetailRecoveredRevenueLabel), findsOneWidget);
    expect(find.byType(FactoryPriceText), findsOneWidget);
    expect(find.text('${en.campaignDetailRecoveredBookingLabel}: booking-77'), findsOneWidget);
  });

  testWidgets('a campaign with nothing recovered shows no revenue, booking or optional rows', (tester) async {
    await _open(tester, _backend(campaign: _campaign(full: false)));

    expect(find.textContaining(en.campaignDetailRecoveredRevenueLabel), findsNothing);
    expect(find.textContaining(en.campaignDetailRecoveredBookingLabel), findsNothing);
    expect(find.text(en.campaignDetailEmployeeLabel), findsNothing);
    expect(find.text(en.campaignDetailSlotLabel), findsNothing);
    expect(find.text(en.campaignDetailCompletedLabel), findsNothing);
    expect(find.text('—'), findsOneWidget); // the service has no title
    expect(find.text(campaignTypeLabel(en, CampaignType.smartFill)), findsWidgets); // title falls back to the type
  });

  testWidgets('zero recovered revenue is not shown as revenue', (tester) async {
    final campaign = _campaign()..['recoveredRevenue'] = 0;
    await _open(tester, _backend(campaign: campaign));

    expect(find.textContaining(en.campaignDetailRecoveredRevenueLabel), findsNothing);
  });

  testWidgets('a failed campaign says why', (tester) async {
    await _open(
      tester,
      _backend(campaign: _campaign(status: 'FAILED', failureReason: 'NO_CANDIDATES_NOTIFIED', actions: ['RETRY'])),
    );

    expect(
      find.text(
          '${en.campaignDetailFailureReasonLabel}: ${campaignFailureReasonLabel(en, CampaignFailureReason.noCandidatesNotified)}'),
      findsOneWidget,
    );
  });

  group('timeline', () {
    testWidgets('lists the events in order with their labels', (tester) async {
      await _open(
        tester,
        _backend(timeline: _timeline([
          {'type': 'CAMPAIGN_CREATED', 'occurredAt': '2026-10-12T10:00:00Z'},
          {'type': 'NOTIFICATION_SENT', 'occurredAt': '2026-10-12T10:05:00Z', 'relatedUserId': 'u1'},
        ])),
      );

      expect(find.text(en.campaignDetailSectionTimeline), findsOneWidget);
      final created = tester.getTopLeft(find.text(campaignTimelineEventLabel(en, CampaignTimelineEventType.campaignCreated)));
      final sent = tester.getTopLeft(find.text(campaignTimelineEventLabel(en, CampaignTimelineEventType.notificationSent)));
      expect(created.dy, lessThan(sent.dy));
      expect(find.text(en.campaignTimelineEmpty), findsNothing);
    });

    testWidgets('says so when there are no events yet', (tester) async {
      await _open(tester, _backend());

      expect(find.text(en.campaignTimelineEmpty), findsOneWidget);
    });

    testWidgets('a timeline that fails to load shows its own error and can be retried', (tester) async {
      final http = _backend();
      http.fail('GET', '$_path/timeline', 500);
      await _open(tester, http);

      expect(find.text(en.errorCampaignTimelineLoadFailed), findsOneWidget);
      expect(find.text(en.campaignDetailCandidatesLabel), findsOneWidget); // the rest still shows

      http.reply('GET', '$_path/timeline', _timeline([
        {'type': 'CAMPAIGN_CREATED', 'occurredAt': '2026-10-12T10:00:00Z'},
      ]));
      await tester.tap(find.descendant(of: find.byType(FactoryErrorState), matching: find.byType(FactoryButton)));
      await tester.pumpAndSettle();

      expect(find.text(en.errorCampaignTimelineLoadFailed), findsNothing);
      expect(find.text(campaignTimelineEventLabel(en, CampaignTimelineEventType.campaignCreated)), findsOneWidget);
    });
  });

  group('loading and failure', () {
    testWidgets('a campaign that fails to load shows an error and retrying loads it', (tester) async {
      final http = _backend();
      http.fail('GET', _path, 500);
      await _open(tester, http);

      expect(find.text(en.errorCampaignDetailLoadFailed), findsOneWidget);
      expect(find.text(en.campaignDetailSectionProgress), findsNothing);

      http.reply('GET', _path, _campaign());
      await tester.tap(find.descendant(of: find.byType(FactoryErrorState), matching: find.byType(FactoryButton)));
      await tester.pumpAndSettle();

      expect(find.text(en.errorCampaignDetailLoadFailed), findsNothing);
      expect(find.text(en.campaignDetailSectionProgress), findsOneWidget);
    });
  });

  group('actions', () {
    testWidgets('only the actions the server allows are shown', (tester) async {
      await _open(tester, _backend(campaign: _campaign(actions: ['PAUSE', 'CANCEL'])));

      expect(find.widgetWithText(FactoryButton, campaignActionLabel(en, CampaignActionType.pause)), findsOneWidget);
      expect(find.widgetWithText(FactoryButton, campaignActionLabel(en, CampaignActionType.cancel)), findsOneWidget);
      expect(find.widgetWithText(FactoryButton, campaignActionLabel(en, CampaignActionType.resume)), findsNothing);
      expect(find.widgetWithText(FactoryButton, campaignActionLabel(en, CampaignActionType.retry)), findsNothing);
    });

    testWidgets('no action buttons when the campaign allows none', (tester) async {
      await _open(tester, _backend(campaign: _campaign(actions: [])));

      expect(find.widgetWithText(FactoryButton, campaignActionLabel(en, CampaignActionType.pause)), findsNothing);
      expect(find.widgetWithText(FactoryButton, campaignActionLabel(en, CampaignActionType.cancel)), findsNothing);
    });

    testWidgets('pause, resume and retry act at once and reload the campaign', (tester) async {
      for (final (action, label) in [
        ('pause', CampaignActionType.pause),
        ('resume', CampaignActionType.resume),
        ('retry', CampaignActionType.retry),
      ]) {
        final http = _backend(campaign: _campaign(actions: [action.toUpperCase()]));
        http.reply('POST', '$_path/$action', _campaign(actions: []));
        await _open(tester, http);
        final loads = http.calls('GET', _path).length;

        await tester.tap(find.widgetWithText(FactoryButton, campaignActionLabel(en, label)));
        await tester.pumpAndSettle();

        expect(http.calls('POST', '$_path/$action'), hasLength(1), reason: action);
        expect(http.calls('GET', _path).length, greaterThan(loads), reason: '$action reloads the campaign');
      }
    });

    testWidgets('cancel asks first; keeping the campaign sends nothing', (tester) async {
      final http = _backend();
      await _open(tester, http);

      await tester.tap(find.widgetWithText(FactoryButton, campaignActionLabel(en, CampaignActionType.cancel)));
      await tester.pumpAndSettle();
      expect(find.text(en.campaignCancelConfirmTitle), findsOneWidget);

      await tester.tap(find.text(en.campaignCancelConfirmDismiss));
      await tester.pumpAndSettle();

      expect(find.text(en.campaignCancelConfirmTitle), findsNothing);
      expect(http.calls('POST', '$_path/cancel'), isEmpty);
    });

    testWidgets('cancel goes through once the owner confirms', (tester) async {
      final http = _backend();
      http.reply('POST', '$_path/cancel', _campaign(status: 'CANCELLED', actions: []));
      await _open(tester, http);

      await tester.tap(find.widgetWithText(FactoryButton, campaignActionLabel(en, CampaignActionType.cancel)));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text(en.campaignCancelConfirmButton)));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(http.calls('POST', '$_path/cancel'), hasLength(1));
    });

    testWidgets('a conflict says the action no longer applies and refreshes the campaign', (tester) async {
      final http = _backend();
      http.fail('POST', '$_path/pause', 409);
      await _open(tester, http);
      final loads = http.calls('GET', _path).length;

      await tester.tap(find.widgetWithText(FactoryButton, campaignActionLabel(en, CampaignActionType.pause)));
      await tester.pumpAndSettle();

      expect(find.text(en.errorCampaignActionConflict), findsOneWidget);
      expect(http.calls('GET', _path).length, greaterThan(loads));
    });

    testWidgets('any other failure shows the generic message', (tester) async {
      final http = _backend();
      http.fail('POST', '$_path/pause', 500);
      await _open(tester, http);

      await tester.tap(find.widgetWithText(FactoryButton, campaignActionLabel(en, CampaignActionType.pause)));
      await tester.pumpAndSettle();

      expect(find.text(en.errorCampaignActionFailed), findsOneWidget);
      expect(find.text(en.errorCampaignActionConflict), findsNothing);
    });
  });
}
