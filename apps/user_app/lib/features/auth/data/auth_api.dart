import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import 'auth_exception.dart';
import 'models/auth_tokens.dart';
import 'models/identity_summary.dart';
import 'models/phone_status.dart';
import 'models/sms_mode.dart';
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

  /// Always succeeds, whether or not the email is registered — see
  /// backend's AuthService.forgotPassword doc comment (no leaking which
  /// emails exist). The reset code itself is only ever emailed, never
  /// returned here.
  Future<void> forgotPassword(String email) async {
    await _dioClient.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({required String token, required String newPassword}) async {
    try {
      await _dioClient.post(
        '/auth/reset-password',
        data: {'token': token, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException(AuthErrorKey.invalidResetToken);
      }
      rethrow;
    }
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

  /// Pass null to remove the avatar. [avatarUrl] should come from
  /// StorageApi.uploadBytes, not a user-typed URL.
  Future<UserSummary> updateAvatar(String? avatarUrl) async {
    final response = await _dioClient.patch(
      '/auth/me/avatar',
      data: {'avatarUrl': avatarUrl},
    );
    return UserSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// Every argument may be null to leave that field unchanged — see
  /// backend's AuthDtos.UpdateProfileRequest. Used both to complete a profile
  /// that started with a placeholder name/no email (Google/Facebook/phone
  /// signup) and by the Edit Profile screen. [clearBirthDate] removes a stored
  /// birth date (null alone means "unchanged"); [gender] 'NOT_SPECIFIED'
  /// clears the stored gender.
  Future<UserSummary> updateProfile({
    String? displayName,
    String? email,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? gender,
    bool? marketingConsent,
  }) async {
    try {
      final response = await _dioClient.patch(
        '/auth/me',
        data: {
          'displayName': displayName,
          'email': email,
          'birthDate': birthDate == null ? null : UserSummary.formatBirthDate(birthDate),
          'clearBirthDate': clearBirthDate,
          'gender': gender,
          'marketingConsent': marketingConsent,
        },
      );
      return UserSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const AuthException(AuthErrorKey.emailAlreadyRegistered);
      }
      rethrow;
    }
  }

  /// Irreversibly deletes the signed-in account -- see backend's
  /// AuthService.deleteAccount. [password] is required when the account has
  /// one; [confirmation] must be exactly `DELETE`.
  Future<void> deleteAccount({String? password, required String confirmation}) async {
    try {
      await _dioClient.post(
        '/auth/me/delete',
        data: {'password': password, 'confirmation': confirmation},
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      throw DeleteAccountException(
        statusCode: e.response?.statusCode,
        serverMessage: data is Map && data['message'] is String ? data['message'] as String : null,
      );
    }
  }

  /// Signs in or registers with a Google ID token obtained on-device via
  /// GoogleSignInService — see IdentityController.googleSignIn.
  Future<AuthTokens> loginWithGoogle(String idToken) async {
    try {
      final response = await _dioClient.post('/auth/google', data: {'idToken': idToken});
      return AuthTokens.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapProviderError(e);
    }
  }

  /// Links a Google account to the already-authenticated caller.
  Future<UserSummary> linkGoogle(String idToken) async {
    try {
      final response = await _dioClient.post('/auth/identities/google', data: {'idToken': idToken});
      return UserSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapProviderError(e);
    }
  }

  /// Signs in or registers with a Sign in with Apple identity token — see
  /// IdentityController.appleSignIn. [displayName] is only used when this
  /// creates a new account.
  Future<AuthTokens> loginWithApple(String identityToken, {String? displayName}) async {
    try {
      final response = await _dioClient.post(
        '/auth/apple',
        data: {'identityToken': identityToken, 'displayName': displayName},
      );
      return AuthTokens.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapProviderError(e);
    }
  }

  /// Links an Apple account to the already-authenticated caller.
  Future<UserSummary> linkApple(String identityToken) async {
    try {
      final response = await _dioClient.post('/auth/identities/apple', data: {'identityToken': identityToken});
      return UserSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapProviderError(e);
    }
  }

  /// Signs in or registers with a Facebook access token obtained on-device
  /// via FacebookSignInService — see IdentityController.facebookSignIn.
  Future<AuthTokens> loginWithFacebook(String accessToken) async {
    try {
      final response = await _dioClient.post('/auth/facebook', data: {'accessToken': accessToken});
      return AuthTokens.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapProviderError(e);
    }
  }

  /// Links a Facebook account to the already-authenticated caller.
  Future<UserSummary> linkFacebook(String accessToken) async {
    try {
      final response = await _dioClient.post('/auth/identities/facebook', data: {'accessToken': accessToken});
      return UserSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapProviderError(e);
    }
  }

  /// [phone] is sent exactly as typed — the backend normalizes it (see
  /// PhoneNumberNormalizer). Always resolves, whether or not this phone is
  /// already registered — see IdentityService.requestPhoneOtp's doc
  /// comment. Only rate-limiting fails, as [AuthErrorKey.otpResendCooldown]
  /// / [AuthErrorKey.tooManyOtpRequests] / [AuthErrorKey.invalidPhoneNumber].
  Future<void> requestPhoneOtp(String phone) async {
    try {
      await _dioClient.post('/auth/phone/request-otp', data: {'phone': phone});
    } on DioException catch (e) {
      throw _mapOtpRequestError(e);
    }
  }

  /// Verifies the 6-digit code and signs in/registers.
  Future<AuthTokens> verifyPhoneOtp({required String phone, required String code}) async {
    try {
      final response = await _dioClient.post(
        '/auth/phone/verify-otp',
        data: {'phone': phone, 'code': code},
      );
      return AuthTokens.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapOtpVerifyError(e);
    }
  }

  /// Verifies the 6-digit code and links this phone to the already-
  /// authenticated caller.
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

  /// Whether the server mocks SMS (pre-production) — the OTP screens then
  /// show the fixed code instead of waiting for a text message.
  Future<SmsMode> smsMode() async {
    final response = await _dioClient.get('/auth/phone/sms-mode');
    return SmsMode.fromJson(response.data as Map<String, dynamic>);
  }

  /// Which screen the phone sign-in shows next: the password prompt for an
  /// existing account, or SMS registration — see IdentityService.phoneStatus
  /// (it deliberately reveals whether a phone is registered).
  Future<PhoneStatus> phoneStatus(String phone) async {
    try {
      final response = await _dioClient.post('/auth/phone/status', data: {'phone': phone});
      return PhoneStatus.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapOtpRequestError(e);
    }
  }

  /// Phone + password sign-in — no SMS.
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

  /// First-time phone registration: SMS [code] + name + password.
  Future<AuthTokens> registerWithPhone({
    required String phone,
    required String code,
    required String displayName,
    required String password,
  }) async {
    try {
      final response = await _dioClient.post(
        '/auth/phone/register',
        data: {'phone': phone, 'code': code, 'displayName': displayName, 'password': password},
      );
      return AuthTokens.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapOtpVerifyError(e);
    }
  }

  /// Forgot password (or first password for an account that has none):
  /// the SMS [code] proves the phone.
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

  /// The answer to [AuthErrorKey.accountLinkRequired]: proves ownership of
  /// the existing email account by its [password] and connects the
  /// Google/Facebook sign-in ([provider] is 'GOOGLE' or 'FACEBOOK') to it.
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
      if (status == 401) {
        // Same status for "wrong password" and "bad provider token" — the
        // provider token was just verified one step earlier, so a 401 here
        // is almost always the password.
        throw const AuthException(AuthErrorKey.invalidCredentials);
      }
      throw _mapProviderError(e);
    }
  }

  /// Every sign-in method currently linked to the caller's own account —
  /// powers Settings > Security.
  Future<List<IdentitySummary>> listIdentities() async {
    final response = await _dioClient.get('/auth/identities');
    final identities = (response.data as Map<String, dynamic>)['identities'] as List<dynamic>;
    return identities.map((e) => IdentitySummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Audit-only — see AuthController.auditBiometricToggle. Never blocks the
  /// local biometric enable/disable flow: callers should fire-and-forget
  /// this (a failed audit call is not a reason to fail enabling biometrics
  /// on-device).
  Future<void> auditBiometricToggle(bool enabled) async {
    await _dioClient.post('/auth/me/biometric-audit', data: {'enabled': enabled});
  }

  AuthException _mapProviderError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) return const AuthException(AuthErrorKey.invalidProviderCredential);
    if (status == 409) {
      return _messageContains(e, 'account_link_required')
          ? const AuthException(AuthErrorKey.accountLinkRequired)
          : const AuthException(AuthErrorKey.emailAlreadyRegistered);
    }
    return AuthException(AuthErrorKey.invalidProviderCredential);
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

  /// Backend's ApiError.message text is stable enough to key off for
  /// disambiguating two exceptions that deliberately share one HTTP status
  /// (see e.g. InvalidOtpException/OtpExpiredException, both 401) — a
  /// pragmatic alternative to adding a machine-readable error code to
  /// every ApiError this codebase throws, which no other endpoint does
  /// either.
  bool _messageContains(DioException e, String needle) {
    final message = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
    return message is String && message.toLowerCase().contains(needle);
  }
}
