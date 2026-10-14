import 'package:business_admin/features/campaigns/data/api/campaign_center_api.dart';
import 'package:business_admin/features/campaigns/data/campaign_center_exception.dart';
import 'package:business_admin/features/campaigns/data/models/campaign.dart';
import 'package:business_admin/l10n/app_localizations_en.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';

Map<String, Object?> _campaign({
  String id = 'c1',
  String type = 'SMART_FILL',
  String status = 'ACTIVE',
  String trigger = 'BOOKING_CANCELLED',
  String outcome = 'PENDING',
  String nextAction = 'WAITING_FOR_RESPONSE',
  List<String> actions = const ['PAUSE', 'CANCEL'],
  Object? failureReason,
  bool full = false,
}) =>
    {
      'id': id,
      'type': type,
      'status': status,
      'rawStatus': status,
      'triggerReason': trigger,
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
        'employeeId': 'w1',
        'employeeName': 'Aigerim',
        'customerId': 'u1',
        'slotStartsAt': '2026-10-13T10:00:00Z',
        'slotEndsAt': '2026-10-13T11:00:00Z',
        'recoveredBookingId': 'b1',
        'recoveredRevenue': 5000,
        'currency': 'KZT',
        'completedAt': '2026-10-12T12:00:00Z',
      },
    };

const _base = '/providers/p1/campaigns';

