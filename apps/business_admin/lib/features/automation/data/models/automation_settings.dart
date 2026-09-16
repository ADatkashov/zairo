/// Mirrors backend's `AutomationDtos.AutomationSettingsResponse`/
/// `UpdateAutomationSettingsRequest` -- the two share one shape on the wire,
/// so one model covers both directions, same as [LoyaltySettings]. Every
/// tuning field is nullable: null means "use the platform's own global
/// default for that engine", never zero/off.
class AutomationSettings {
  final bool rebookEnabled;
  final bool reactivationEnabled;
  final bool smartFillEnabled;
  final int? rebookMinVisitsToEstablishInterval;
  final int? rebookMinIntervalDays;
  final int? rebookMaxIntervalDays;
  final int? rebookFollowUpWindowDays;
  final int? reactivationScanMinInactivityDays;
  final double? reactivationIntervalMultiplier;
  final int? reactivationAbsoluteMaxInactivityDays;
  final int? reactivationFollowUpWindowDays;
  final int? allowedHoursStart;
  final int? allowedHoursEnd;
  final String? timezone;
  final int? cooldownDaysBetweenOffers;

  const AutomationSettings({
    required this.rebookEnabled,
    required this.reactivationEnabled,
    required this.smartFillEnabled,
    this.rebookMinVisitsToEstablishInterval,
    this.rebookMinIntervalDays,
    this.rebookMaxIntervalDays,
    this.rebookFollowUpWindowDays,
    this.reactivationScanMinInactivityDays,
    this.reactivationIntervalMultiplier,
    this.reactivationAbsoluteMaxInactivityDays,
    this.reactivationFollowUpWindowDays,
    this.allowedHoursStart,
    this.allowedHoursEnd,
    this.timezone,
    this.cooldownDaysBetweenOffers,
  });

  factory AutomationSettings.fromJson(Map<String, dynamic> json) {
    return AutomationSettings(
      rebookEnabled: json['rebookEnabled'] as bool,
      reactivationEnabled: json['reactivationEnabled'] as bool,
      smartFillEnabled: json['smartFillEnabled'] as bool,
      rebookMinVisitsToEstablishInterval: (json['rebookMinVisitsToEstablishInterval'] as num?)?.toInt(),
      rebookMinIntervalDays: (json['rebookMinIntervalDays'] as num?)?.toInt(),
      rebookMaxIntervalDays: (json['rebookMaxIntervalDays'] as num?)?.toInt(),
      rebookFollowUpWindowDays: (json['rebookFollowUpWindowDays'] as num?)?.toInt(),
      reactivationScanMinInactivityDays: (json['reactivationScanMinInactivityDays'] as num?)?.toInt(),
      reactivationIntervalMultiplier: (json['reactivationIntervalMultiplier'] as num?)?.toDouble(),
      reactivationAbsoluteMaxInactivityDays: (json['reactivationAbsoluteMaxInactivityDays'] as num?)?.toInt(),
      reactivationFollowUpWindowDays: (json['reactivationFollowUpWindowDays'] as num?)?.toInt(),
      allowedHoursStart: (json['allowedHoursStart'] as num?)?.toInt(),
      allowedHoursEnd: (json['allowedHoursEnd'] as num?)?.toInt(),
      timezone: json['timezone'] as String?,
      cooldownDaysBetweenOffers: (json['cooldownDaysBetweenOffers'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toUpdateJson() => {
        'rebookEnabled': rebookEnabled,
        'reactivationEnabled': reactivationEnabled,
        'smartFillEnabled': smartFillEnabled,
        'rebookMinVisitsToEstablishInterval': rebookMinVisitsToEstablishInterval,
        'rebookMinIntervalDays': rebookMinIntervalDays,
        'rebookMaxIntervalDays': rebookMaxIntervalDays,
        'rebookFollowUpWindowDays': rebookFollowUpWindowDays,
        'reactivationScanMinInactivityDays': reactivationScanMinInactivityDays,
        'reactivationIntervalMultiplier': reactivationIntervalMultiplier,
        'reactivationAbsoluteMaxInactivityDays': reactivationAbsoluteMaxInactivityDays,
        'reactivationFollowUpWindowDays': reactivationFollowUpWindowDays,
        'allowedHoursStart': allowedHoursStart,
        'allowedHoursEnd': allowedHoursEnd,
        'timezone': timezone,
        'cooldownDaysBetweenOffers': cooldownDaysBetweenOffers,
      };
}
