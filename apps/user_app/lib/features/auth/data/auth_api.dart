import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import 'auth_exception.dart';
import 'models/auth_tokens.dart';
import 'models/user_summary.dart';

/// Not final: tests substitute a subclass overriding these methods instead
/// of mocking Dio — same pattern as DiscoveryApi.
class AuthApi {
  final DioClient _dioClient;

  AuthApi(this._dioClient);

  Future<AuthTokens> register({
    required String email,
    required String password,
    required String displayName,
    required String phone,
  }) async {
    try {
      final response = await _dioClient.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'displayName': displayName,
          'phone': phone,
          'role': 'CUSTOMER',
        },
      );
      return AuthTokens.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const AuthException('This email is already registered.');
      }
      rethrow;
    }
  }

  Future<AuthTokens> login({required String email, required String password}) async {
    try {
      final response = await _dioClient.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return AuthTokens.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('Invalid email or password.');
      }
      rethrow;
    }
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    final response = await _dioClient.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return AuthTokens.fromJson(response.data as Map<String, dynamic>);
  }

  /// Passes [accessToken] explicitly via the Authorization header rather
  /// than relying on core_network's AuthTokenHolder — this is used during
  /// app-start bootstrap, before AuthController has confirmed the token is
  /// still valid and pushed it into the holder for the rest of the app.
  Future<UserSummary> me(String accessToken) async {
    final response = await _dioClient.get(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return UserSummary.fromJson(response.data as Map<String, dynamic>);
  }
}
