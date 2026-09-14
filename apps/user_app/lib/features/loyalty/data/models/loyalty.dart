/// Mirrors backend's LoyaltyDtos (backend/loyalty/.../LoyaltyDtos.java) —
/// the customer-facing Loyalty & Rewards read/write surface. Every field
/// matches the backend JSON shape exactly; nullable fields mean "not set on
/// this business/reward/redemption", never a fabricated placeholder.
library;

/// What redeeming a [LoyaltyReward] actually gets a customer. Mirrors
/// backend's `LoyaltyRewardType`.
enum LoyaltyRewardType {
  fixedDiscount,
  percentageDiscount,
  freeService,
  custom;

  static LoyaltyRewardType fromWire(String value) => switch (value) {
        'FIXED_DISCOUNT' => LoyaltyRewardType.fixedDiscount,
        'PERCENTAGE_DISCOUNT' => LoyaltyRewardType.percentageDiscount,
        'FREE_SERVICE' => LoyaltyRewardType.freeService,
        'CUSTOM' => LoyaltyRewardType.custom,
        _ => throw ArgumentError('Unknown LoyaltyRewardType: $value'),
      };

  String toWire() => switch (this) {
        LoyaltyRewardType.fixedDiscount => 'FIXED_DISCOUNT',
        LoyaltyRewardType.percentageDiscount => 'PERCENTAGE_DISCOUNT',
        LoyaltyRewardType.freeService => 'FREE_SERVICE',
        LoyaltyRewardType.custom => 'CUSTOM',
      };
}

/// Every possible reason a points balance changes. Mirrors backend's
/// `LoyaltyTransactionType`. The Flutter side never re-derives whether a
/// row reads as a gain or a loss from this — [LoyaltyTransaction.pointsDelta]
/// is already signed and is what drives the +/- color, exactly as the
/// backend computed it.
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

/// Mirrors backend's `LoyaltyRedemptionStatus`.
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

/// One row of "my rewards across every business" — GET /api/v1/loyalty.
/// [tierName] is null when the program has no tier configured, or the
/// account hasn't reached one yet.
class LoyaltyBusinessSummary {
  final String providerId;
  final String? providerName;
  final bool programEnabled;
  final int pointsBalance;
  final int lifetimeEarned;
  final String? tierName;
  final int pointsExpiringSoon30d;

  const LoyaltyBusinessSummary({
    required this.providerId,
    this.providerName,
    required this.programEnabled,
    required this.pointsBalance,
    required this.lifetimeEarned,
    this.tierName,
    required this.pointsExpiringSoon30d,
  });

  factory LoyaltyBusinessSummary.fromJson(Map<String, dynamic> json) {
    return LoyaltyBusinessSummary(
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String?,
      programEnabled: json['programEnabled'] as bool,
      pointsBalance: (json['pointsBalance'] as num).toInt(),
      lifetimeEarned: (json['lifetimeEarned'] as num).toInt(),
      tierName: json['tierName'] as String?,
      pointsExpiringSoon30d: (json['pointsExpiringSoon30d'] as num).toInt(),
    );
  }
}

/// The next tier-milestone the customer hasn't reached yet at one business
/// -- null on [LoyaltyBusinessDetail] means there's no further milestone
/// configured (or none left to reach).
class NextMilestone {
  final String label;
  final int visitsRequired;
  final int visitsRemaining;
  final int pointsAwarded;

  const NextMilestone({
    required this.label,
    required this.visitsRequired,
    required this.visitsRemaining,
    required this.pointsAwarded,
  });

  factory NextMilestone.fromJson(Map<String, dynamic> json) {
    return NextMilestone(
      label: json['label'] as String,
      visitsRequired: (json['visitsRequired'] as num).toInt(),
      visitsRemaining: (json['visitsRemaining'] as num).toInt(),
      pointsAwarded: (json['pointsAwarded'] as num).toInt(),
    );
  }
}

/// One business's loyalty program from the customer's point of view -- GET
/// /api/v1/loyalty/businesses/{providerId}. Always returns a value (zeros /
/// [programEnabled] false), never a 404, even for a business the customer
/// has never booked with.
class LoyaltyBusinessDetail {
  final String providerId;
  final String? providerName;
  final bool programEnabled;
  final String? programName;
  final String? programDescription;
  final int pointsBalance;
  final int lifetimeEarned;
  final int lifetimeRedeemed;
  final int completedVisits;
  final String? tierName;
  final int pointsExpiringSoon30d;

  /// Already human-readable English sentences generated server-side (e.g.
  /// "10 points per completed booking") -- rendered as-is, never
  /// re-localized, per backend's own doc comment on this field.
  final List<String> waysToEarn;
  final NextMilestone? nextMilestone;
  final int availableRewardsCount;

