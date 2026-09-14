/// What redeeming a [LoyaltyReward] actually gets a customer -- mirrors
/// backend's LoyaltyRewardType enum exactly. The create/edit form adapts
/// its visible fields to whichever type is selected: [fixedDiscount] needs
/// [LoyaltyReward.discountAmount]+[LoyaltyReward.discountCurrency],
/// [percentageDiscount] needs [LoyaltyReward.discountPercentage],
/// [freeService] needs [LoyaltyReward.serviceId], [custom] needs none of
/// those -- the business explains it via description/terms alone.
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

/// Mirrors backend's LoyaltyAdminDtos.RewardResponse/RewardRequest -- one
/// entry in this business's redemption catalog. [id]/[redemptionsCount]/
/// [active] only exist server-side (never sent on create/update -- see
/// [toRequestJson]); a freshly-built draft (the "add reward" form's local
/// state before the first save) carries [id] null and [redemptionsCount]
/// zero.
class LoyaltyReward {
  final String? id;
  final String name;
  final String? description;
  final LoyaltyRewardType type;
  final int pointsCost;
  final double? discountAmount;
  final String? discountCurrency;
  final double? discountPercentage;
  final String? serviceId;
  final int? maxRedemptions;
  final int redemptionsCount;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool active;
  final String? terms;

  const LoyaltyReward({
    this.id,
    required this.name,
    this.description,
    required this.type,
    required this.pointsCost,
    this.discountAmount,
    this.discountCurrency,
    this.discountPercentage,
    this.serviceId,
    this.maxRedemptions,
    this.redemptionsCount = 0,
    this.startsAt,
    this.endsAt,
    this.active = true,
    this.terms,
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
      maxRedemptions: (json['maxRedemptions'] as num?)?.toInt(),
      redemptionsCount: (json['redemptionsCount'] as num).toInt(),
      startsAt: json['startsAt'] == null ? null : DateTime.parse(json['startsAt'] as String),
      endsAt: json['endsAt'] == null ? null : DateTime.parse(json['endsAt'] as String),
      active: json['active'] as bool,
      terms: json['terms'] as String?,
    );
  }

  /// The create/update body's shape -- everything the backend actually
  /// accepts, regardless of [type] (server-side validation rejects a
  /// mismatched combination; the form itself already only shows the fields
  /// that apply, see LoyaltyRewardFormScreen).
  Map<String, dynamic> toRequestJson() => {
        'name': name,
        'description': description,
        'type': type.toWire(),
        'pointsCost': pointsCost,
        'discountAmount': discountAmount,
        'discountCurrency': discountCurrency,
        'discountPercentage': discountPercentage,
        'serviceId': serviceId,
        'maxRedemptions': maxRedemptions,
        'startsAt': startsAt?.toUtc().toIso8601String(),
        'endsAt': endsAt?.toUtc().toIso8601String(),
        'terms': terms,
      };
}
