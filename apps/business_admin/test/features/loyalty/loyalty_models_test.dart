import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_customer.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_milestone.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_overview.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_page.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_redemption.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_reward.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_settings.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_tier.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_transaction.dart';

void main() {
  group('LoyaltySettings', () {
    test('fromJson parses every field, nulls included', () {
      final json = {
        'providerId': 'p1',
        'enabled': true,
        'name': 'Glow Rewards',
        'description': null,
        'fixedPointsPerBooking': 10,
        'pointsPerCurrencyUnit': 0.5,
        'firstBookingBonusPoints': 50,
        'repeatVisitBonusPoints': 20,
        'repeatVisitThreshold': 3,
        'reviewBonusPoints': 15,
        'pointsPerCurrencyUnitRedemption': null,
        'minRedemptionPoints': null,
        'maxRedemptionPointsPerBooking': null,
        'pointsExpireEnabled': false,
        'pointsExpirationMonths': null,
        'dailyEarningPointsCap': null,
        'monthlyEarningPointsCap': null,
      };

      final settings = LoyaltySettings.fromJson(json);

      expect(settings.providerId, 'p1');
      expect(settings.enabled, isTrue);
      expect(settings.name, 'Glow Rewards');
      expect(settings.description, isNull);
      expect(settings.fixedPointsPerBooking, 10);
      expect(settings.pointsPerCurrencyUnit, 0.5);
      expect(settings.repeatVisitThreshold, 3);
      expect(settings.pointsExpireEnabled, isFalse);
      expect(settings.pointsExpirationMonths, isNull);
    });

    test('toUpdateJson emits every field except providerId, nulls included', () {
      const settings = LoyaltySettings(
        providerId: 'p1',
        enabled: true,
        name: 'Glow Rewards',
        fixedPointsPerBooking: 10,
        pointsPerCurrencyUnit: 0.5,
        firstBookingBonusPoints: 0,
        repeatVisitBonusPoints: 0,
        repeatVisitThreshold: 2,
        reviewBonusPoints: 0,
        pointsExpireEnabled: false,
      );

      final json = settings.toUpdateJson();

      expect(json.containsKey('providerId'), isFalse);
      expect(json.length, 17);
      expect(json['birthdayBonusPoints'], 0);
      expect(json['enabled'], isTrue);
      expect(json['name'], 'Glow Rewards');
      expect(json['description'], isNull);
      expect(json['pointsPerCurrencyUnitRedemption'], isNull);
      expect(json['minRedemptionPoints'], isNull);
      expect(json['pointsExpirationMonths'], isNull);
    });

    test('copyWith clears an optional field when asked', () {
      const settings = LoyaltySettings(
        providerId: 'p1',
        enabled: true,
        name: 'Glow Rewards',
        fixedPointsPerBooking: 10,
        pointsPerCurrencyUnit: 0.5,
        firstBookingBonusPoints: 0,
        repeatVisitBonusPoints: 0,
        repeatVisitThreshold: 2,
        reviewBonusPoints: 0,
        pointsExpireEnabled: true,
        pointsExpirationMonths: 12,
      );

      final cleared = settings.copyWith(pointsExpireEnabled: false, clearPointsExpirationMonths: true);

      expect(cleared.pointsExpireEnabled, isFalse);
      expect(cleared.pointsExpirationMonths, isNull);
      // Unrelated fields are untouched.
      expect(cleared.name, 'Glow Rewards');
    });
  });

  group('LoyaltyMilestone', () {
    test('fromJson/toRequestJson round trip drops id on write', () {
      final milestone = LoyaltyMilestone.fromJson({
        'id': 'm1',
        'visitsRequired': 5,
        'pointsAwarded': 100,
        'label': 'Regular',
      });

      expect(milestone.id, 'm1');
      expect(milestone.visitsRequired, 5);

      final requestJson = milestone.toRequestJson();
      expect(requestJson.containsKey('id'), isFalse);
      expect(requestJson, {'visitsRequired': 5, 'pointsAwarded': 100, 'label': 'Regular'});
    });
  });

  group('LoyaltyTier', () {
    test('fromJson/toRequestJson round trip drops id on write', () {
      final tier = LoyaltyTier.fromJson({'id': 't1', 'name': 'Gold', 'minLifetimePoints': 1000});

      expect(tier.id, 't1');
      expect(tier.toRequestJson(), {'name': 'Gold', 'minLifetimePoints': 1000});
    });
  });

  group('LoyaltyOverview', () {
    test('fromJson parses every aggregate', () {
      final overview = LoyaltyOverview.fromJson({
        'totalMembers': 120,
        'activeMembers': 80,
        'totalPointsIssued': 50000,
        'totalPointsRedeemed': 12000,
        'outstandingPointsLiability': 38000,
        'rewardsRedeemed': 45,
      });

      expect(overview.totalMembers, 120);
      expect(overview.outstandingPointsLiability, 38000);
      expect(overview.rewardsRedeemed, 45);
    });
  });

  group('LoyaltyCustomerInsight', () {
    test('fromJson handles a null retentionStatus and lastActivityAt', () {
      final customer = LoyaltyCustomerInsight.fromJson({
        'userId': 'u1',
        'displayName': 'Aigerim',
        'email': null,
        'pointsBalance': 340,
        'lifetimeEarned': 900,
        'lifetimeRedeemed': 560,
        'completedVisits': 12,
        'lastActivityAt': null,
        'pointsExpiringSoon30d': 0,
        'retentionStatus': null,
      });

      expect(customer.displayName, 'Aigerim');
      expect(customer.pointsBalance, 340);
      expect(customer.lastActivityAt, isNull);
      expect(customer.retentionStatus, isNull);
    });

    test('fromJson parses a known retention status and lastActivityAt', () {
      final customer = LoyaltyCustomerInsight.fromJson({
        'userId': 'u2',
        'displayName': null,
        'email': 'u2@example.com',
        'pointsBalance': 10,
        'lifetimeEarned': 10,
        'lifetimeRedeemed': 0,
        'completedVisits': 1,
        'lastActivityAt': '2026-08-01T10:00:00Z',
        'pointsExpiringSoon30d': 5,
        'retentionStatus': 'AT_RISK',
      });

      expect(customer.retentionStatus, 'AT_RISK');
      expect(customer.lastActivityAt, DateTime.parse('2026-08-01T10:00:00Z'));
    });
  });

  group('LoyaltyReward', () {
    test('fromJson/toWire round trip for every LoyaltyRewardType', () {
      for (final entry in {
        'FIXED_DISCOUNT': LoyaltyRewardType.fixedDiscount,
        'PERCENTAGE_DISCOUNT': LoyaltyRewardType.percentageDiscount,
        'FREE_SERVICE': LoyaltyRewardType.freeService,
        'CUSTOM': LoyaltyRewardType.custom,
      }.entries) {
        expect(LoyaltyRewardType.fromWire(entry.key), entry.value);
        expect(entry.value.toWire(), entry.key);
      }
    });

    test('fromJson parses a fixed-discount reward', () {
      final reward = LoyaltyReward.fromJson({
        'id': 'r1',
        'name': '5000 off',
        'description': null,
        'type': 'FIXED_DISCOUNT',
        'pointsCost': 500,
        'discountAmount': 5000.0,
        'discountCurrency': 'KZT',
        'discountPercentage': null,
        'serviceId': null,
        'maxRedemptions': 100,
        'redemptionsCount': 3,
        'startsAt': null,
        'endsAt': null,
        'active': true,
        'terms': null,
      });

      expect(reward.type, LoyaltyRewardType.fixedDiscount);
      expect(reward.discountAmount, 5000.0);
      expect(reward.discountCurrency, 'KZT');
      expect(reward.redemptionsCount, 3);
      expect(reward.active, isTrue);
    });

    test('toRequestJson never includes id/redemptionsCount/active', () {
      const reward = LoyaltyReward(
        id: 'r1',
        name: 'Free haircut',
        type: LoyaltyRewardType.freeService,
        pointsCost: 800,
        serviceId: 's1',
        redemptionsCount: 5,
        active: false,
      );

      final json = reward.toRequestJson();

      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('redemptionsCount'), isFalse);
      expect(json.containsKey('active'), isFalse);
      expect(json['serviceId'], 's1');
      expect(json['type'], 'FREE_SERVICE');
    });
  });

  group('LoyaltyRedemption', () {
    test('fromJson/fromWire round trip for every LoyaltyRedemptionStatus', () {
      for (final entry in {
        'ACTIVE': LoyaltyRedemptionStatus.active,
        'APPLIED': LoyaltyRedemptionStatus.applied,
        'CANCELLED': LoyaltyRedemptionStatus.cancelled,
        'EXPIRED': LoyaltyRedemptionStatus.expired,
      }.entries) {
        expect(LoyaltyRedemptionStatus.fromWire(entry.key), entry.value);
      }
    });

    test('fromJson parses an applied redemption', () {
      final redemption = LoyaltyRedemption.fromJson({
        'id': 'red1',
        'userId': 'u1',
        'rewardId': 'r1',
        'rewardName': '5000 off',
        'pointsSpent': 500,
        'code': 'AB3D9F2K',
        'status': 'APPLIED',
        'createdAt': '2026-08-01T10:00:00Z',
        'expiresAt': null,
        'appliedBookingId': 'b1',
        'appliedAt': '2026-08-02T10:00:00Z',
      });

      expect(redemption.status, LoyaltyRedemptionStatus.applied);
      expect(redemption.code, 'AB3D9F2K');
      expect(redemption.appliedBookingId, 'b1');
    });
  });

  group('LoyaltyTransaction', () {
    test('fromJson parses an ADJUSTMENT transaction', () {
      final tx = LoyaltyTransaction.fromJson({
        'id': 'tx1',
        'type': 'ADJUSTMENT',
        'pointsDelta': -50,
        'balanceAfter': 250,
        'reason': 'Goodwill correction',
        'createdAt': '2026-08-01T10:00:00Z',
        'expiresAt': null,
        'bookingId': null,
      });

      expect(tx.type, LoyaltyTransactionType.adjustment);
      expect(tx.pointsDelta, -50);
      expect(tx.balanceAfter, 250);
      expect(tx.reason, 'Goodwill correction');
    });
  });

  group('LoyaltyPage', () {
    test('fromJson parses the Spring Page envelope', () {
      final page = LoyaltyPage.fromJson(
        {
          'content': [
            {'id': 'a'},
            {'id': 'b'},
          ],
          'totalElements': 22,
          'totalPages': 2,
          'number': 0,
          'size': 20,
          'first': true,
          'last': false,
        },
        (json) => json['id'] as String,
      );

      expect(page.content, ['a', 'b']);
      expect(page.totalElements, 22);
      expect(page.totalPages, 2);
      expect(page.first, isTrue);
      expect(page.last, isFalse);
    });
  });
}
