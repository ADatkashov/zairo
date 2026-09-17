/// Mirrors backend's LoyaltyAdminDtos.CustomerInsightResponse -- one row of
/// the loyalty roster (`GET .../loyalty/customers`) or a single customer's
/// detail (`GET .../loyalty/customers/{userId}`). [retentionStatus] is kept
/// as the raw wire string rather than a closed enum: it's a read-through to
/// Customer Intelligence's own classification (`NEW`/`ACTIVE`/`AT_RISK`/
/// `DUE_FOR_REBOOKING`/`LOST` today), and this screen only needs to render
/// it as a badge -- see `loyaltyRetentionStatusBadge` for the known/unknown
/// split, so a future status this app doesn't recognize yet still renders,
/// just with a neutral color instead of a crash.
class LoyaltyCustomerInsight {
  final String userId;
  final String? displayName;
  final String? email;
  final int pointsBalance;
  final int lifetimeEarned;
  final int lifetimeRedeemed;
  final int completedVisits;
  final DateTime? lastActivityAt;
  final int pointsExpiringSoon30d;
  final String? retentionStatus;

  const LoyaltyCustomerInsight({
    required this.userId,
    this.displayName,
    this.email,
    required this.pointsBalance,
    required this.lifetimeEarned,
    required this.lifetimeRedeemed,
    required this.completedVisits,
    this.lastActivityAt,
    required this.pointsExpiringSoon30d,
    this.retentionStatus,
  });

  factory LoyaltyCustomerInsight.fromJson(Map<String, dynamic> json) {
    return LoyaltyCustomerInsight(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      pointsBalance: (json['pointsBalance'] as num).toInt(),
      lifetimeEarned: (json['lifetimeEarned'] as num).toInt(),
      lifetimeRedeemed: (json['lifetimeRedeemed'] as num).toInt(),
      completedVisits: (json['completedVisits'] as num).toInt(),
      lastActivityAt: json['lastActivityAt'] == null ? null : DateTime.parse(json['lastActivityAt'] as String),
      pointsExpiringSoon30d: (json['pointsExpiringSoon30d'] as num).toInt(),
      retentionStatus: json['retentionStatus'] as String?,
    );
  }
}
