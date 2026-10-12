import 'package:business_admin/features/billing/data/billing_api.dart';
import 'package:business_admin/features/billing/data/billing_exception.dart';
import 'package:business_admin/features/billing/data/models/subscription.dart';
import 'package:business_admin/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';

Map<String, Object?> _subscription({
  String plan = 'PRO',
  String status = 'ACTIVE',
  int maxBookings = 2147483647,
  Object? grace,
  String? checkoutUrl,
}) =>
    {
      'id': 'sub1',
      'ownerUserId': 'o1',
      'plan': plan,
      'status': status,
      'limits': {
        'maxProviders': 5,
        'maxStaffPerProvider': 20,
        'maxBookingsPerMonth': maxBookings,
        'recurringScheduleAllowed': plan == 'PRO',
      },
      'currentPeriodStart': '2026-10-01T00:00:00Z',
      'currentPeriodEnd': '2026-10-31T00:00:00Z',
      'gracePeriodEndsAt': grace,
      'cancelAtPeriodEnd': false,
      'checkoutUrl': checkoutUrl,
      'proMonthlyPrice': 29.5,
      'currency': 'USD',
    };

void main() {
  late FakeHttp http;
  late BillingApi api;

  setUp(() {
    http = FakeHttp();
    api = BillingApi(http.client());
  });

  test('getMine parses the plan, its limits and the billing period', () async {
    http.reply('GET', '/subscriptions/me', _subscription());

    final s = await api.getMine();

    expect([s.id, s.ownerUserId, s.plan, s.status], ['sub1', 'o1', 'PRO', 'ACTIVE']);
    expect(s.isPro, isTrue);
    expect(s.limits.maxProviders, 5);
    expect(s.limits.maxStaffPerProvider, 20);
    expect(s.limits.recurringScheduleAllowed, isTrue);
    expect(s.limits.isUnlimitedBookings, isTrue);
    expect(s.currentPeriodStart, DateTime.utc(2026, 10, 1));
    expect(s.currentPeriodEnd, DateTime.utc(2026, 10, 31));
    expect(s.gracePeriodEndsAt, isNull);
    expect(s.cancelAtPeriodEnd, isFalse);
    expect(s.proMonthlyPrice, 29.5);
    expect(s.currency, 'USD');
  });

  test('a free plan is not Pro and has a finite booking limit', () async {
    http.reply('GET', '/subscriptions/me', _subscription(plan: 'FREE', maxBookings: 30));

    final s = await api.getMine();

    expect(s.isPro, isFalse);
    expect(s.limits.isUnlimitedBookings, isFalse);
    expect(s.limits.maxBookingsPerMonth, 30);
    expect(s.limits.recurringScheduleAllowed, isFalse);
  });

  test('a past-due subscription carries its grace deadline and a retry checkout link', () async {
    http.reply('GET', '/subscriptions/me',
        _subscription(status: 'PAST_DUE', grace: '2026-11-03T00:00:00Z', checkoutUrl: 'https://pay.example/c'));

    final s = await api.getMine();

    expect(s.status, 'PAST_DUE');
    expect(s.gracePeriodEndsAt, DateTime.utc(2026, 11, 3));
    expect(s.checkoutUrl, 'https://pay.example/c');
  });

  test('upgrade, downgrade and retry post to their own endpoints and return the subscription', () async {
    http
      ..reply('POST', '/subscriptions/upgrade', _subscription(checkoutUrl: 'https://pay.example/up'))
      ..reply('POST', '/subscriptions/downgrade', _subscription(plan: 'FREE'))
      ..reply('POST', '/subscriptions/retry-charge', _subscription());

    expect((await api.upgradeToPro()).checkoutUrl, 'https://pay.example/up');
    expect((await api.downgradeToFree()).isPro, isFalse);
    expect((await api.retryPastDueCharge()).isPro, isTrue);
  });

  test('getPaymentMethod parses a saved card and an empty one', () async {
    http.reply('GET', '/subscriptions/me/payment-method',
        {'saved': true, 'brand': 'VISA', 'last4': '4242', 'addedAt': '2026-09-01T00:00:00Z', 'autoRenew': true});
    final card = await api.getPaymentMethod();
    expect([card.saved, card.brand, card.last4, card.autoRenew], [true, 'VISA', '4242', true]);
    expect(card.addedAt, DateTime.utc(2026, 9, 1));

    http.reply('GET', '/subscriptions/me/payment-method', {'saved': false});
    final none = await api.getPaymentMethod();
    expect([none.saved, none.brand, none.last4, none.addedAt, none.autoRenew], [false, null, null, null, false]);
  });

  test('removePaymentMethod deletes the saved card', () async {
    http.reply('DELETE', '/subscriptions/me/payment-method', <String, Object?>{});

    await api.removePaymentMethod();

    expect(http.calls('DELETE', '/subscriptions/me/payment-method'), hasLength(1));
  });

  test('listCharges parses the billing history', () async {
    http.reply('GET', '/subscriptions/me/charges', [
      {'id': 'c1', 'amount': 29.5, 'currency': 'USD', 'status': 'SUCCEEDED', 'createdAt': '2026-10-01T00:00:00Z'},
      {'id': 'c2', 'amount': 29, 'currency': 'USD', 'status': 'FAILED', 'createdAt': '2026-09-01T00:00:00Z'},
    ]);

    final charges = await api.listCharges();

    expect(charges.map((c) => c.id), ['c1', 'c2']);
    expect(charges.map((c) => c.amount), [29.5, 29.0]);
    expect(charges.map((c) => c.status), ['SUCCEEDED', 'FAILED']);
    expect(charges.first.createdAt, DateTime.utc(2026, 10, 1));
    expect(charges.first.currency, 'USD');
  });

  test('every plan-limit error has its own localized message', () {
    final l10n = AppLocalizationsEn();
    final expected = {
      SubscriptionErrorKey.providerLimitReached: l10n.errorProviderLimitReached,
      SubscriptionErrorKey.staffLimitReached: l10n.errorStaffLimitReached,
      SubscriptionErrorKey.bookingLimitReached: l10n.errorBookingLimitReached,
      SubscriptionErrorKey.featureRequiresUpgrade: l10n.errorFeatureRequiresUpgrade,
    };

    expect(expected.keys.toSet(), SubscriptionErrorKey.values.toSet());
    expected.forEach((key, message) => expect(BillingException(key).localizedMessage(l10n), message));
    expect(expected.values.toSet(), hasLength(4));
  });

  test('PlanLimits treats a very large booking cap as unlimited and a normal one as limited', () {
    const unlimited = PlanLimits(
        maxProviders: 1, maxStaffPerProvider: 1, maxBookingsPerMonth: 2147483647, recurringScheduleAllowed: true);
    const limited = PlanLimits(
        maxProviders: 1, maxStaffPerProvider: 1, maxBookingsPerMonth: 2147483646, recurringScheduleAllowed: false);

    expect(unlimited.isUnlimitedBookings, isTrue);
    expect(limited.isUnlimitedBookings, isFalse);
  });
}
