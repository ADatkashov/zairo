import 'package:business_admin/features/loyalty/data/api/loyalty_admin_api.dart';
import 'package:business_admin/features/loyalty/data/loyalty_admin_exception.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_milestone.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_redemption.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_reward.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_tier.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';

const _base = '/business/p1/loyalty';

const _settings = {
  'providerId': 'p1',
  'enabled': true,
  'name': 'Glow Rewards',
  'description': 'Earn points',
  'fixedPointsPerBooking': 10,
  'pointsPerCurrencyUnit': 0.01,
  'firstBookingBonusPoints': 50,
  'repeatVisitBonusPoints': 20,
  'repeatVisitThreshold': 3,
  'reviewBonusPoints': 5,
  'pointsPerCurrencyUnitRedemption': 0.5,
  'minRedemptionPoints': 100,
  'maxRedemptionPointsPerBooking': 500,
  'pointsExpireEnabled': true,
  'pointsExpirationMonths': 12,
  'dailyEarningPointsCap': 200,
  'monthlyEarningPointsCap': 2000,
  'birthdayBonusPoints': 30,
};

const _reward = {
  'id': 'r1',
  'name': '10% off',
  'type': 'PERCENTAGE_DISCOUNT',
  'pointsCost': 300,
  'discountPercentage': 10,
  'redemptionsCount': 2,
  'active': true,
};

const _redemption = {
  'id': 'red1',
  'userId': 'u1',
  'rewardId': 'r1',
  'rewardName': '10% off',
  'pointsSpent': 300,
  'code': 'ABC123',
  'status': 'ACTIVE',
  'createdAt': '2026-10-12T10:00:00Z',
  'expiresAt': '2026-11-12T10:00:00Z',
};

const _customer = {
  'userId': 'u1',
  'displayName': 'Aigerim',
  'email': 'a@example.com',
  'pointsBalance': 450,
  'lifetimeEarned': 900,
  'lifetimeRedeemed': 450,
  'completedVisits': 9,
  'lastActivityAt': '2026-10-10T10:00:00Z',
  'pointsExpiringSoon30d': 40,
  'retentionStatus': 'ACTIVE',
};

Map<String, Object?> _page(List<Object?> content) => {
      'content': content,
      'totalElements': 41,
      'totalPages': 3,
      'number': 1,
      'size': 20,
      'first': false,
      'last': false,
    };

Future<LoyaltyAdminException> _failure(Future<Object?> Function() call) async {
  try {
    await call();
  } on LoyaltyAdminException catch (e) {
    return e;
  }
  fail('expected a LoyaltyAdminException');
}

