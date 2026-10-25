import 'package:business_admin/features/dashboard/data/revenue_pulse.dart';
import 'package:business_admin/features/salon/data/models/business_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 25, 12);

DateTime _daysAgo(int n) => DateTime(2026, 10, 25 - n);

BusinessAnalyticsRevenue _revenue({
  Map<int, double> byDaysAgo = const {},
  List<RevenueByService> services = const [],
  String? currency = 'KZT',
}) => BusinessAnalyticsRevenue(
  totalRevenue: byDaysAgo.values.fold(0, (a, b) => a + b),
  currency: currency,
  revenueByDay: [for (final e in byDaysAgo.entries) DailyAmount(date: _daysAgo(e.key), amount: e.value)],
  revenueByService: services,
  revenueByStaff: const [],
  revenueRecovered: 0,
);

RevenuePulse _pulse(List<BusinessAnalyticsRevenue> long, [List<BusinessAnalyticsRevenue>? short]) =>
    RevenuePulse.fromRevenue(lastTwoPeriods: long, lastPeriod: short ?? long, now: _now, topServices: 2);

CustomerListItem _customer(String id, double spent, {String? name, String? email, String? currency = 'KZT'}) =>
    CustomerListItem(
      userId: id,
      displayName: name,
      email: email,
      retentionStatus: CustomerRetentionStatus.active,
      totalSpent: spent,
      currency: currency,
    );

