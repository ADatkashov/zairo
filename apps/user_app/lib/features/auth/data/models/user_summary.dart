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

  const UserSummary({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.avatarUrl,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String,
      role: json['role'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
