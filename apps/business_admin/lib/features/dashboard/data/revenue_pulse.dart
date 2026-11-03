import '../../salon/data/models/business_analytics.dart';

/// How many days the dashboard looks back, and the window before that it
/// compares against ("vs previous 30 days").
const int pulseDays = 30;

/// One slice of the "where the money comes from" ring. [title] is null for the
/// [isOther] slice (everything beyond the top few) and for a service the
/// server has no name for.
class ServiceRevenueShare {
  const ServiceRevenueShare({
    required this.title,
    required this.amount,
    this.isOther = false,
  });

  final String? title;
  final double amount;
  final bool isOther;
}

/// What the owner earned lately, across every business they run: the daily
/// series behind the Today / 7 days / 30 days cards, each with its change
/// against the period before, and the split by service.
///
/// Built client-side from the per-business revenue analytics (the same endpoint
/// the Business Analytics screen uses), so there is no extra backend aggregate.
/// Days without a completed visit are zero-filled, as the server only lists
/// days that earned something. The server buckets a visit by its UTC date, which
/// is the visit's own calendar day for any ordinary opening hours in the
/// markets served; only a visit in the first hours after local midnight would
/// land on the neighbouring day.
class RevenuePulse {
  const RevenuePulse._(this._days, this.services, this.currency);

  /// Revenue per day for the last `2 × pulseDays` days, oldest first, today last.
  final List<double> _days;
  final List<ServiceRevenueShare> services;
  final String? currency;

  /// [lastTwoPeriods] covers the last `2 × pulseDays` days (for the series and
  /// the comparisons); [lastPeriod] covers only the last [pulseDays] (for the
  /// service split, so it describes exactly the window the 30-days card shows).
  /// One entry per business in each list. [now] is the device's clock.
  factory RevenuePulse.fromRevenue({
    required List<BusinessAnalyticsRevenue> lastTwoPeriods,
    required List<BusinessAnalyticsRevenue> lastPeriod,
    required DateTime now,
    int topServices = 4,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final total = pulseDays * 2;
    final days = List<double>.filled(total, 0);
    for (final part in lastTwoPeriods) {
      for (final entry in part.revenueByDay) {
        // Whole calendar days apart, immune to a daylight-saving hour.
        final date = DateTime(
          entry.date.year,
          entry.date.month,
          entry.date.day,
        );
        final ago = DateTime.utc(
          today.year,
          today.month,
          today.day,
        ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
        if (ago >= 0 && ago < total) days[total - 1 - ago] += entry.amount;
      }
    }

    final byService = <String, ({String? title, double amount})>{};
    for (final part in lastPeriod) {
      for (final row in part.revenueByService) {
        final known = byService[row.serviceId];
        byService[row.serviceId] = (
          title: known?.title ?? row.title,
          amount: (known?.amount ?? 0) + row.amount,
        );
      }
    }
    final ranked = byService.values.where((s) => s.amount > 0).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final shares = [
      for (final s in ranked.take(topServices))
        ServiceRevenueShare(title: s.title, amount: s.amount),
    ];
    final rest = ranked
        .skip(topServices)
        .fold<double>(0, (sum, s) => sum + s.amount);
    if (rest > 0) {
      shares.add(ServiceRevenueShare(title: null, amount: rest, isOther: true));
    }

    String? currency;
    for (final part in [...lastTwoPeriods, ...lastPeriod]) {
      currency ??= part.currency;
    }
    return RevenuePulse._(days, shares, currency);
  }

  double _sum(int from, int to) =>
      _days.sublist(from, to).fold(0, (a, b) => a + b);

  int get _n => _days.length;

  double get today => _days[_n - 1];
  double get yesterday => _days[_n - 2];
  double get last7 => _sum(_n - 7, _n);
  double get previous7 => _sum(_n - 14, _n - 7);
  double get last30 => _sum(_n - pulseDays, _n);
  double get previous30 => _sum(0, _n - pulseDays);

  /// Daily revenue of the last [days] days, oldest first — a card's trend line.
  List<double> trend(int days) => _days.sublist(_n - days);

  /// Nothing earned in the whole window: a brand-new business, where three
  /// zero cards and flat lines would only be noise.
  bool get isEmpty => _days.every((d) => d == 0);

  double get serviceTotal => services.fold(0, (sum, s) => sum + s.amount);

  /// Percent change from [previous] to [current]; null when there is nothing
  /// to compare against (a rise "from zero" has no meaningful percentage).
  static double? change(double current, double previous) {
    if (previous <= 0) return null;
    return (current - previous) / previous * 100;
  }
}

/// A customer ranked by what they have spent across the owner's businesses.
class TopCustomer {
  const TopCustomer({
    required this.userId,
    required this.name,
    required this.spent,
    this.currency,
  });

  final String userId;

  /// Display name, else the e-mail; null when the server has neither.
  final String? name;
  final double spent;
  final String? currency;
}

/// The biggest customers by lifetime spend, with the denominator needed to say
/// what part of all spending each one is.
class CustomerRanking {
  const CustomerRanking({required this.top, required this.total});

  final List<TopCustomer> top;

  /// What every customer (not just the top ones) has spent.
  final double total;

  bool get isEmpty => top.isEmpty;

  double shareOf(TopCustomer customer) =>
      total <= 0 ? 0 : customer.spent / total;

  /// One list of customers per business; the same person at two of them is one
  /// customer with the sum.
  factory CustomerRanking.fromLists(
    List<List<CustomerListItem>> perBusiness, {
    int top = 3,
  }) {
    final byUser = <String, TopCustomer>{};
    for (final list in perBusiness) {
      for (final item in list) {
        if (item.totalSpent <= 0) continue;
        final known = byUser[item.userId];
        byUser[item.userId] = TopCustomer(
          userId: item.userId,
          name: known?.name ?? _nameOf(item),
          spent: (known?.spent ?? 0) + item.totalSpent,
          currency: known?.currency ?? item.currency,
        );
      }
    }
    final ranked = byUser.values.toList()
      ..sort((a, b) => b.spent.compareTo(a.spent));
    return CustomerRanking(
      top: ranked.take(top).toList(),
      total: ranked.fold<double>(0, (sum, c) => sum + c.spent),
    );
  }

  static String? _nameOf(CustomerListItem item) {
    final name = item.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = item.email?.trim();
    return (email == null || email.isEmpty) ? null : email;
  }
}
