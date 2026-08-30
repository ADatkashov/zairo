/// The signed-in platform account plus its access token — mirrors the
/// backend's `platformadmin.PlatformAdminDtos.TokenResponse`. Kept in memory
/// only (see `platform_admin_providers.dart`): no refresh token exists in
/// this phase, so there's nothing durable worth persisting to storage.
class PlatformAdminSession {
  final String accessToken;
  final String email;
  final String displayName;
  final String role;

  const PlatformAdminSession({
    required this.accessToken,
    required this.email,
    required this.displayName,
    required this.role,
  });

  factory PlatformAdminSession.fromJson(Map<String, dynamic> json) {
    final admin = json['admin'] as Map<String, dynamic>;
    return PlatformAdminSession(
      accessToken: json['accessToken'] as String,
      email: admin['email'] as String,
      displayName: admin['displayName'] as String,
      role: admin['role'] as String,
    );
  }

  bool get isPlatformAdmin => role == 'PLATFORM_ADMIN';
}
