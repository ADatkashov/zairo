/// Mirrors backend's PlatformInsightsDtos.PlatformDashboardMetrics.
class DashboardMetrics {
  final int users;
  final int businessesTotal;
  final int businessesActive;
  final int businessesPending;
  final int businessesBlocked;
  final int subsFree;
  final int subsPro;
  final int subsActive;
  final int subsPastDue;
  final int subsCancelled;
  final int bookingsToday;
  final int bookingsWeek;
  final int bookingsMonth;
  final int bookingsCompleted;
  final int bookingsCancelled;
  final int paymentsSucceeded;
  final int paymentsFailed;
  final int paymentsPending;
  final int paymentsRefunded;
  final int paymentsRefundFailed;
  final num mrr;
  final String? currency;
  final num platformCommission;
  final String? commissionCurrency;

  /// Reviews a business reported that wait for a platform decision.
  final int reviewsReported;

  const DashboardMetrics({
    required this.users,
    required this.businessesTotal,
    required this.businessesActive,
    required this.businessesPending,
    required this.businessesBlocked,
    required this.subsFree,
    required this.subsPro,
    required this.subsActive,
    required this.subsPastDue,
    required this.subsCancelled,
    required this.bookingsToday,
    required this.bookingsWeek,
    required this.bookingsMonth,
    required this.bookingsCompleted,
    required this.bookingsCancelled,
    required this.paymentsSucceeded,
    required this.paymentsFailed,
    required this.paymentsPending,
    required this.paymentsRefunded,
    required this.paymentsRefundFailed,
    required this.mrr,
    required this.currency,
    required this.platformCommission,
    required this.commissionCurrency,
    this.reviewsReported = 0,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    int n(Map<String, dynamic> section, String key) => (section[key] as num? ?? 0).toInt();
    final users = json['users'] as Map<String, dynamic>? ?? const {};
    final businesses = json['businesses'] as Map<String, dynamic>? ?? const {};
    final subs = json['subscriptions'] as Map<String, dynamic>? ?? const {};
    final bookings = json['bookings'] as Map<String, dynamic>? ?? const {};
    final payments = json['payments'] as Map<String, dynamic>? ?? const {};
    final revenue = json['revenue'] as Map<String, dynamic>? ?? const {};
    final reviews = json['reviews'] as Map<String, dynamic>? ?? const {};
    return DashboardMetrics(
      users: n(users, 'total'),
      businessesTotal: n(businesses, 'total'),
      businessesActive: n(businesses, 'active'),
      businessesPending: n(businesses, 'pendingModeration'),
      businessesBlocked: n(businesses, 'blocked'),
      subsFree: n(subs, 'free'),
      subsPro: n(subs, 'pro'),
      subsActive: n(subs, 'active'),
      subsPastDue: n(subs, 'pastDue'),
      subsCancelled: n(subs, 'cancelled'),
      bookingsToday: n(bookings, 'today'),
      bookingsWeek: n(bookings, 'thisWeek'),
      bookingsMonth: n(bookings, 'thisMonth'),
      bookingsCompleted: n(bookings, 'completed'),
      bookingsCancelled: n(bookings, 'cancelled'),
      paymentsSucceeded: n(payments, 'succeeded'),
      paymentsFailed: n(payments, 'failed'),
      paymentsPending: n(payments, 'pending'),
      paymentsRefunded: n(payments, 'refunded'),
      paymentsRefundFailed: n(payments, 'refundFailed'),
      mrr: _decimal(revenue['mrr']),
      currency: revenue['currency'] as String?,
      platformCommission: _decimal(revenue['platformCommission']),
      commissionCurrency: revenue['platformCommissionCurrency'] as String?,
      reviewsReported: n(reviews, 'reportedOpen'),
    );
  }
}

num _decimal(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? 0;
  return 0;
}
