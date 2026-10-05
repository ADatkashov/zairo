num _num(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? 0;
  return 0;
}

DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String);

/// Mirrors backend's BusinessPayoutDtos.PayoutResponse — what a business is
/// owed for one completed booking (ADR-0007). PAID only after a person has
/// confirmed the money actually moved.
class Payout {
  final String id;
  final String bookingId;
  final String paymentId;
  final String providerId;
  final num amount;
  final String currency;
  final String status;
  final String? providerReference;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? settledAt;

  const Payout({
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

  factory Payout.fromJson(Map<String, dynamic> json) {
    return Payout(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      paymentId: json['paymentId'] as String,
      providerId: json['providerId'] as String,
      amount: _num(json['amount']),
      currency: json['currency'] as String,
      status: json['status'] as String,
      providerReference: json['providerReference'] as String?,
      failureReason: json['failureReason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      settledAt: _date(json['settledAt']),
    );
  }
}

/// Mirrors backend's PaymentDtos.PaymentResponse, the fields the console uses
/// (payments whose refund failed — money still owed back to a customer).
class FailedRefundPayment {
  final String id;
  final String bookingId;
  final num amount;
  final String currency;
  final String status;
  final String? provider;
  final String? providerReference;
  final String? refundFailureReason;
  final int refundAttempts;
  final DateTime? createdAt;

  const FailedRefundPayment({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.currency,
    required this.status,
    this.provider,
    this.providerReference,
    this.refundFailureReason,
    required this.refundAttempts,
    this.createdAt,
  });

  factory FailedRefundPayment.fromJson(Map<String, dynamic> json) {
    return FailedRefundPayment(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      amount: _num(json['amount']),
      currency: json['currency'] as String,
      status: json['status'] as String,
      provider: json['provider'] as String?,
      providerReference: json['providerReference'] as String?,
      refundFailureReason: json['refundFailureReason'] as String?,
      refundAttempts: (json['refundAttempts'] as num? ?? 0).toInt(),
      createdAt: _date(json['createdAt']),
    );
  }
}

/// Mirrors backend's PaymentDtos.RefundRequestResponse — one row of the
/// durable refund queue.
class RefundRequest {
  final String id;
  final String paymentId;
  final String bookingId;
  final num amount;
  final String currency;
  final String status;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final DateTime? createdAt;

  const RefundRequest({
    required this.id,
    required this.paymentId,
    required this.bookingId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.attempts,
    this.nextAttemptAt,
    this.lastError,
    this.createdAt,
  });

  factory RefundRequest.fromJson(Map<String, dynamic> json) {
    return RefundRequest(
      id: json['id'] as String,
      paymentId: json['paymentId'] as String,
      bookingId: json['bookingId'] as String,
      amount: _num(json['amount']),
      currency: json['currency'] as String,
      status: json['status'] as String,
      attempts: (json['attempts'] as num? ?? 0).toInt(),
      nextAttemptAt: _date(json['nextAttemptAt']),
      lastError: json['lastError'] as String?,
      createdAt: _date(json['createdAt']),
    );
  }
}

/// The result of comparing ZAIRO's payment status with the provider's.
/// DISCREPANCY means a person must look — nothing is corrected automatically.
class ReconciliationResult {
  final String outcome;
  final String localStatus;
  final String? providerStatus;
  final String? providerReference;

  const ReconciliationResult({
    required this.outcome,
    required this.localStatus,
    this.providerStatus,
    this.providerReference,
  });

  bool get isMatch => outcome == 'MATCH';

  factory ReconciliationResult.fromJson(Map<String, dynamic> json) {
    return ReconciliationResult(
      outcome: json['outcome'] as String,
      localStatus: json['localStatus'] as String,
      providerStatus: json['providerStatus'] as String?,
      providerReference: json['providerReference'] as String?,
    );
  }
}
