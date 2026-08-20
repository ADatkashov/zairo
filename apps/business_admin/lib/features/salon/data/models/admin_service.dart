/// Mirrors backend's ServiceOfferingDtos.ServiceResponse
/// (backend/services/.../ServiceOfferingDtos.java).
class AdminService {
  final String id;
  final String providerId;
  final String title;
  final int durationMinutes;
  final double price;
  final String currency;
  final bool active;

  const AdminService({
    required this.id,
    required this.providerId,
    required this.title,
    required this.durationMinutes,
    required this.price,
    required this.currency,
    required this.active,
  });

  factory AdminService.fromJson(Map<String, dynamic> json) {
    return AdminService(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      title: json['title'] as String,
      durationMinutes: json['durationMinutes'] as int,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
      active: json['active'] as bool,
    );
  }
}
