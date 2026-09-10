/// Mirrors backend's PlatformAdminDtos.AdminSummary
/// (backend/platform-admin/.../PlatformAdminDtos.java) — one row in the
/// Control Center's staff directory.
class PlatformAdminAccountSummary {
  final String id;
  final String email;
  final String displayName;
  final String role;
  final bool active;
  final String? avatarUrl;

  const PlatformAdminAccountSummary({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.active,
    this.avatarUrl,
  });

  factory PlatformAdminAccountSummary.fromJson(Map<String, dynamic> json) {
    return PlatformAdminAccountSummary(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      role: json['role'] as String,
      active: json['active'] as bool,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
