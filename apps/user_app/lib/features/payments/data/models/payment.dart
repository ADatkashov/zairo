/// Mirrors backend's PaymentDtos.PaymentResponse
/// (backend/payments/.../PaymentDtos.java).
class Payment {
  final String id;
  final String bookingId;
  final double amount;
  final String currency;
  final String status;
  final String? providerReference;
  final String? failureReason;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.currency,
    required this.status,
    this.providerReference,
    this.failureReason,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      status: json['status'] as String,
      providerReference: json['providerReference'] as String?,
      failureReason: json['failureReason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
