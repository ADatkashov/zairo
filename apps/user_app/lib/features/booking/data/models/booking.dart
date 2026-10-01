/// Mirrors backend's BookingDtos.BookingResponse
/// (backend/booking/.../BookingDtos.java).
class Booking {
  final String id;
  final String userId;
  final String serviceId;
  final String availabilitySlotId;
  final String status;
  final double totalPrice;
  final double? depositAmount;
  final double? remainingAmount;
  final DateTime createdAt;

  const Booking({
    required this.id,
    required this.userId,
    required this.serviceId,
    required this.availabilitySlotId,
    required this.status,
    required this.totalPrice,
    this.depositAmount,
    this.remainingAmount,
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      userId: json['userId'] as String,
      serviceId: json['serviceId'] as String,
      availabilitySlotId: json['availabilitySlotId'] as String,
      status: json['status'] as String,
      totalPrice: (json['totalPrice'] as num).toDouble(),
      depositAmount: json['depositAmount'] != null
          ? (json['depositAmount'] as num).toDouble()
          : null,
      remainingAmount: json['remainingAmount'] != null
          ? (json['remainingAmount'] as num).toDouble()
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
