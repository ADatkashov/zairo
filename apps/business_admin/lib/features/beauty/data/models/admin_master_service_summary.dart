/// Mirrors backend's MasterDtos.MasterServiceResponse — the services a
/// given master is linked to (subset of AdminService's fields).
class AdminMasterServiceSummary {
  final String serviceId;
  final String title;
  final int durationMinutes;
  final double price;
  final String currency;

  const AdminMasterServiceSummary({
    required this.serviceId,
    required this.title,
    required this.durationMinutes,
    required this.price,
    required this.currency,
  });

  factory AdminMasterServiceSummary.fromJson(Map<String, dynamic> json) {
    return AdminMasterServiceSummary(
      serviceId: json['serviceId'] as String,
      title: json['title'] as String,
      durationMinutes: json['durationMinutes'] as int,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
    );
  }
}
