/// Mirrors backend's LoyaltyTransactionType enum -- every reason a
/// customer's points balance can change. The admin adjust-points action
/// always produces [adjustment]; the other values exist because
/// [LoyaltyTransaction] is the same shape a customer's own ledger uses, and
/// this app never filters the response down to admin-only cases.
enum LoyaltyTransactionType {
  earned,
  bonus,
  redeemed,
  expired,
  refund,
  adjustment,
  reversal;

  static LoyaltyTransactionType fromWire(String value) => switch (value) {
        'EARNED' => LoyaltyTransactionType.earned,
        'BONUS' => LoyaltyTransactionType.bonus,
        'REDEEMED' => LoyaltyTransactionType.redeemed,
        'EXPIRED' => LoyaltyTransactionType.expired,
        'REFUND' => LoyaltyTransactionType.refund,
        'ADJUSTMENT' => LoyaltyTransactionType.adjustment,
        'REVERSAL' => LoyaltyTransactionType.reversal,
        _ => throw ArgumentError('Unknown LoyaltyTransactionType: $value'),
      };
}

/// Mirrors backend's LoyaltyDtos.LoyaltyTransactionResponse -- the ledger
/// entry a manual balance adjustment (`POST .../adjust`) returns, so the
/// confirmation UI can show the customer's new balance immediately.
class LoyaltyTransaction {
  final String id;
  final LoyaltyTransactionType type;
  final int pointsDelta;
  final int balanceAfter;
  final String? reason;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? bookingId;

  const LoyaltyTransaction({
    required this.id,
    required this.type,
    required this.pointsDelta,
    required this.balanceAfter,
    this.reason,
    required this.createdAt,
    this.expiresAt,
    this.bookingId,
  });

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransaction(
      id: json['id'] as String,
      type: LoyaltyTransactionType.fromWire(json['type'] as String),
      pointsDelta: (json['pointsDelta'] as num).toInt(),
      balanceAfter: (json['balanceAfter'] as num).toInt(),
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String),
      bookingId: json['bookingId'] as String?,
    );
  }
}
