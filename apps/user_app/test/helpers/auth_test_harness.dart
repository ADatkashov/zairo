import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zairo/features/auth/data/apple_sign_in_service.dart';
import 'package:zairo/features/auth/data/auth_api.dart';
import 'package:zairo/features/auth/data/biometric_auth_service.dart';
import 'package:zairo/features/auth/data/google_sign_in_service.dart';
import 'package:zairo/features/auth/data/models/auth_tokens.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/l10n/app_localizations.dart';

/// Shared scaffolding for auth screen widget tests: a recording [AuthApi]
/// fake, in-memory secure storage, and "nothing available" sign-in services,
/// wired into a themed, localized [MaterialApp] by [wrapAuthScreen].
class RecordingAuthApi extends AuthApi {
  RecordingAuthApi() : super(DioClient(Dio()));

  static const user = UserSummary(
    id: 'u1',
    email: 'a@example.com',
    displayName: 'Test User',
    role: 'CUSTOMER',
  );

  static const tokens = AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1', user: user);

  Object? error;
  final List<Map<String, String>> registerCalls = [];

  @override
  Future<AuthTokens> register({
    required String email,
    required String password,
    required String displayName,
    required String phone,
  }) async {
    registerCalls.add({'email': email, 'password': password, 'displayName': displayName, 'phone': phone});
    if (error != null) throw error!;
    return tokens;
  }
}

class InMemorySecureStorage extends SecureStorageService {
  InMemorySecureStorage() : super(const FlutterSecureStorage());

  final Map<String, String> _store = {};

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();
}

class _NoApple implements AppleSignInService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<AppleSignInResult?> signIn() async => null;
}

class _CancelledGoogle implements GoogleSignInService {
  @override
  Future<String?> signIn() async => null;

  @override
  Future<void> signOut() async {}
}

class _NoBiometrics implements BiometricAuthService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

Widget wrapAuthScreen(Widget screen, AuthApi api) {
  return ProviderScope(
    overrides: [
      authApiProvider.overrideWithValue(api),
      secureStorageServiceProvider.overrideWithValue(InMemorySecureStorage()),
      appleSignInServiceProvider.overrideWithValue(_NoApple()),
      googleSignInServiceProvider.overrideWithValue(_CancelledGoogle()),
      biometricAuthServiceProvider.overrideWithValue(_NoBiometrics()),
    ],
    child: MaterialApp(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: screen,
    ),
  );
}
