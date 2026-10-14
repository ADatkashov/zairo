/// Mirrors backend's PlatformInsightsDtos.PlatformReport.
class PlatformReport {
  final DateTime from;
  final DateTime to;

  /// Bookings created per day, oldest first.
  final List<DailyValue> bookingsCreated;
  final List<DailyValue> commissionByDay;
  final String? commissionCurrency;
  final List<DailyValue> subscriptionRevenueByDay;
  final String? subscriptionCurrency;
  final BookingsByStatus bookingsByStatus;

  const PlatformReport({
    required this.from,
    required this.to,
    required this.bookingsCreated,
    required this.commissionByDay,
    required this.commissionCurrency,
    required this.subscriptionRevenueByDay,
    required this.subscriptionCurrency,
    required this.bookingsByStatus,
  });

  factory PlatformReport.fromJson(Map<String, dynamic> json) {
    List<DailyValue> series(String key, String valueKey) => [
      for (final day in (json[key] as List<dynamic>? ?? const []))
        DailyValue.fromJson(day as Map<String, dynamic>, valueKey),
    ];
    return PlatformReport(
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      bookingsCreated: series('bookingsCreated', 'count'),
      commissionByDay: series('commissionByDay', 'amount'),
      commissionCurrency: json['commissionCurrency'] as String?,
      subscriptionRevenueByDay: series('subscriptionRevenueByDay', 'amount'),
      subscriptionCurrency: json['subscriptionCurrency'] as String?,
      bookingsByStatus: BookingsByStatus.fromJson((json['bookingsByStatus'] as Map<String, dynamic>?) ?? const {}),
    );
  }
}

class DailyValue {
  final DateTime date;
  final double value;

  const DailyValue({required this.date, required this.value});

  factory DailyValue.fromJson(Map<String, dynamic> json, String valueKey) =>
      DailyValue(date: DateTime.parse(json['date'] as String), value: (json[valueKey] as num).toDouble());
}

extension DailySeries on List<DailyValue> {
  List<double> get values => [for (final d in this) d.value];

  double get total => fold(0, (sum, d) => sum + d.value);
}

class BookingsByStatus {
  final int pending;
  final int confirmed;
  final int completed;
  final int cancelled;
  final int noShow;

  const BookingsByStatus({
    this.pending = 0,
    this.confirmed = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.noShow = 0,
  });

  factory BookingsByStatus.fromJson(Map<String, dynamic> json) => BookingsByStatus(
    pending: (json['pending'] as num?)?.toInt() ?? 0,
    confirmed: (json['confirmed'] as num?)?.toInt() ?? 0,
    completed: (json['completed'] as num?)?.toInt() ?? 0,
    cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
    noShow: (json['noShow'] as num?)?.toInt() ?? 0,
  );

  int get total => pending + confirmed + completed + cancelled + noShow;
}
