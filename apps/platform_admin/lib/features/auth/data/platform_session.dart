import 'jwt_expiry.dart';
import 'platform_admin_account.dart';
import 'platform_role.dart';

/// The signed-in staff account plus its access token. The token lives 30
/// minutes and there is no refresh token (see PlatformAdminJwtService), so
/// when [expiresAt] passes the person signs in again.
class PlatformSession {
  final String accessToken;
  final PlatformAdminAccount admin;
  final DateTime? expiresAt;

  const PlatformSession({required this.accessToken, required this.admin, this.expiresAt});

  factory PlatformSession.fromLoginJson(Map<String, dynamic> json) {
    final token = json['accessToken'] as String;
    return PlatformSession(
      accessToken: token,
      admin: PlatformAdminAccount.fromJson(json['admin'] as Map<String, dynamic>),
      expiresAt: jwtExpiry(token),
    );
  }

  PlatformPermissions get permissions => PlatformPermissions(admin.role);

  PlatformSession withAdmin(PlatformAdminAccount admin) =>
      PlatformSession(accessToken: accessToken, admin: admin, expiresAt: expiresAt);
}
