/// Mirrors backend's AvailabilitySlotDtos.AvailabilitySlotResponse
/// (backend/booking/.../AvailabilitySlotDtos.java).
class AdminSlot {
  final String id;
  final String providerId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;

  const AdminSlot({
    required this.id,
    required this.providerId,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  factory AdminSlot.fromJson(Map<String, dynamic> json) {
    return AdminSlot(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      status: json['status'] as String,
    );
  }
}