  const LoyaltyBusinessDetail({
    required this.providerId,
    this.providerName,
    required this.programEnabled,
    this.programName,
    this.programDescription,
    required this.pointsBalance,
    required this.lifetimeEarned,
    required this.lifetimeRedeemed,
    required this.completedVisits,
    this.tierName,
    required this.pointsExpiringSoon30d,
    required this.waysToEarn,
    this.nextMilestone,
    required this.availableRewardsCount,
  });

  factory LoyaltyBusinessDetail.fromJson(Map<String, dynamic> json) {
    return LoyaltyBusinessDetail(
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String?,
      programEnabled: json['programEnabled'] as bool,
      programName: json['programName'] as String?,
      programDescription: json['programDescription'] as String?,
      pointsBalance: (json['pointsBalance'] as num).toInt(),
      lifetimeEarned: (json['lifetimeEarned'] as num).toInt(),
      lifetimeRedeemed: (json['lifetimeRedeemed'] as num).toInt(),
      completedVisits: (json['completedVisits'] as num).toInt(),
      tierName: json['tierName'] as String?,
      pointsExpiringSoon30d: (json['pointsExpiringSoon30d'] as num).toInt(),
      waysToEarn: (json['waysToEarn'] as List<dynamic>).map((e) => e as String).toList(),
      nextMilestone:
          json['nextMilestone'] == null ? null : NextMilestone.fromJson(json['nextMilestone'] as Map<String, dynamic>),
      availableRewardsCount: (json['availableRewardsCount'] as num).toInt(),
    );
  }
}

/// One redeemable reward at a business -- GET
/// /api/v1/loyalty/businesses/{providerId}/rewards. [affordable] is
/// server-computed against the caller's current balance at fetch time; the
/// UI never re-derives it from [pointsCost] and a locally-cached balance
/// (which could be stale right after a redemption elsewhere).
class LoyaltyReward {
  final String id;
  final String name;
  final String? description;
  final LoyaltyRewardType type;
  final int pointsCost;
  final double? discountAmount;
  final String? discountCurrency;
  final double? discountPercentage;
  final String? serviceId;
  final DateTime? endsAt;
  final String? terms;
  final bool affordable;

  const LoyaltyReward({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.pointsCost,
    this.discountAmount,
    this.discountCurrency,
    this.discountPercentage,
    this.serviceId,
    this.endsAt,
    this.terms,
    required this.affordable,
  });

  factory LoyaltyReward.fromJson(Map<String, dynamic> json) {
    return LoyaltyReward(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      type: LoyaltyRewardType.fromWire(json['type'] as String),
      pointsCost: (json['pointsCost'] as num).toInt(),
      discountAmount: (json['discountAmount'] as num?)?.toDouble(),
      discountCurrency: json['discountCurrency'] as String?,
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble(),
      serviceId: json['serviceId'] as String?,
      endsAt: json['endsAt'] == null ? null : DateTime.parse(json['endsAt'] as String),
      terms: json['terms'] as String?,
      affordable: json['affordable'] as bool,
    );
  }
}

/// One immutable ledger row -- GET
/// /api/v1/loyalty/businesses/{providerId}/history. [pointsDelta] is signed
/// (positive for a gain, negative for a spend/expiry) and is the single
/// source of truth for how a row renders -- never re-derived from [type].
class LoyaltyTransaction {
  final String id;
  final LoyaltyTransactionType type;
  final int pointsDelta;
  final int balanceAfter;
  final String reason;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? bookingId;

  const LoyaltyTransaction({
    required this.id,
    required this.type,
    required this.pointsDelta,
    required this.balanceAfter,
    required this.reason,
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
      reason: json['reason'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String),
      bookingId: json['bookingId'] as String?,
    );
  }
}

/// One redemption code -- issued by POST
/// /api/v1/loyalty/rewards/{rewardId}/redeem, listed by GET
/// /api/v1/loyalty/redemptions, fetched singly by GET
/// /api/v1/loyalty/redemptions/{id}.
class LoyaltyRedemption {
  final String id;
  final String providerId;
  final String? providerName;
  final String rewardId;
  final String rewardName;
  final LoyaltyRewardType rewardType;
  final int pointsSpent;
  final String code;
  final LoyaltyRedemptionStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? appliedBookingId;
  final DateTime? appliedAt;

  const LoyaltyRedemption({
    required this.id,
    required this.providerId,
    this.providerName,
    required this.rewardId,
    required this.rewardName,
    required this.rewardType,
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
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String?,
      rewardId: json['rewardId'] as String,
      rewardName: json['rewardName'] as String,
      rewardType: LoyaltyRewardType.fromWire(json['rewardType'] as String),
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
