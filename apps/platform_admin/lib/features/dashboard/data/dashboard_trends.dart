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
}
