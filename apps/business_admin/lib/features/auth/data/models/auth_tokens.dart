import 'user_summary.dart';

/// Mirrors backend's AuthDtos.TokenResponse (backend/auth/.../AuthDtos.java).
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final UserSummary user;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
