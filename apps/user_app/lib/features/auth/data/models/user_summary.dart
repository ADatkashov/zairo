/// Mirrors backend's AuthDtos.UserSummary (backend/auth/.../AuthDtos.java).
/// [email] is nullable — a phone-only signup (POST /auth/phone/verify-otp)
/// or a Facebook signup that didn't grant the email permission has none
/// yet; see PATCH /auth/me (AuthApi.updateProfile) for how it gets filled
/// in later.
class UserSummary {
  final String id;
  final String? email;
  final String displayName;
  final String role;
  final String? avatarUrl;

  /// Date only (no time zone) — used by businesses for birthday greetings
  /// and bonuses. Null until the customer fills it in.
  final DateTime? birthDate;

  /// 'FEMALE' | 'MALE', or null for "prefer not to say".
  final String? gender;

  /// Opt-in to birthday greetings, bonuses and offers.
  final bool marketingConsent;

  const UserSummary({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    this.birthDate,
    this.gender,
    this.marketingConsent = false,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String,
      role: json['role'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      birthDate: parseBirthDate(json['birthDate'] as String?),
      gender: json['gender'] as String?,
      marketingConsent: json['marketingConsent'] as bool? ?? false,
    );
  }

  /// Parses the backend's ISO `yyyy-MM-dd` as a local calendar date, so the
  /// day never shifts with the device's time zone.
  static DateTime? parseBirthDate(String? value) {
    if (value == null || value.length < 10) return null;
    final parts = value.substring(0, 10).split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Inverse of [parseBirthDate] — the `yyyy-MM-dd` the backend expects.
  static String formatBirthDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
