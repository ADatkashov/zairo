/// Mirrors backend's ProviderInsightsDtos.DashboardMetrics
/// (backend/provider-insights/.../ProviderInsightsDtos.java).
class DashboardMetrics {
  final int totalBookings;
  final int completedBookings;
  final int cancelledBookings;
  final double cancellationRate;
  final int totalCustomers;
  final double totalRevenue;
  final double? averageCheck;
  final String? currency;
  final List<DashboardTopService> topServices;

  const DashboardMetrics({
    required this.totalBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.cancellationRate,
    required this.totalCustomers,
    required this.totalRevenue,
    this.averageCheck,
    this.currency,
    required this.topServices,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      totalBookings: json['totalBookings'] as int,
      completedBookings: json['completedBookings'] as int,
      cancelledBookings: json['cancelledBookings'] as int,
      cancellationRate: (json['cancellationRate'] as num).toDouble(),
      totalCustomers: json['totalCustomers'] as int,
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      averageCheck: (json['averageCheck'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      topServices: (json['topServices'] as List<dynamic>)
          .map((e) => DashboardTopService.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DashboardTopService {
  final String serviceId;
  final String? title;
  final int bookingCount;

  const DashboardTopService({required this.serviceId, this.title, required this.bookingCount});

  factory DashboardTopService.fromJson(Map<String, dynamic> json) {
    return DashboardTopService(
      serviceId: json['serviceId'] as String,
      title: json['title'] as String?,
      bookingCount: json['bookingCount'] as int,
    );
  }
}
