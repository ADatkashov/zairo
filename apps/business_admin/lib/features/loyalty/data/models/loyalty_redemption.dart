/// Mirrors backend's LoyaltyRedemptionStatus enum exactly.
enum LoyaltyRedemptionStatus {
  active,
  applied,
  cancelled,
  expired;

  static LoyaltyRedemptionStatus fromWire(String value) => switch (value) {
        'ACTIVE' => LoyaltyRedemptionStatus.active,
        'APPLIED' => LoyaltyRedemptionStatus.applied,
        'CANCELLED' => LoyaltyRedemptionStatus.cancelled,
        'EXPIRED' => LoyaltyRedemptionStatus.expired,
        _ => throw ArgumentError('Unknown LoyaltyRedemptionStatus: $value'),
      };
}

/// Mirrors backend's LoyaltyAdminDtos.RedemptionAdminResponse -- one
/// customer's redemption code, from this business's point of view: the
/// short code they'll show at checkout, what it was spent on, and its
/// current lifecycle state.
class LoyaltyRedemption {
  final String id;
  final String userId;
  final String rewardId;
  final String rewardName;
  final int pointsSpent;
  final String code;
  final LoyaltyRedemptionStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? appliedBookingId;
  final DateTime? appliedAt;

  const LoyaltyRedemption({
    required this.id,
    required this.userId,
    required this.rewardId,
    required this.rewardName,
    required this.pointsSpent,
    required this.code,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.appliedBookingId,
    this.appliedAt,
  });

  factory LoyaltyRedemption.fromJson(Map<String, dynamic> json) {
    return LoyaltyRedemption(
      id: json['id'] as String,
      userId: json['userId'] as String,
      rewardId: json['rewardId'] as String,
      rewardName: json['rewardName'] as String,
      pointsSpent: (json['pointsSpent'] as num).toInt(),
      code: json['code'] as String,
      status: LoyaltyRedemptionStatus.fromWire(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String),
      appliedBookingId: json['appliedBookingId'] as String?,
      appliedAt: json['appliedAt'] == null ? null : DateTime.parse(json['appliedAt'] as String),
    );
  }
}
