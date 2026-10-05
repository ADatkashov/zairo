/// Mirrors backend's PlatformAdminDtos.AdminSummary — one platform staff
/// account (the signed-in person, or a row in the staff directory).
class PlatformAdminAccount {
  final String id;
  final String email;
  final String displayName;
  final String role;
  final bool active;
  final String? avatarUrl;

  const PlatformAdminAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.active,
    this.avatarUrl,
  });

  factory PlatformAdminAccount.fromJson(Map<String, dynamic> json) {
    return PlatformAdminAccount(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      role: json['role'] as String,
      active: json['active'] as bool? ?? true,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  PlatformAdminAccount copyWith({String? displayName, String? role, String? avatarUrl, bool clearAvatar = false}) {
    return PlatformAdminAccount(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      active: active,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
    );
  }
}
