/// Mirrors backend's MechanicDtos.MechanicServiceResponse — the services a
/// given mechanic is linked to (subset of AdminService's fields).
class AdminMechanicServiceSummary {
  final String serviceId;
  final String title;
  final int durationMinutes;
  final double price;
  final String currency;

  const AdminMechanicServiceSummary({
    required this.serviceId,
    required this.title,
    required this.durationMinutes,
    required this.price,
    required this.currency,
  });

  factory AdminMechanicServiceSummary.fromJson(Map<String, dynamic> json) {
    return AdminMechanicServiceSummary(
      serviceId: json['serviceId'] as String,
      title: json['title'] as String,
      durationMinutes: json['durationMinutes'] as int,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
    );
  }
}