void main() {
  late FakeHttp http;
  late LoyaltyAdminApi api;

  setUp(() {
    http = FakeHttp();
    api = LoyaltyAdminApi(http.client());
  });

  group('settings', () {
    test('fetchSettings parses every field', () async {
      http.reply('GET', '$_base/settings', _settings);

      final s = await api.fetchSettings('p1');

      expect(s.name, 'Glow Rewards');
      expect(s.pointsPerCurrencyUnit, 0.01);
      expect(s.pointsPerCurrencyUnitRedemption, 0.5);
      expect(s.minRedemptionPoints, 100);
      expect(s.maxRedemptionPointsPerBooking, 500);
      expect(s.pointsExpirationMonths, 12);
      expect(s.dailyEarningPointsCap, 200);
      expect(s.monthlyEarningPointsCap, 2000);
      expect(s.birthdayBonusPoints, 30);
    });

    test('optional settings may be absent and the birthday bonus defaults to 0', () async {
      http.reply('GET', '$_base/settings', {
        ..._settings,
        'description': null,
        'pointsPerCurrencyUnitRedemption': null,
        'minRedemptionPoints': null,
        'maxRedemptionPointsPerBooking': null,
        'pointsExpireEnabled': false,
        'pointsExpirationMonths': null,
        'dailyEarningPointsCap': null,
        'monthlyEarningPointsCap': null,
        'birthdayBonusPoints': null,
      });

      final s = await api.fetchSettings('p1');

      expect(s.description, isNull);
      expect(s.minRedemptionPoints, isNull);
      expect(s.dailyEarningPointsCap, isNull);
      expect(s.birthdayBonusPoints, 0);
    });

    test('updateSettings puts the editable fields (not the provider id) and returns the saved ones', () async {
      http.reply('GET', '$_base/settings', _settings);
      http.reply('PUT', '$_base/settings', {..._settings, 'name': 'Renamed'});
      final current = await api.fetchSettings('p1');

      final saved = await api.updateSettings('p1', current.copyWith(name: 'Renamed'));

      final body = http.bodyOf('PUT', '$_base/settings');
      expect(body['name'], 'Renamed');
      expect(body['fixedPointsPerBooking'], 10);
      expect(body.containsKey('providerId'), isFalse);
      expect(body.length, 17);
      expect(saved.name, 'Renamed');
    });

    test('copyWith changes only what it is given, and the clear flags blank optional values', () async {
      http.reply('GET', '$_base/settings', _settings);
      final s = await api.fetchSettings('p1');

      final changed = s.copyWith(
        enabled: false,
        description: 'New',
        fixedPointsPerBooking: 1,
        pointsPerCurrencyUnit: 2,
        firstBookingBonusPoints: 3,
        repeatVisitBonusPoints: 4,
        repeatVisitThreshold: 5,
        reviewBonusPoints: 6,
        pointsPerCurrencyUnitRedemption: 7,
        minRedemptionPoints: 8,
        maxRedemptionPointsPerBooking: 9,
        pointsExpireEnabled: false,
        pointsExpirationMonths: 10,
        dailyEarningPointsCap: 11,
        monthlyEarningPointsCap: 12,
        birthdayBonusPoints: 13,
      );
      expect(changed.providerId, 'p1');
      expect(changed.name, 'Glow Rewards');
      expect(changed.enabled, isFalse);
      expect(changed.description, 'New');
      expect([
        changed.fixedPointsPerBooking,
        changed.pointsPerCurrencyUnit,
        changed.firstBookingBonusPoints,
        changed.repeatVisitBonusPoints,
        changed.repeatVisitThreshold,
        changed.reviewBonusPoints,
        changed.pointsPerCurrencyUnitRedemption,
        changed.minRedemptionPoints,
        changed.maxRedemptionPointsPerBooking,
        changed.pointsExpirationMonths,
        changed.dailyEarningPointsCap,
        changed.monthlyEarningPointsCap,
        changed.birthdayBonusPoints,
      ], [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]);

      final cleared = s.copyWith(
        clearDescription: true,
        clearPointsPerCurrencyUnitRedemption: true,
        clearMinRedemptionPoints: true,
        clearMaxRedemptionPointsPerBooking: true,
        clearPointsExpirationMonths: true,
        clearDailyEarningPointsCap: true,
        clearMonthlyEarningPointsCap: true,
      );
      expect(cleared.description, isNull);
      expect(cleared.pointsPerCurrencyUnitRedemption, isNull);
      expect(cleared.minRedemptionPoints, isNull);
      expect(cleared.maxRedemptionPointsPerBooking, isNull);
      expect(cleared.pointsExpirationMonths, isNull);
      expect(cleared.dailyEarningPointsCap, isNull);
      expect(cleared.monthlyEarningPointsCap, isNull);
      expect(cleared.name, 'Glow Rewards'); // untouched

      final untouched = s.copyWith();
      expect(untouched.toUpdateJson(), s.toUpdateJson());
    });
  });

  group('birthdays and greetings', () {
    test('fetchBirthdays asks for 30 days by default and parses the flags', () async {
      http.reply('GET', '$_base/birthdays', [
        {
          'userId': 'u1',
          'displayName': 'Aigerim',
          'month': 10,
          'day': 20,
          'daysUntil': 8,
          'bonusPoints': 30,
          'bonusAwarded': true,
          'greetedToday': true,
        },
        {'userId': 'u2', 'month': 11, 'day': 1, 'daysUntil': 20, 'bonusPoints': 0},
      ]);

      final birthdays = await api.fetchBirthdays('p1');
      expect(http.calls('GET', '$_base/birthdays').single.queryParameters, {'days': 30});
      expect(birthdays[0].bonusAwarded, isTrue);
      expect(birthdays[0].greetedToday, isTrue);
      expect(birthdays[1].displayName, isNull);
      expect(birthdays[1].bonusAwarded, isFalse);
      expect(birthdays[1].greetedToday, isFalse);

      await api.fetchBirthdays('p1', days: 7);
      expect(http.calls('GET', '$_base/birthdays').last.queryParameters, {'days': 7});
    });

    test('sendGreeting posts the message and the optional bonus', () async {
      http.reply('POST', '$_base/customers/u1/greet', <String, Object?>{});

      await api.sendGreeting('p1', 'u1', message: 'Happy birthday!', bonusPoints: 50);
      expect(http.bodyOf('POST', '$_base/customers/u1/greet'), {'message': 'Happy birthday!', 'bonusPoints': 50});

      http.requests.clear();
      await api.sendGreeting('p1', 'u1');
      expect(http.bodyOf('POST', '$_base/customers/u1/greet'), {'message': null, 'bonusPoints': null});
    });
  });

  group('milestones and tiers', () {
    test('fetchMilestones parses them', () async {
      http.reply('GET', '$_base/milestones', [
        {'id': 'm1', 'visitsRequired': 5, 'pointsAwarded': 100, 'label': 'Regular'},
        {'id': 'm2', 'visitsRequired': 10, 'pointsAwarded': 300},
      ]);

      final milestones = await api.fetchMilestones('p1');

      expect(milestones.map((m) => m.label), ['Regular', null]);
      expect(milestones.map((m) => m.visitsRequired), [5, 10]);
    });

    test('replaceMilestones sends the whole list (without ids) and returns the saved one', () async {
      http.reply('PUT', '$_base/milestones', [
        {'id': 'm9', 'visitsRequired': 5, 'pointsAwarded': 100, 'label': 'Regular'},
      ]);

      final saved = await api.replaceMilestones('p1', [
        const LoyaltyMilestone(visitsRequired: 5, pointsAwarded: 100, label: 'Regular'),
      ]);

      expect(http.bodyOf('PUT', '$_base/milestones'), {
        'milestones': [
          {'visitsRequired': 5, 'pointsAwarded': 100, 'label': 'Regular'},
        ],
      });
      expect(saved.single.id, 'm9');
    });

    test('LoyaltyMilestone.copyWith updates fields, keeps the id and can clear the label', () {
      const m = LoyaltyMilestone(id: 'm1', visitsRequired: 5, pointsAwarded: 100, label: 'Regular');

      final changed = m.copyWith(visitsRequired: 6, pointsAwarded: 150, label: 'VIP');
      expect([changed.id, changed.visitsRequired, changed.pointsAwarded, changed.label], ['m1', 6, 150, 'VIP']);

      expect(m.copyWith(clearLabel: true).label, isNull);
      expect(m.copyWith().label, 'Regular');
    });

    test('tiers: fetch, replace and copyWith', () async {
      http.reply('GET', '$_base/tiers', [
        {'id': 't1', 'name': 'Silver', 'minLifetimePoints': 500},
      ]);
      http.reply('PUT', '$_base/tiers', [
        {'id': 't2', 'name': 'Gold', 'minLifetimePoints': 1000},
      ]);

      expect((await api.fetchTiers('p1')).single.name, 'Silver');

      final saved = await api.replaceTiers('p1', [const LoyaltyTier(name: 'Gold', minLifetimePoints: 1000)]);
      expect(http.bodyOf('PUT', '$_base/tiers'), {
        'tiers': [
          {'name': 'Gold', 'minLifetimePoints': 1000},
        ],
      });
      expect(saved.single.id, 't2');

      const tier = LoyaltyTier(id: 't1', name: 'Silver', minLifetimePoints: 500);
      expect(tier.copyWith(name: 'Platinum').name, 'Platinum');
      expect(tier.copyWith(minLifetimePoints: 2000).minLifetimePoints, 2000);
      expect(tier.copyWith().id, 't1');
    });
  });

  group('overview and customers', () {
    test('fetchOverview parses the programme totals', () async {
      http.reply('GET', '$_base/overview', {
        'totalMembers': 100,
        'activeMembers': 60,
        'totalPointsIssued': 50000,
        'totalPointsRedeemed': 20000,
        'outstandingPointsLiability': 30000,
        'rewardsRedeemed': 40,
      });

      final o = await api.fetchOverview('p1');

      expect([o.totalMembers, o.activeMembers, o.totalPointsIssued, o.totalPointsRedeemed], [100, 60, 50000, 20000]);
      expect([o.outstandingPointsLiability, o.rewardsRedeemed], [30000, 40]);
    });

    test('fetchCustomers pages through the list', () async {
      http.reply('GET', '$_base/customers', _page([_customer]));

      final page = await api.fetchCustomers('p1');
      expect(http.calls('GET', '$_base/customers').single.queryParameters, {'page': 0, 'size': 20});
      expect(page.totalElements, 41);
      expect(page.totalPages, 3);
      expect(page.number, 1);
      expect(page.size, 20);
      expect(page.first, isFalse);
      expect(page.last, isFalse);
      expect(page.content.single.pointsBalance, 450);
      expect(page.content.single.lastActivityAt, isNotNull);
      expect(page.content.single.retentionStatus, 'ACTIVE');

      await api.fetchCustomers('p1', page: 2, size: 5);
      expect(http.calls('GET', '$_base/customers').last.queryParameters, {'page': 2, 'size': 5});
    });

    test('fetchCustomer parses one customer, including a missing activity date', () async {
      http.reply('GET', '$_base/customers/u1', {
        ..._customer,
        'displayName': null,
        'email': null,
        'lastActivityAt': null,
        'retentionStatus': null,
      });

      final c = await api.fetchCustomer('p1', 'u1');

      expect(c.displayName, isNull);
      expect(c.lastActivityAt, isNull);
      expect(c.retentionStatus, isNull);
      expect(c.pointsExpiringSoon30d, 40);
    });

    test('adjustPoints posts the delta and reason and parses the transaction', () async {
      http.reply('POST', '$_base/customers/u1/adjust', {
        'id': 'tx1',
        'type': 'ADJUSTMENT',
        'pointsDelta': -50,
        'balanceAfter': 400,
        'reason': 'Correction',
        'createdAt': '2026-10-12T10:00:00Z',
        'expiresAt': '2027-10-12T10:00:00Z',
        'bookingId': 'b1',
      });

      final tx = await api.adjustPoints('p1', 'u1', delta: -50, reason: 'Correction');

      expect(http.bodyOf('POST', '$_base/customers/u1/adjust'), {'delta': -50, 'reason': 'Correction'});
      expect(tx.type, LoyaltyTransactionType.adjustment);
      expect(tx.pointsDelta, -50);
      expect(tx.balanceAfter, 400);
      expect(tx.expiresAt, isNotNull);
      expect(tx.bookingId, 'b1');
    });

    test('every transaction type is understood and an unknown one is rejected', () {
      const wire = {
        'EARNED': LoyaltyTransactionType.earned,
        'BONUS': LoyaltyTransactionType.bonus,
        'REDEEMED': LoyaltyTransactionType.redeemed,
        'EXPIRED': LoyaltyTransactionType.expired,
        'REFUND': LoyaltyTransactionType.refund,
        'ADJUSTMENT': LoyaltyTransactionType.adjustment,
        'REVERSAL': LoyaltyTransactionType.reversal,
      };
      wire.forEach((name, type) => expect(LoyaltyTransactionType.fromWire(name), type));
      expect(wire.length, LoyaltyTransactionType.values.length);
      expect(() => LoyaltyTransactionType.fromWire('NOPE'), throwsArgumentError);
    });
  });

  group('rewards', () {
    test('fetchRewards parses rewards of every type', () async {
      http.reply('GET', '$_base/rewards', [
        _reward,
        {
          'id': 'r2',
          'name': '1000 off',
          'description': 'Big one',
          'type': 'FIXED_DISCOUNT',
          'pointsCost': 800,
          'discountAmount': 1000,
          'discountCurrency': 'KZT',
          'maxRedemptions': 10,
          'redemptionsCount': 0,
          'startsAt': '2026-10-01T00:00:00Z',
          'endsAt': '2026-12-31T00:00:00Z',
          'active': false,
          'terms': 'One per visit',
        },
        {'id': 'r3', 'name': 'Free cut', 'type': 'FREE_SERVICE', 'pointsCost': 900, 'serviceId': 's1',
          'redemptionsCount': 1, 'active': true},
        {'id': 'r4', 'name': 'Gift', 'type': 'CUSTOM', 'pointsCost': 100, 'redemptionsCount': 0, 'active': true},
      ]);

      final rewards = await api.fetchRewards('p1');

      expect(rewards.map((r) => r.type), [
        LoyaltyRewardType.percentageDiscount,
        LoyaltyRewardType.fixedDiscount,
        LoyaltyRewardType.freeService,
        LoyaltyRewardType.custom,
      ]);
      expect(rewards[0].discountPercentage, 10);
      expect(rewards[1].discountAmount, 1000);
      expect(rewards[1].maxRedemptions, 10);
      expect(rewards[1].startsAt, isNotNull);
      expect(rewards[1].active, isFalse);
      expect(rewards[1].terms, 'One per visit');
      expect(rewards[2].serviceId, 's1');
    });

    test('create and update send the draft; the wire name of each type is stable', () async {
      http
        ..reply('POST', '$_base/rewards', _reward)
        ..reply('PUT', '$_base/rewards/r1', _reward);
      final draft = LoyaltyReward(
        name: '10% off',
        type: LoyaltyRewardType.percentageDiscount,
        pointsCost: 300,
        discountPercentage: 10,
        startsAt: DateTime.utc(2026, 10, 1),
      );

      await api.createReward('p1', draft);
      await api.updateReward('p1', 'r1', draft);

      final body = http.bodyOf('POST', '$_base/rewards');
      expect(body['type'], 'PERCENTAGE_DISCOUNT');
      expect(body['startsAt'], '2026-10-01T00:00:00.000Z');
      expect(body['endsAt'], isNull);
      expect(http.bodyOf('PUT', '$_base/rewards/r1'), body);

      expect(LoyaltyRewardType.fixedDiscount.toWire(), 'FIXED_DISCOUNT');
      expect(LoyaltyRewardType.freeService.toWire(), 'FREE_SERVICE');
      expect(LoyaltyRewardType.custom.toWire(), 'CUSTOM');
      expect(() => LoyaltyRewardType.fromWire('NOPE'), throwsArgumentError);
    });

    test('activate, deactivate and delete use their own endpoints', () async {
      http
        ..reply('POST', '$_base/rewards/r1/activate', _reward)
        ..reply('POST', '$_base/rewards/r1/deactivate', {..._reward, 'active': false})
        ..reply('DELETE', '$_base/rewards/r1', <String, Object?>{});

      expect((await api.activateReward('p1', 'r1')).active, isTrue);
      expect((await api.deactivateReward('p1', 'r1')).active, isFalse);
      await api.deleteReward('p1', 'r1');
      expect(http.calls('DELETE', '$_base/rewards/r1'), hasLength(1));
    });
  });

  group('redemptions', () {
    test('fetchRedemptions pages and parses the status of each', () async {
      http.reply('GET', '$_base/redemptions', _page([
        _redemption,
        {
          ..._redemption,
          'id': 'red2',
          'status': 'APPLIED',
          'expiresAt': null,
          'appliedBookingId': 'b1',
          'appliedAt': '2026-10-13T10:00:00Z',
        },
        {..._redemption, 'id': 'red3', 'status': 'CANCELLED'},
        {..._redemption, 'id': 'red4', 'status': 'EXPIRED'},
      ]));

      final page = await api.fetchRedemptions('p1', page: 1, size: 4);

      expect(http.calls('GET', '$_base/redemptions').single.queryParameters, {'page': 1, 'size': 4});
      expect(page.content.map((r) => r.status), LoyaltyRedemptionStatus.values);
      expect(page.content[1].appliedBookingId, 'b1');
      expect(page.content[1].appliedAt, isNotNull);
      expect(page.content[1].expiresAt, isNull);
      expect(() => LoyaltyRedemptionStatus.fromWire('NOPE'), throwsArgumentError);
    });

    test('applyRedemption and cancelRedemption post their payloads', () async {
      http
        ..reply('POST', '$_base/redemptions/ABC123/apply', {..._redemption, 'status': 'APPLIED'})
        ..reply('POST', '$_base/redemptions/red1/cancel', {..._redemption, 'status': 'CANCELLED'});

      final applied = await api.applyRedemption('p1', 'ABC123', bookingId: 'b1');
      expect(http.bodyOf('POST', '$_base/redemptions/ABC123/apply'), {'bookingId': 'b1'});
      expect(applied.status, LoyaltyRedemptionStatus.applied);

      await api.cancelRedemption('p1', 'red1', reason: 'Customer asked');
      expect(http.bodyOf('POST', '$_base/redemptions/red1/cancel'), {'reason': 'Customer asked'});

      http.requests.clear();
      await api.cancelRedemption('p1', 'red1');
      expect(http.bodyOf('POST', '$_base/redemptions/red1/cancel'), {'reason': null});
    });
  });

  group('errors', () {
    test('an HTTP error becomes a LoyaltyAdminException with the status and the server message', () async {
      http.fail('GET', '$_base/settings', 400, message: 'Name is required');
      final e = await _failure(() => api.fetchSettings('p1'));
      expect(e.statusCode, 400);
      expect(e.serverMessage, 'Name is required');
    });

    test('a body that is not an object has no server message', () async {
      http.reply('DELETE', '$_base/rewards/r1', 'oops', status: 500);
      final e = await _failure(() => api.deleteReward('p1', 'r1'));
      expect(e.statusCode, 500);
      expect(e.serverMessage, isNull);
    });
  });
}
