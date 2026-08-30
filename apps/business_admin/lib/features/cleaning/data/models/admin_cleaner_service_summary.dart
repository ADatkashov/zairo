/// Mirrors backend's CleanerDtos.CleanerServiceResponse — the services a
/// given cleaner is linked to (subset of AdminService's fields).
class AdminCleanerServiceSummary {
  final String serviceId;
  final String title;
  final int durationMinutes;
  final double price;
  final String currency;

  const AdminCleanerServiceSummary({
    required this.serviceId,
    required this.title,
    required this.durationMinutes,
    required this.price,
    required this.currency,
  });

  factory AdminCleanerServiceSummary.fromJson(Map<String, dynamic> json) {
    return AdminCleanerServiceSummary(
      serviceId: json['serviceId'] as String,
      title: json['title'] as String,
      durationMinutes: json['durationMinutes'] as int,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
    );
  }
}
