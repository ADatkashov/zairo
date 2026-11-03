/// Mirrors backend's PlatformInsightsDtos.PlatformTrends.
class DashboardTrends {
  /// Bookings created per day, oldest first.
  final List<double> bookingsCreated;

  const DashboardTrends({required this.bookingsCreated});

  const DashboardTrends.empty() : bookingsCreated = const [];

  factory DashboardTrends.fromJson(Map<String, dynamic> json) => DashboardTrends(
    bookingsCreated: [
      for (final day in (json['bookingsCreated'] as List<dynamic>? ?? const []))
        ((day as Map<String, dynamic>)['count'] as num).toDouble(),
    ],
  );

  double get bookingsTotal => bookingsCreated.fold(0, (sum, value) => sum + value);

  /// How the last 7 days compare with the 7 before, in percent. Null when the
  /// series covers fewer than 14 days, or the earlier week had no bookings (a
  /// rise from zero has no meaningful percentage).
  double? get bookingsWeekChange {
    if (bookingsCreated.length < 14) return null;
    final lastTwoWeeks = bookingsCreated.sublist(bookingsCreated.length - 14);
    double sum(Iterable<double> values) => values.fold(0, (a, b) => a + b);
    final before = sum(lastTwoWeeks.take(7));
    if (before <= 0) return null;
    return (sum(lastTwoWeeks.skip(7)) - before) / before * 100;
  }
}
