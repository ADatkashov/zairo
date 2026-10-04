/// Mirrors backend's LoyaltyAdminDtos.BirthdayResponse: one member who
/// opted in to greetings and has a birthday coming up. Month/day only --
/// the backend never exposes the birth year (age) to the business.
class LoyaltyBirthday {
  final String userId;
  final String? displayName;
  final int month;
  final int day;

  /// 0 = today.
  final int daysUntil;

  /// What the program grants on the birthday; 0 = no bonus configured.
  final int bonusPoints;

  /// True once today's bonus was granted (only ever true for [daysUntil] 0).
  final bool bonusAwarded;

  const LoyaltyBirthday({
    required this.userId,
    required this.displayName,
    required this.month,
    required this.day,
    required this.daysUntil,
    required this.bonusPoints,
    required this.bonusAwarded,
  });

  factory LoyaltyBirthday.fromJson(Map<String, dynamic> json) {
    return LoyaltyBirthday(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String?,
      month: (json['month'] as num).toInt(),
      day: (json['day'] as num).toInt(),
      daysUntil: (json['daysUntil'] as num).toInt(),
      bonusPoints: (json['bonusPoints'] as num).toInt(),
      bonusAwarded: json['bonusAwarded'] as bool? ?? false,
    );
  }
}
