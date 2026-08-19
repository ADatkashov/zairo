/// Mirrors backend's AuthDtos.UserSummary (backend/auth/.../AuthDtos.java).
class UserSummary {
  final String id;
  final String email;
  final String displayName;
  final String role;

  const UserSummary({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      role: json['role'] as String,
    );
  }
}
