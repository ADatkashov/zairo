/// Mirrors backend's BusinessPayoutDtos.PayoutResponse
/// (backend/payments/.../BusinessPayoutDtos.java) — the business's own
/// settlement record for one completed booking. See ADR-0007
/// (docs/adr/0007-marketplace-commission-and-settlement.md): created only
/// once the booking is COMPLETED, never at payment time, and [status]
/// never reaches "PAID" until a platform admin has actually confirmed the
/// money moved — this screen must never imply a payout is done before that.
class AdminPayout {
  final String id;
  final String bookingId;
  final String paymentId;
  final String providerId;
  final double amount;
  final String currency;
  final String status;
  final String? providerReference;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? settledAt;

  const AdminPayout({
    required this.id,
    required this.bookingId,
    required this.paymentId,
    required this.providerId,
    required this.amount,
    required this.currency,
    required this.status,
    this.providerReference,
    this.failureReason,
    required this.createdAt,
    this.settledAt,
  });

  factory AdminPayout.fromJson(Map<String, dynamic> json) {
    return AdminPayout(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      paymentId: json['paymentId'] as String,
      providerId: json['providerId'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      status: json['status'] as String,
      providerReference: json['providerReference'] as String?,
      failureReason: json['failureReason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      settledAt: json['settledAt'] == null
          ? null
          : DateTime.parse(json['settledAt'] as String),
    );
  }
}
