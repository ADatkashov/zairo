/// Mirrors backend's LoyaltyAdminDtos.LoyaltySettingsResponse /
/// UpdateLoyaltySettingsRequest (backend/loyalty/.../LoyaltyAdminDtos.java).
/// `GET .../loyalty/settings` auto-creates a disabled draft on first call
/// and never 404s -- [LoyaltyAdminApi.fetchSettings] always returns
/// something to render, even for a business that's never opened this
/// screen. `PUT .../loyalty/settings` is a full replace, not a patch: every
/// field below (minus [providerId]) is sent back on every save, via
/// [toUpdateJson].
class LoyaltySettings {
  final String providerId;
  final bool enabled;
  final String name;
  final String? description;
  final int fixedPointsPerBooking;
  final double pointsPerCurrencyUnit;
  final int firstBookingBonusPoints;
  final int repeatVisitBonusPoints;
  final int repeatVisitThreshold;
  final int reviewBonusPoints;
  final double? pointsPerCurrencyUnitRedemption;
  final int? minRedemptionPoints;
  final int? maxRedemptionPointsPerBooking;
  final bool pointsExpireEnabled;
  final int? pointsExpirationMonths;
  final int? dailyEarningPointsCap;
  final int? monthlyEarningPointsCap;

  const LoyaltySettings({
    required this.providerId,
    required this.enabled,
    required this.name,
    this.description,
    required this.fixedPointsPerBooking,
    required this.pointsPerCurrencyUnit,
    required this.firstBookingBonusPoints,
    required this.repeatVisitBonusPoints,
    required this.repeatVisitThreshold,
    required this.reviewBonusPoints,
    this.pointsPerCurrencyUnitRedemption,
    this.minRedemptionPoints,
    this.maxRedemptionPointsPerBooking,
    required this.pointsExpireEnabled,
    this.pointsExpirationMonths,
    this.dailyEarningPointsCap,
    this.monthlyEarningPointsCap,
  });

  factory LoyaltySettings.fromJson(Map<String, dynamic> json) {
    return LoyaltySettings(
      providerId: json['providerId'] as String,
      enabled: json['enabled'] as bool,
      name: json['name'] as String,
      description: json['description'] as String?,
      fixedPointsPerBooking: (json['fixedPointsPerBooking'] as num).toInt(),
      pointsPerCurrencyUnit: (json['pointsPerCurrencyUnit'] as num).toDouble(),
      firstBookingBonusPoints: (json['firstBookingBonusPoints'] as num).toInt(),
      repeatVisitBonusPoints: (json['repeatVisitBonusPoints'] as num).toInt(),
      repeatVisitThreshold: (json['repeatVisitThreshold'] as num).toInt(),
      reviewBonusPoints: (json['reviewBonusPoints'] as num).toInt(),
      pointsPerCurrencyUnitRedemption: (json['pointsPerCurrencyUnitRedemption'] as num?)?.toDouble(),
      minRedemptionPoints: (json['minRedemptionPoints'] as num?)?.toInt(),
      maxRedemptionPointsPerBooking: (json['maxRedemptionPointsPerBooking'] as num?)?.toInt(),
      pointsExpireEnabled: json['pointsExpireEnabled'] as bool,
      pointsExpirationMonths: (json['pointsExpirationMonths'] as num?)?.toInt(),
      dailyEarningPointsCap: (json['dailyEarningPointsCap'] as num?)?.toInt(),
      monthlyEarningPointsCap: (json['monthlyEarningPointsCap'] as num?)?.toInt(),
    );
  }

  /// The PUT body's shape -- every field except [providerId], all present
  /// (even when null) since the backend replaces the whole settings row.
  Map<String, dynamic> toUpdateJson() => {
        'enabled': enabled,
        'name': name,
        'description': description,
        'fixedPointsPerBooking': fixedPointsPerBooking,
        'pointsPerCurrencyUnit': pointsPerCurrencyUnit,
        'firstBookingBonusPoints': firstBookingBonusPoints,
        'repeatVisitBonusPoints': repeatVisitBonusPoints,
        'repeatVisitThreshold': repeatVisitThreshold,
        'reviewBonusPoints': reviewBonusPoints,
        'pointsPerCurrencyUnitRedemption': pointsPerCurrencyUnitRedemption,
        'minRedemptionPoints': minRedemptionPoints,
        'maxRedemptionPointsPerBooking': maxRedemptionPointsPerBooking,
        'pointsExpireEnabled': pointsExpireEnabled,
        'pointsExpirationMonths': pointsExpirationMonths,
        'dailyEarningPointsCap': dailyEarningPointsCap,
        'monthlyEarningPointsCap': monthlyEarningPointsCap,
      };

  LoyaltySettings copyWith({
    bool? enabled,
    String? name,
    String? description,
    bool clearDescription = false,
    int? fixedPointsPerBooking,
    double? pointsPerCurrencyUnit,
    int? firstBookingBonusPoints,
    int? repeatVisitBonusPoints,
    int? repeatVisitThreshold,
    int? reviewBonusPoints,
    double? pointsPerCurrencyUnitRedemption,
    bool clearPointsPerCurrencyUnitRedemption = false,
    int? minRedemptionPoints,
    bool clearMinRedemptionPoints = false,
    int? maxRedemptionPointsPerBooking,
    bool clearMaxRedemptionPointsPerBooking = false,
    bool? pointsExpireEnabled,
    int? pointsExpirationMonths,
    bool clearPointsExpirationMonths = false,
    int? dailyEarningPointsCap,
    bool clearDailyEarningPointsCap = false,
    int? monthlyEarningPointsCap,
    bool clearMonthlyEarningPointsCap = false,
  }) {
    return LoyaltySettings(
      providerId: providerId,
      enabled: enabled ?? this.enabled,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      fixedPointsPerBooking: fixedPointsPerBooking ?? this.fixedPointsPerBooking,
      pointsPerCurrencyUnit: pointsPerCurrencyUnit ?? this.pointsPerCurrencyUnit,
      firstBookingBonusPoints: firstBookingBonusPoints ?? this.firstBookingBonusPoints,
      repeatVisitBonusPoints: repeatVisitBonusPoints ?? this.repeatVisitBonusPoints,
      repeatVisitThreshold: repeatVisitThreshold ?? this.repeatVisitThreshold,
      reviewBonusPoints: reviewBonusPoints ?? this.reviewBonusPoints,
      pointsPerCurrencyUnitRedemption: clearPointsPerCurrencyUnitRedemption
          ? null
          : (pointsPerCurrencyUnitRedemption ?? this.pointsPerCurrencyUnitRedemption),
      minRedemptionPoints: clearMinRedemptionPoints ? null : (minRedemptionPoints ?? this.minRedemptionPoints),
      maxRedemptionPointsPerBooking: clearMaxRedemptionPointsPerBooking
          ? null
          : (maxRedemptionPointsPerBooking ?? this.maxRedemptionPointsPerBooking),
      pointsExpireEnabled: pointsExpireEnabled ?? this.pointsExpireEnabled,
      pointsExpirationMonths:
          clearPointsExpirationMonths ? null : (pointsExpirationMonths ?? this.pointsExpirationMonths),
      dailyEarningPointsCap:
          clearDailyEarningPointsCap ? null : (dailyEarningPointsCap ?? this.dailyEarningPointsCap),
      monthlyEarningPointsCap:
          clearMonthlyEarningPointsCap ? null : (monthlyEarningPointsCap ?? this.monthlyEarningPointsCap),
    );
  }
}
