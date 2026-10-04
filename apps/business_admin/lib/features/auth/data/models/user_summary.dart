/// Mirrors backend's AuthDtos.UserSummary (backend/auth/.../AuthDtos.java).
/// [email] is nullable: an account created by phone (or by Apple/Google with a
/// hidden email) has none.
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
