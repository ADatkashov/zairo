/// Mirrors backend's BookingDtos.BookingResponse
/// (backend/booking/.../BookingDtos.java).
class AdminBooking {
  final String id;
  final String userId;
  final String serviceId;
  final String availabilitySlotId;
  final String status;
  final double totalPrice;
  final DateTime createdAt;

  /// Why it was cancelled, when the customer said (only on a cancelled booking).
  final String? cancellationReason;

  const AdminBooking({
    required this.id,
    required this.userId,
    required this.serviceId,
    required this.availabilitySlotId,
    required this.status,
    required this.totalPrice,
    required this.createdAt,
    this.cancellationReason,
  });

  factory AdminBooking.fromJson(Map<String, dynamic> json) {
    return AdminBooking(
      id: json['id'] as String,
      userId: json['userId'] as String,
      serviceId: json['serviceId'] as String,
      availabilitySlotId: json['availabilitySlotId'] as String,
      status: json['status'] as String,
      totalPrice: (json['totalPrice'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      cancellationReason: json['cancellationReason'] as String?,
    );
  }
}