void main() {
  group('RevenuePulse periods', () {
    // Every day falls in exactly one bucket below; the numbers in the comments are the expected sums.
    final pulse = _pulse([
      _revenue(
        byDaysAgo: {
          0: 100, // today
          1: 50, // yesterday
          6: 30, // last 7 days (oldest day of it)
          7: 20, // previous 7 days
          13: 10, // previous 7 days (oldest day of it)
          14: 5, // last 30, neither 7-day window
          29: 7, // last 30 (oldest day of it)
          30: 9, // previous 30
          59: 11, // previous 30 (oldest day of it)
          60: 999, // older than the window: ignored
        },
      ),
    ]);

    test('today and yesterday', () {
      expect(pulse.today, 100);
      expect(pulse.yesterday, 50);
    });

    test('the last 7 days and the 7 before', () {
      expect(pulse.last7, 180);
      expect(pulse.previous7, 30);
    });

    test('the last 30 days and the 30 before', () {
      expect(pulse.last30, 222);
      expect(pulse.previous30, 20);
    });

    test('trend is the last N days, oldest first, ending today', () {
      final trend = pulse.trend(14);
      expect(trend, hasLength(14));
      expect(trend.last, 100);
      expect(trend[trend.length - 2], 50);
      expect(trend.first, 10, reason: '13 days ago');
      expect(pulse.trend(pulseDays), hasLength(pulseDays));
    });

    test('days the server did not list are zero', () {
      // 6 days ago earned 30, the four days after it nothing, then yesterday and today.
      expect(pulse.trend(7), [30, 0, 0, 0, 0, 50, 100]);
    });

    test('businesses add up on the same day', () {
      final two = _pulse([_revenue(byDaysAgo: {0: 100}), _revenue(byDaysAgo: {0: 40, 1: 5})]);
      expect(two.today, 140);
      expect(two.yesterday, 5);
    });

    test('a visit late in the evening is still the same calendar day', () {
      final late = RevenuePulse.fromRevenue(
        lastTwoPeriods: [
          BusinessAnalyticsRevenue(
            totalRevenue: 1,
            revenueByDay: [DailyAmount(date: DateTime(2026, 10, 25, 23, 59), amount: 1)],
            revenueByService: const [],
            revenueByStaff: const [],
            revenueRecovered: 0,
          ),
        ],
        lastPeriod: const [],
        now: DateTime(2026, 10, 25, 0, 5),
      );
      expect(late.today, 1);
    });

    test('is empty only when nothing was earned in the whole window', () {
      expect(_pulse([_revenue()]).isEmpty, isTrue);
      expect(_pulse(const []).isEmpty, isTrue);
      expect(pulse.isEmpty, isFalse);
      expect(_pulse([_revenue(byDaysAgo: {45: 3})]).isEmpty, isFalse, reason: 'earned in the previous period only');
    });

    test('change is a percentage, and absent without a baseline', () {
      expect(RevenuePulse.change(180, 30), 500);
      expect(RevenuePulse.change(50, 100), -50);
      expect(RevenuePulse.change(10, 10), 0);
      expect(RevenuePulse.change(10, 0), isNull);
    });

    test('the currency is the first one the server names', () {
      expect(_pulse([_revenue(currency: null), _revenue(currency: 'USD')]).currency, 'USD');
      expect(_pulse([_revenue(currency: null)]).currency, isNull);
    });
  });

  group('RevenuePulse service split', () {
    RevenueByService s(String id, String? title, double amount) =>
        RevenueByService(serviceId: id, title: title, amount: amount, bookingCount: 1);

    test('merges a service across businesses, ranks it, and folds the rest into Other', () {
      final pulse = _pulse(
        const [],
        [
          _revenue(services: [s('a', 'Haircut', 100), s('b', 'Colour', 120), s('c', 'Wash', 30)]),
          _revenue(services: [s('a', 'Haircut', 50), s('d', 'Styling', 20)]),
        ],
      );
      expect(pulse.services.map((e) => (e.title, e.amount, e.isOther)), [
        ('Haircut', 150.0, false),
        ('Colour', 120.0, false),
        (null, 50.0, true),
      ]);
      expect(pulse.serviceTotal, 320);
    });

    test('without more services than the limit there is no Other slice', () {
      final pulse = _pulse(const [], [_revenue(services: [s('a', 'Haircut', 10)])]);
      expect(pulse.services.single.isOther, isFalse);
    });

    test('a service earning nothing is left out, and the first known title wins', () {
      final pulse = _pulse(
        const [],
        [
          _revenue(services: [s('a', null, 10), s('z', 'Free', 0)]),
          _revenue(services: [s('a', 'Haircut', 5)]),
        ],
      );
      expect(pulse.services.single.title, 'Haircut');
      expect(pulse.services.single.amount, 15);
    });

    test('no services at all', () {
      expect(_pulse(const [], const []).services, isEmpty);
      expect(_pulse(const [], const []).serviceTotal, 0);
    });
  });

  group('CustomerRanking', () {
    test('ranks by spend, keeps the top few, and totals everyone', () {
      final ranking = CustomerRanking.fromLists([
        [_customer('u1', 100, name: 'Ana'), _customer('u2', 400, name: 'Bek'), _customer('u3', 300, name: 'Cem')],
        [_customer('u4', 200, name: 'Dan'), _customer('u5', 0, name: 'Free')],
      ]);
      expect(ranking.top.map((c) => c.name), ['Bek', 'Cem', 'Dan']);
      expect(ranking.total, 1000, reason: 'includes customers outside the top, not those who spent nothing');
      expect(ranking.shareOf(ranking.top.first), 0.4);
      expect(ranking.isEmpty, isFalse);
    });

    test('the same person at two businesses is one customer with the sum', () {
      final ranking = CustomerRanking.fromLists([
        [_customer('u1', 100, name: 'Ana')],
        [_customer('u1', 50, name: null, email: 'ana@x.kz'), _customer('u2', 120, name: 'Bek')],
      ]);
      expect(ranking.top.map((c) => c.name), ['Ana', 'Bek'], reason: 'Ana: 100 + 50 beats Bek: 120');
      expect(ranking.top.first.spent, 150);
      expect(ranking.top.first.name, 'Ana', reason: 'the first name seen is kept, not the later e-mail');
    });

    test('a name falls back to the e-mail, then to nothing', () {
      final ranking = CustomerRanking.fromLists([
        [
          _customer('u1', 5, name: '  ', email: 'a@x.kz'),
          _customer('u2', 4, name: null, email: ''),
          _customer('u3', 3, name: ' Cem ', email: 'c@x.kz'),
        ],
      ]);
      expect(ranking.top.map((c) => c.name), ['a@x.kz', null, 'Cem']);
    });

    test('nobody has spent anything', () {
      final ranking = CustomerRanking.fromLists([
        [_customer('u1', 0)],
        const [],
      ]);
      expect(ranking.isEmpty, isTrue);
      expect(ranking.total, 0);
      expect(ranking.shareOf(const TopCustomer(userId: 'x', name: null, spent: 5)), 0);
    });
  });
}
