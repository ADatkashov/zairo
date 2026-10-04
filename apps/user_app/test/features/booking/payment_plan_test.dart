import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/booking/data/models/payment_plan.dart';

void main() {
  group('PaymentPlan.fromPolicy', () {
    test('no policy / NO_PAYMENT is free to book, everything at the venue', () {
      for (final policy in [null, const DepositPolicy(depositType: 'NO_PAYMENT')]) {
        final plan = PaymentPlan.fromPolicy(policy, 100);
        expect(plan.mode, PaymentMode.free);
        expect(plan.dueNow, 0);
        expect(plan.atVenue, 100);
      }
    });

    test('FULL_PAYMENT charges the whole price now', () {
      final plan = PaymentPlan.fromPolicy(const DepositPolicy(depositType: 'FULL_PAYMENT'), 100);
      expect(plan.mode, PaymentMode.full);
      expect(plan.dueNow, 100);
      expect(plan.atVenue, 0);
    });

    test('percentage deposit splits now / venue and rounds like the backend', () {
      final plan = PaymentPlan.fromPolicy(
        const DepositPolicy(depositType: 'DEPOSIT', depositValueType: 'PERCENTAGE', depositValue: 30),
        99.99,
      );
      expect(plan.mode, PaymentMode.deposit);
      expect(plan.dueNow, 30.0);
      expect(plan.atVenue, 69.99);
      expect(plan.total, 99.99);
    });

    test('fixed deposit is capped at the price', () {
      final plan = PaymentPlan.fromPolicy(
        const DepositPolicy(depositType: 'DEPOSIT', depositValueType: 'FIXED_AMOUNT', depositValue: 500),
        200,
      );
      expect(plan.mode, PaymentMode.full);
      expect(plan.dueNow, 200);
    });

    test('a 100% deposit is a full payment', () {
      final plan = PaymentPlan.fromPolicy(
        const DepositPolicy(depositType: 'DEPOSIT', depositValueType: 'PERCENTAGE', depositValue: 100),
        50,
      );
      expect(plan.mode, PaymentMode.full);
    });
  });

  group('PaymentPlan.fromAmounts', () {
    test('derives the venue share from total - deposit, not remainingAmount', () {
      final plan = PaymentPlan.fromAmounts(total: 100, deposit: 25);
      expect(plan.mode, PaymentMode.deposit);
      expect(plan.atVenue, 75);
    });

    test('null or zero deposit is free', () {
      expect(PaymentPlan.fromAmounts(total: 100, deposit: null).mode, PaymentMode.free);
      expect(PaymentPlan.fromAmounts(total: 100, deposit: 0).mode, PaymentMode.free);
    });
  });
}
