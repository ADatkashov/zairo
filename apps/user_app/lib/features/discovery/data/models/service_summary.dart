/// Mirrors backend's SearchDtos.ServiceSummary
/// (backend/search/.../SearchDtos.java).
class ServiceSummary {
  final String id;
  final String title;
  final int durationMinutes;
  final double price;
  final String currency;

  const ServiceSummary({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.price,
    required this.currency,
  });

  factory ServiceSummary.fromJson(Map<String, dynamic> json) {
    return ServiceSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      durationMinutes: json['durationMinutes'] as int,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
    );
  }
}
