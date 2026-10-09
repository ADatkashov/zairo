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

  // What the booking references by id, resolved by the backend for display.
  // All nullable: an older backend (or a reference that no longer resolves)
  // simply leaves them out, and the UI falls back to what it always showed.
  final String? serviceTitle;
  final String? providerId;
  final String? providerName;
  final String? providerVertical;

  /// When the appointment starts and ends (the booked slot's times).
  final DateTime? startsAt;
  final DateTime? endsAt;

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
    this.serviceTitle,
    this.providerId,
    this.providerName,
    this.providerVertical,
    this.startsAt,
    this.endsAt,
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
      serviceTitle: json['serviceTitle'] as String?,
      providerId: json['providerId'] as String?,
      providerName: json['providerName'] as String?,
      providerVertical: json['providerVertical'] as String?,
      startsAt: _parseInstant(json['startsAt']),
      endsAt: _parseInstant(json['endsAt']),
    );
  }
}

DateTime? _parseInstant(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