void main() {
  late FakeHttp http;
  late CampaignCenterApi api;

  setUp(() {
    http = FakeHttp();
    api = CampaignCenterApi(http.client());
  });

  group('fetchCampaigns', () {
    test('sends only the paging defaults when no filter is set', () async {
      http.reply('GET', _base, {
        'items': [_campaign()],
        'page': 0,
        'pageSize': 20,
        'totalItems': 1,
        'totalPages': 1,
      });

      final result = await api.fetchCampaigns('p1');

      expect(http.calls('GET', _base).single.queryParameters, {'page': 0, 'pageSize': 20, 'newestFirst': true});
      expect(result.items, hasLength(1));
      expect([result.page, result.pageSize, result.totalItems, result.totalPages], [0, 20, 1, 1]);
    });

    test('translates every filter into its query parameter, dropping an empty search', () async {
      http.reply('GET', _base, {'items': [], 'page': 2, 'pageSize': 5, 'totalItems': 0, 'totalPages': 0});

      await api.fetchCampaigns(
        'p1',
        type: CampaignType.rebook,
        status: CampaignStatus.paused,
        serviceId: 's1',
        employeeId: 'w1',
        from: DateTime.utc(2026, 10, 1),
        to: DateTime.utc(2026, 10, 31),
        search: 'hair',
        page: 2,
        pageSize: 5,
        newestFirst: false,
      );
      expect(http.calls('GET', _base).single.queryParameters, {
        'type': 'REBOOK',
        'status': 'PAUSED',
        'serviceId': 's1',
        'employeeId': 'w1',
        'from': '2026-10-01T00:00:00.000Z',
        'to': '2026-10-31T00:00:00.000Z',
        'search': 'hair',
        'page': 2,
        'pageSize': 5,
        'newestFirst': false,
      });

      await api.fetchCampaigns('p1', search: '');
      expect(http.calls('GET', _base).last.queryParameters.containsKey('search'), isFalse);
    });
  });

  group('campaign parsing', () {
    test('a fully populated campaign keeps every field', () async {
      http.reply('GET', '$_base/SMART_FILL/c1', _campaign(
        status: 'COMPLETED',
        outcome: 'RECOVERED',
        nextAction: 'VIEW_RECOVERED_BOOKING',
        actions: const [],
        full: true,
      ));

      final c = await api.fetchCampaignDetail('p1', CampaignType.smartFill, 'c1');

      expect(c.serviceTitle, 'Haircut');
      expect(c.employeeName, 'Aigerim');
      expect(c.customerId, 'u1');
      expect(c.slotStartsAt, isNotNull);
      expect(c.slotEndsAt, isNotNull);
      expect(c.recoveredBookingId, 'b1');
      expect(c.recoveredRevenue, 5000);
      expect(c.currency, 'KZT');
      expect(c.completedAt, isNotNull);
      expect(c.outcome, CampaignOutcome.recovered);
      expect(c.nextAction, CampaignNextAction.viewRecoveredBooking);
      expect(c.availableActions, isEmpty);
      expect(c.rawStatus, 'COMPLETED');
    });

    test('a bare campaign has null optional fields', () async {
      http.reply('GET', '$_base/REBOOK/c2', _campaign(type: 'REBOOK', trigger: 'BOOKING_COMPLETED'));

      final c = await api.fetchCampaignDetail('p1', CampaignType.rebook, 'c2');

      expect(c.type, CampaignType.rebook);
      expect(c.triggerReason, CampaignTriggerReason.bookingCompleted);
      expect(c.serviceTitle, isNull);
      expect(c.slotStartsAt, isNull);
      expect(c.recoveredRevenue, isNull);
      expect(c.completedAt, isNull);
      expect(c.failureReason, isNull);
      expect(c.availableActions, [CampaignActionType.pause, CampaignActionType.cancel]);
    });

    test('every status, outcome, next action, trigger and action is understood', () {
      expect(CampaignStatus.values.map((s) => CampaignStatus.fromWire(s.toWire())), CampaignStatus.values);
      expect(CampaignType.values.map((t) => CampaignType.fromWire(t.toWire())), CampaignType.values);
      expect(CampaignOutcome.fromWire('NOT_RECOVERED'), CampaignOutcome.notRecovered);
      expect(CampaignOutcome.fromWire('PENDING'), CampaignOutcome.pending);
      expect(
        ['NONE', 'WAITING_FOR_RESPONSE', 'PAUSED_BY_OWNER', 'RETRY_AVAILABLE', 'VIEW_RECOVERED_BOOKING']
            .map(CampaignNextAction.fromWire),
        CampaignNextAction.values,
      );
      expect(
        ['BOOKING_CANCELLED', 'BOOKING_COMPLETED', 'CUSTOMER_INACTIVE'].map(CampaignTriggerReason.fromWire),
        CampaignTriggerReason.values,
      );
      expect(
        ['PAUSE', 'RESUME', 'CANCEL', 'RETRY'].map(CampaignActionType.fromWire),
        CampaignActionType.values,
      );
      expect(CampaignFailureReason.fromWire('NO_CANDIDATES_NOTIFIED'), CampaignFailureReason.noCandidatesNotified);
      expect(CampaignFailureReason.fromWire('ANYTHING_ELSE'), CampaignFailureReason.other);
    });

    test('an unknown value in a closed set is rejected rather than guessed', () {
      expect(() => CampaignType.fromWire('X'), throwsArgumentError);
      expect(() => CampaignStatus.fromWire('X'), throwsArgumentError);
      expect(() => CampaignOutcome.fromWire('X'), throwsArgumentError);
      expect(() => CampaignActionType.fromWire('X'), throwsArgumentError);
      expect(() => CampaignNextAction.fromWire('X'), throwsArgumentError);
      expect(() => CampaignTriggerReason.fromWire('X'), throwsArgumentError);
      expect(() => CampaignTimelineEventType.fromWire('X'), throwsArgumentError);
      expect(() => SmartActionType.fromWire('X'), throwsArgumentError);
      expect(() => SmartActionPriority.fromWire('X'), throwsArgumentError);
    });

    test('a failed campaign carries its failure reason', () async {
      http.reply('GET', '$_base/SMART_FILL/c3',
          _campaign(status: 'FAILED', failureReason: 'NO_CANDIDATES_NOTIFIED', actions: const ['RETRY']));

      final c = await api.fetchCampaignDetail('p1', CampaignType.smartFill, 'c3');

      expect(c.status, CampaignStatus.failed);
      expect(c.failureReason, CampaignFailureReason.noCandidatesNotified);
    });
  });

  test('fetchStats parses the counters', () async {
    http.reply('GET', '$_base/stats', {
      'providerId': 'p1',
      'activeCampaigns': 2,
      'completedCampaigns': 5,
      'failedCampaigns': 1,
      'expiredCampaigns': 3,
      'cancelledCampaigns': 0,
      'recoveredSlots': 4,
      'totalRecoveredRevenue': 20000,
      'currency': 'KZT',
      'conversionRate': 0.35,
      'notificationsSent': 40,
      'offersAccepted': 7,
      'averageCompletionMinutes': 42.5,
      'campaignsRequiringAttention': 2,
    });

    final s = await api.fetchStats('p1');

    expect(s.providerId, 'p1');
    expect([s.activeCampaigns, s.completedCampaigns, s.failedCampaigns, s.expiredCampaigns], [2, 5, 1, 3]);
    expect([s.cancelledCampaigns, s.recoveredSlots, s.notificationsSent, s.offersAccepted], [0, 4, 40, 7]);
    expect(s.totalRecoveredRevenue, 20000);
    expect(s.conversionRate, 0.35);
    expect(s.averageCompletionMinutes, 42.5);
    expect(s.campaignsRequiringAttention, 2);
    expect(s.currency, 'KZT');
  });

  test('fetchSmartActions parses recommendations with and without a campaign', () async {
    http.reply('GET', '/providers/p1/smart-actions', {
      'providerId': 'p1',
      'items': [
        {
          'type': 'CAMPAIGN_EXPIRING_SOON',
          'priority': 'HIGH',
          'providerId': 'p1',
          'campaignType': 'SMART_FILL',
          'campaignId': 'c1',
          'customerId': 'u1',
          'serviceId': 's1',
          'employeeId': 'w1',
          'bookingId': 'b1',
          'relatedAt': '2026-10-13T10:00:00Z',
          'observedAt': '2026-10-12T10:00:00Z',
          'recommendedActions': ['PAUSE', 'RETRY'],
        },
        {
          'type': 'LONG_INACTIVE_CUSTOMER',
          'priority': 'LOW',
          'providerId': 'p1',
          'observedAt': '2026-10-12T10:00:00Z',
          'recommendedActions': <String>[],
        },
      ],
    });

    final r = await api.fetchSmartActions('p1');

    expect(r.providerId, 'p1');
    expect(r.items[0].type, SmartActionType.campaignExpiringSoon);
    expect(r.items[0].priority, SmartActionPriority.high);
    expect(r.items[0].campaignType, CampaignType.smartFill);
    expect(r.items[0].recommendedActions, [CampaignActionType.pause, CampaignActionType.retry]);
    expect(r.items[0].relatedAt, isNotNull);
    expect(r.items[1].campaignType, isNull);
    expect(r.items[1].relatedAt, isNull);
    expect(r.items[1].recommendedActions, isEmpty);
    expect(
      ['CAMPAIGN_EXPIRING_SOON', 'FAILED_CAMPAIGN', 'RETRIABLE_CAMPAIGN', 'REBOOKING_OPPORTUNITY', 'AT_RISK_CUSTOMER',
        'LONG_INACTIVE_CUSTOMER'].map(SmartActionType.fromWire),
      SmartActionType.values,
    );
    expect(['HIGH', 'MEDIUM', 'LOW'].map(SmartActionPriority.fromWire), SmartActionPriority.values);
  });

  test('fetchTimeline parses the events in order', () async {
    http.reply('GET', '$_base/REACTIVATION/c1/timeline', {
      'providerId': 'p1',
      'type': 'REACTIVATION',
      'campaignId': 'c1',
      'events': [
        {'type': 'CAMPAIGN_CREATED', 'occurredAt': '2026-10-12T10:00:00Z'},
        {'type': 'NOTIFICATION_SENT', 'occurredAt': '2026-10-12T10:05:00Z', 'relatedUserId': 'u1'},
      ],
    });

    final t = await api.fetchTimeline('p1', CampaignType.reactivation, 'c1');

    expect(t.type, CampaignType.reactivation);
    expect(t.campaignId, 'c1');
    expect(t.events.map((e) => e.type),
        [CampaignTimelineEventType.campaignCreated, CampaignTimelineEventType.notificationSent]);
    expect(t.events.map((e) => e.relatedUserId), [null, 'u1']);
    expect(
      [
        'CAMPAIGN_CREATED', 'CANDIDATES_SELECTED', 'NOTIFICATION_SENT', 'OFFER_ACCEPTED', 'BOOKING_CREATED',
        'SLOT_RECOVERED', 'CAMPAIGN_EXPIRED', 'CAMPAIGN_CANCELLED', 'CAMPAIGN_COMPLETED',
      ].map(CampaignTimelineEventType.fromWire),
      CampaignTimelineEventType.values,
    );
  });

  group('actions', () {
    test('pause, resume, cancel and retry post to their own endpoint and return the campaign', () async {
      for (final action in ['pause', 'resume', 'cancel', 'retry']) {
        http.reply('POST', '$_base/REBOOK/c1/$action', _campaign(type: 'REBOOK', status: 'PAUSED'));
      }

      expect((await api.pauseCampaign('p1', CampaignType.rebook, 'c1')).status, CampaignStatus.paused);
      await api.resumeCampaign('p1', CampaignType.rebook, 'c1');
      await api.cancelCampaign('p1', CampaignType.rebook, 'c1');
      await api.retryCampaign('p1', CampaignType.rebook, 'c1');

      for (final action in ['pause', 'resume', 'cancel', 'retry']) {
        expect(http.calls('POST', '$_base/REBOOK/c1/$action'), hasLength(1), reason: action);
      }
    });

    test('409 means the campaign changed under the owner, other errors pass through', () async {
      http.fail('POST', '$_base/REBOOK/c1/pause', 409);
      await expectLater(api.pauseCampaign('p1', CampaignType.rebook, 'c1'),
          throwsA(isA<CampaignActionConflictException>()));

      http.fail('POST', '$_base/REBOOK/c1/pause', 500);
      await expectLater(api.pauseCampaign('p1', CampaignType.rebook, 'c1'), throwsA(isA<DioException>()));
    });
  });

  test('the conflict exception has a localized message and a readable log form', () {
    final l10n = AppLocalizationsEn();
    const e = CampaignActionConflictException();

    expect(e.localizedMessage(l10n), l10n.errorCampaignActionConflict);
    expect(e.toString(), 'CampaignActionConflictException()');
  });
}
