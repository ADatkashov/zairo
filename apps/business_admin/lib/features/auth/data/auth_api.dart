import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import 'auth_exception.dart';
import 'models/auth_tokens.dart';
import 'models/identity_summary.dart';
import 'models/phone_status.dart';
import 'models/sms_mode.dart';
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

  /// Always succeeds, whether or not the email is registered (no leaking
  /// which emails exist) — same endpoint the consumer app uses.
  Future<void> forgotPassword(String email) async {
    await _dioClient.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({required String token, required String newPassword}) async {
    try {
      await _dioClient.post('/auth/reset-password', data: {'token': token, 'newPassword': newPassword});
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException(AuthErrorKey.invalidResetToken);
      }
      rethrow;
    }
  }

  // ---- Google / Apple (new accounts created here are PROVIDER_OWNER) ----------

  Future<AuthTokens> loginWithGoogle(String idToken) async {
    try {
      final response = await _dioClient.post(
        '/auth/google',
        data: {'idToken': idToken, 'role': 'PROVIDER_OWNER'},
      );
      return AuthTokens.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapProviderError(e);
    }
  }

  Future<AuthTokens> loginWithApple(String identityToken, {String? displayName}) async {
    try {
      final response = await _dioClient.post(
        '/auth/apple',
        data: {'identityToken': identityToken, 'displayName': displayName, 'role': 'PROVIDER_OWNER'},
      );
      return AuthTokens.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapProviderError(e);
    }
  }

  /// The answer to [AuthErrorKey.accountLinkRequired]: proves ownership of
  /// the existing email account by its [password] and connects the
  /// Google/Apple sign-in ([provider] is 'GOOGLE' or 'APPLE') to it.
  Future<AuthTokens> linkProviderWithPassword({
    required String provider,
    required String token,
    required String password,
  }) async {
    try {
      final response = await _dioClient.post(
        '/auth/identities/link-with-password',
        data: {'provider': provider, 'token': token, 'password': password},
      );
      return AuthTokens.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 429) throw const AuthException(AuthErrorKey.tooManyLoginAttempts);
      if (status == 401) throw const AuthException(AuthErrorKey.invalidCredentials);
      throw _mapProviderError(e);
    }
  }

  // ---- Linked accounts: add a sign-in method to the signed-in owner's account --

  Future<List<IdentitySummary>> listIdentities() async {
    final response = await _dioClient.get('/auth/identities');
    final identities = (response.data as Map<String, dynamic>)['identities'] as List<dynamic>;
    return identities.map((e) => IdentitySummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UserSummary> linkGoogle(String idToken) async {
    try {
      final response = await _dioClient.post('/auth/identities/google', data: {'idToken': idToken});
      return UserSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapProviderError(e);
    }
  }

  Future<UserSummary> linkApple(String identityToken) async {
    try {
      final response = await _dioClient.post('/auth/identities/apple', data: {'identityToken': identityToken});
      return UserSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapProviderError(e);
    }
  }

  /// Verifies the SMS [code] and links this phone to the signed-in account.
  Future<UserSummary> linkPhone({required String phone, required String code}) async {
    try {
      final response = await _dioClient.post(
        '/auth/identities/phone/verify-otp',
        data: {'phone': phone, 'code': code},
      );
      return UserSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapOtpVerifyError(e);
    }
  }

  // ---- Phone: password sign-in, SMS only to register / reset -----------------

  /// Whether the server mocks SMS (pre-production) — the code screens then
  /// show the fixed code instead of waiting for a text message.
  Future<SmsMode> smsMode() async {
    final response = await _dioClient.get('/auth/phone/sms-mode');
    return SmsMode.fromJson(response.data as Map<String, dynamic>);
  }

  /// Which screen phone sign-in shows next: the password prompt for an
  /// existing account, or SMS registration.
  Future<PhoneStatus> phoneStatus(String phone) async {
    try {
      final response = await _dioClient.post('/auth/phone/status', data: {'phone': phone});
      return PhoneStatus.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapOtpRequestError(e);
    }
  }

  Future<void> requestPhoneOtp(String phone) async {
    try {
      await _dioClient.post('/auth/phone/request-otp', data: {'phone': phone});
    } on DioException catch (e) {
      throw _mapOtpRequestError(e);
    }
  }

  Future<AuthTokens> loginWithPhonePassword({required String phone, required String password}) async {
    try {
      final response = await _dioClient.post(
        '/auth/phone/login',
        data: {'phone': phone, 'password': password},
      );
      return AuthTokens.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) throw const AuthException(AuthErrorKey.invalidCredentials);
      if (status == 429) throw const AuthException(AuthErrorKey.tooManyLoginAttempts);
      rethrow;
    }
  }

  /// First-time phone registration of a PROVIDER_OWNER: SMS [code] + name + password.
  Future<AuthTokens> registerWithPhone({
    required String phone,
    required String code,
    required String displayName,
    required String password,
  }) async {
    try {
      final response = await _dioClient.post(
        '/auth/phone/register',
        data: {
          'phone': phone,
          'code': code,
          'displayName': displayName,
          'password': password,
          'role': 'PROVIDER_OWNER',
        },
      );
      return AuthTokens.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapOtpVerifyError(e);
    }
  }

  Future<void> resetPasswordWithPhone({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _dioClient.post(
        '/auth/phone/reset-password',
        data: {'phone': phone, 'code': code, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      throw _mapOtpVerifyError(e);
    }
  }

  AuthException _mapProviderError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) return const AuthException(AuthErrorKey.invalidProviderCredential);
    if (status == 409) {
      return _messageContains(e, 'account_link_required')
          ? const AuthException(AuthErrorKey.accountLinkRequired)
          : const AuthException(AuthErrorKey.emailAlreadyRegistered);
    }
    return const AuthException(AuthErrorKey.invalidProviderCredential);
  }

  AuthException _mapOtpRequestError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 400) {
      return _messageContains(e, 'not supported')
          ? const AuthException(AuthErrorKey.phoneCountryNotSupported)
          : const AuthException(AuthErrorKey.invalidPhoneNumber);
    }
    if (status == 429) {
      return _messageContains(e, 'wait')
          ? const AuthException(AuthErrorKey.otpResendCooldown)
          : const AuthException(AuthErrorKey.tooManyOtpRequests);
    }
    return const AuthException(AuthErrorKey.invalidPhoneNumber);
  }

  AuthException _mapOtpVerifyError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) {
      return _messageContains(e, 'expired')
          ? const AuthException(AuthErrorKey.otpExpired)
          : const AuthException(AuthErrorKey.invalidOtp);
    }
    if (status == 429) return const AuthException(AuthErrorKey.tooManyOtpAttempts);
    if (status == 409) return const AuthException(AuthErrorKey.identityAlreadyLinked);
    return const AuthException(AuthErrorKey.invalidOtp);
  }

  /// The backend's ApiError.message is stable enough to tell apart two
  /// exceptions that share one HTTP status (e.g. a wrong vs. an expired code).
  bool _messageContains(DioException e, String needle) {
    final message = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
    return message is String && message.toLowerCase().contains(needle);
  }

  Future<UserSummary> me(String accessToken) async {
    final response = await _dioClient.get(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return UserSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// Audit-only — never blocks the local biometric enable/disable flow: callers
  /// fire-and-forget (a failed audit call is no reason to fail enabling
  /// biometrics on-device). The backend never stores biometric data.
  Future<void> auditBiometricToggle(bool enabled) async {
    await _dioClient.post('/auth/me/biometric-audit', data: {'enabled': enabled});
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
