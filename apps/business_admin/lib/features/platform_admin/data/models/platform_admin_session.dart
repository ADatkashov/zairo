/// The signed-in platform account plus its access token — mirrors the
/// backend's `platformadmin.PlatformAdminDtos.TokenResponse`. Kept in memory
/// only (see `platform_admin_providers.dart`): no refresh token exists in
/// this phase, so there's nothing durable worth persisting to storage.
class PlatformAdminSession {
  final String accessToken;
  final String email;
  final String displayName;
  final String role;
  final String? avatarUrl;

  const PlatformAdminSession({
    required this.accessToken,
    required this.email,
    required this.displayName,
    required this.role,
    this.avatarUrl,
  });

  factory PlatformAdminSession.fromJson(Map<String, dynamic> json) {
    final admin = json['admin'] as Map<String, dynamic>;
    return PlatformAdminSession(
      accessToken: json['accessToken'] as String,
      email: admin['email'] as String,
      displayName: admin['displayName'] as String,
      role: admin['role'] as String,
      avatarUrl: admin['avatarUrl'] as String?,
    );
  }

  /// Same accessToken — only the profile fields change after a PATCH
  /// /platform/auth/me/avatar response (an AdminSummary, not a fresh
  /// TokenResponse).
  PlatformAdminSession copyWithAdmin({required String displayName, required String role, String? avatarUrl}) {
    return PlatformAdminSession(
      accessToken: accessToken,
      email: email,
      displayName: displayName,
      role: role,
      avatarUrl: avatarUrl,
    );
  }

  bool get isPlatformAdmin => role == 'PLATFORM_ADMIN';

  /// PLATFORM_ADMIN or PLATFORM_MODERATOR — the two roles that can approve,
  /// suspend, or reinstate a business. PLATFORM_SUPPORT stays read-only.
  bool get canModerateBusinesses => role == 'PLATFORM_ADMIN' || role == 'PLATFORM_MODERATOR';
}
