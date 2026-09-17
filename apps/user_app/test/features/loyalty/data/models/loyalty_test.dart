import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/loyalty/data/models/loyalty.dart';
import 'package:zairo/features/loyalty/data/models/page.dart';

void main() {
  group('LoyaltyBusinessSummary', () {
    test('parses a full JSON row', () {
      final summary = LoyaltyBusinessSummary.fromJson({
        'providerId': 'provider-1',
        'providerName': 'Glow Salon',
        'programEnabled': true,
        'pointsBalance': 120,
        'lifetimeEarned': 500,
        'tierName': 'Gold',
        'pointsExpiringSoon30d': 30,
      });

      expect(summary.providerId, 'provider-1');
      expect(summary.providerName, 'Glow Salon');
      expect(summary.programEnabled, isTrue);
      expect(summary.pointsBalance, 120);
      expect(summary.lifetimeEarned, 500);
      expect(summary.tierName, 'Gold');
      expect(summary.pointsExpiringSoon30d, 30);
    });

    test('tolerates null providerName/tierName', () {
      final summary = LoyaltyBusinessSummary.fromJson({
        'providerId': 'provider-1',
        'providerName': null,
        'programEnabled': false,
        'pointsBalance': 0,
        'lifetimeEarned': 0,
        'tierName': null,
        'pointsExpiringSoon30d': 0,
      });

      expect(summary.providerName, isNull);
      expect(summary.tierName, isNull);
      expect(summary.programEnabled, isFalse);
    });
  });

  group('LoyaltyBusinessDetail', () {
    test('parses a full JSON response including nextMilestone', () {
      final detail = LoyaltyBusinessDetail.fromJson({
        'providerId': 'provider-1',
        'providerName': 'Glow Salon',
        'programEnabled': true,
        'programName': 'Glow Rewards',
        'programDescription': 'Earn points on every visit',
        'pointsBalance': 120,
        'lifetimeEarned': 500,
        'lifetimeRedeemed': 380,
        'completedVisits': 4,
        'tierName': 'Gold',
        'pointsExpiringSoon30d': 30,
        'waysToEarn': ['10 points per completed booking', '50 bonus points on your first booking'],
        'nextMilestone': {
          'label': 'Loyal customer',
          'visitsRequired': 5,
          'visitsRemaining': 1,
          'pointsAwarded': 50,
        },
        'availableRewardsCount': 3,
      });

      expect(detail.programName, 'Glow Rewards');
      expect(detail.waysToEarn, hasLength(2));
      expect(detail.nextMilestone, isNotNull);
      expect(detail.nextMilestone!.label, 'Loyal customer');
      expect(detail.nextMilestone!.visitsRemaining, 1);
      expect(detail.availableRewardsCount, 3);
    });

    test('parses the all-zero shape for a business with no account/program', () {
      final detail = LoyaltyBusinessDetail.fromJson({
        'providerId': 'provider-2',
        'providerName': null,
        'programEnabled': false,
        'programName': null,
        'programDescription': null,
        'pointsBalance': 0,
        'lifetimeEarned': 0,
        'lifetimeRedeemed': 0,
        'completedVisits': 0,
        'tierName': null,
        'pointsExpiringSoon30d': 0,
        'waysToEarn': <String>[],
        'nextMilestone': null,
        'availableRewardsCount': 0,
      });

      expect(detail.programEnabled, isFalse);
      expect(detail.waysToEarn, isEmpty);
      expect(detail.nextMilestone, isNull);
    });
  });

  group('LoyaltyReward', () {
    test('parses a FIXED_DISCOUNT reward', () {
      final reward = LoyaltyReward.fromJson({
        'id': 'reward-1',
        'name': '5 off',
        'description': 'Five dollars off your next visit',
        'type': 'FIXED_DISCOUNT',
        'pointsCost': 200,
        'discountAmount': 5.0,
        'discountCurrency': 'USD',
        'discountPercentage': null,
        'serviceId': null,
        'endsAt': '2026-12-31T00:00:00Z',
        'terms': 'One per customer',
        'affordable': true,
      });

      expect(reward.type, LoyaltyRewardType.fixedDiscount);
      expect(reward.discountAmount, 5.0);
      expect(reward.discountCurrency, 'USD');
      expect(reward.endsAt, DateTime.parse('2026-12-31T00:00:00Z'));
      expect(reward.affordable, isTrue);
    });

    test('round-trips every LoyaltyRewardType wire value', () {
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
  });

  group('LoyaltyTransaction', () {
    test('preserves a signed pointsDelta for a spend', () {
      final tx = LoyaltyTransaction.fromJson({
        'id': 'tx-1',
        'type': 'REDEEMED',
        'pointsDelta': -200,
        'balanceAfter': 300,
        'reason': 'Redeemed: 5 off',
        'createdAt': '2026-01-01T10:00:00Z',
        'expiresAt': null,
        'bookingId': null,
      });

      expect(tx.type, LoyaltyTransactionType.redeemed);
      expect(tx.pointsDelta, -200);
      expect(tx.balanceAfter, 300);
    });

    test('preserves a signed pointsDelta for an earn', () {
      final tx = LoyaltyTransaction.fromJson({
        'id': 'tx-2',
        'type': 'EARNED',
        'pointsDelta': 50,
        'balanceAfter': 500,
        'reason': 'Completed booking',
        'createdAt': '2026-01-01T10:00:00Z',
        'expiresAt': '2026-07-01T10:00:00Z',
        'bookingId': 'booking-1',
      });

      expect(tx.pointsDelta, 50);
      expect(tx.expiresAt, DateTime.parse('2026-07-01T10:00:00Z'));
      expect(tx.bookingId, 'booking-1');
    });
  });

  group('LoyaltyRedemption', () {
    test('parses an ACTIVE redemption', () {
      final redemption = LoyaltyRedemption.fromJson({
        'id': 'redemption-1',
        'providerId': 'provider-1',
        'providerName': 'Glow Salon',
        'rewardId': 'reward-1',
        'rewardName': '5 off',
        'rewardType': 'FIXED_DISCOUNT',
        'pointsSpent': 200,
        'code': 'AB3D9F2K',
        'status': 'ACTIVE',
        'createdAt': '2026-01-01T10:00:00Z',
        'expiresAt': '2026-02-01T10:00:00Z',
        'appliedBookingId': null,
        'appliedAt': null,
      });

      expect(redemption.status, LoyaltyRedemptionStatus.active);
      expect(redemption.code, 'AB3D9F2K');
      expect(redemption.appliedAt, isNull);
    });
  });

  group('Page', () {
    test('parses content and pagination metadata via the given item mapper', () {
      final page = Page<LoyaltyTransaction>.fromJson({
        'content': [
          {
            'id': 'tx-1',
            'type': 'EARNED',
            'pointsDelta': 10,
            'balanceAfter': 10,
            'reason': 'Completed booking',
            'createdAt': '2026-01-01T10:00:00Z',
            'expiresAt': null,
            'bookingId': null,
          },
        ],
        'totalElements': 1,
        'totalPages': 1,
        'number': 0,
        'size': 20,
        'first': true,
        'last': true,
      }, (json) => LoyaltyTransaction.fromJson(json));

      expect(page.content, hasLength(1));
      expect(page.content.first.pointsDelta, 10);
      expect(page.totalElements, 1);
      expect(page.first, isTrue);
      expect(page.last, isTrue);
    });
  });
}
