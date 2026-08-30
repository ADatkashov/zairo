/// Mirrors backend's StaffDtos.StaffServiceResponse — the services a given
/// staff member is linked to (subset of AdminService's fields).
class AdminStaffServiceSummary {
  final String serviceId;
  final String title;
  final int durationMinutes;
  final double price;
  final String currency;

  const AdminStaffServiceSummary({
    required this.serviceId,
    required this.title,
    required this.durationMinutes,
    required this.price,
    required this.currency,
  });

  factory AdminStaffServiceSummary.fromJson(Map<String, dynamic> json) {
    return AdminStaffServiceSummary(
      serviceId: json['serviceId'] as String,
      title: json['title'] as String,
      durationMinutes: json['durationMinutes'] as int,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
    );
  }
}
