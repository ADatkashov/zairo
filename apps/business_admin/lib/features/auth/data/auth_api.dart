import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import 'auth_exception.dart';
import 'models/auth_tokens.dart';
import 'models/user_summary.dart';

/// Not final: tests substitute a subclass overriding these methods instead
/// of mocking Dio — same pattern as apps/user_app.
class AuthApi {
  final DioClient _dioClient;

  AuthApi(this._dioClient);

  /// Always registers as PROVIDER_OWNER — this app is where provider-owner
  /// accounts are created (Factory Blueprint §11); the consumer app
  /// (apps/user_app) always registers as CUSTOMER instead. Same backend
  /// endpoint, different literal role passed from each app's own AuthApi.
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
          'role': 'PROVIDER_OWNER',
        },
      );
      return AuthTokens.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const AuthException(AuthErrorKey.emailAlreadyRegistered);
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
        throw const AuthException(AuthErrorKey.invalidCredentials);
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

  Future<UserSummary> me(String accessToken) async {
    final response = await _dioClient.get(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return UserSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// Pass null to remove the avatar. [avatarUrl] should come from
  /// StorageApi.uploadBytes, not a user-typed URL.
  Future<UserSummary> updateAvatar(String? avatarUrl) async {
    final response = await _dioClient.patch(
      '/auth/me/avatar',
      data: {'avatarUrl': avatarUrl},
    );
    return UserSummary.fromJson(response.data as Map<String, dynamic>);
  }
}
