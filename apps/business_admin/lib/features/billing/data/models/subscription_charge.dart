/// Mirrors backend's SubscriptionDtos.SubscriptionChargeResponse
/// (backend/subscriptions/.../SubscriptionDtos.java) — one billing-period
/// charge attempt, shown as the Billing screen's invoice history (v2
/// design audit).
class SubscriptionCharge {
  final String id;
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAt;

  const SubscriptionCharge({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  factory SubscriptionCharge.fromJson(Map<String, dynamic> json) {
    return SubscriptionCharge(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
