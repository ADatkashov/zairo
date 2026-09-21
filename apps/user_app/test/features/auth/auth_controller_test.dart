import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Override isn't exported from the main flutter_riverpod.dart barrel in
// Riverpod 3.x (see riverpod's own riverpod.dart vs. misc.dart) — needed
// here only to type _overrides' return value.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/auth_api.dart';
import 'package:zairo/features/auth/data/auth_exception.dart';
import 'package:zairo/features/auth/data/biometric_auth_service.dart';
import 'package:zairo/features/auth/data/facebook_sign_in_service.dart';
import 'package:zairo/features/auth/data/google_sign_in_service.dart';
import 'package:zairo/features/auth/data/models/auth_tokens.dart';
import 'package:zairo/features/auth/data/models/identity_summary.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(DioClient(Dio()));

  AuthTokens? loginResult;
  Object? loginError;
  bool meShouldSucceed = false;

  Object? googleError;
  Object? facebookError;
  Object? otpError;
  String? lastLinkedGoogleToken;
  String? lastLinkedFacebookToken;
  Map<String, String>? lastLinkedPhone;
  List<IdentitySummary> identities = const [];
  bool? lastBiometricAudit;

  static const _user = UserSummary(
    id: 'u1',
    email: 'a@example.com',
    displayName: 'Test User',
    role: 'CUSTOMER',
  );

  static const tokens = AuthTokens(
    accessToken: 'access-1',
    refreshToken: 'refresh-1',
    user: _user,
  );

  @override
  Future<UserSummary> me(String accessToken) async {
    if (meShouldSucceed) return _user;
    throw const AuthException(AuthErrorKey.invalidCredentials);
  }

  @override
  Future<AuthTokens> login({required String email, required String password}) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<AuthTokens> loginWithGoogle(String idToken) async {
    if (googleError != null) throw googleError!;
    return tokens;
  }

  @override
  Future<AuthTokens> loginWithFacebook(String accessToken) async {
    if (facebookError != null) throw facebookError!;
    return tokens;
  }

  @override
  Future<UserSummary> linkGoogle(String idToken) async {
    lastLinkedGoogleToken = idToken;
    return _user;
  }

  @override
  Future<UserSummary> linkFacebook(String accessToken) async {
    lastLinkedFacebookToken = accessToken;
    return _user;
  }

  @override
  Future<AuthTokens> verifyPhoneOtp({required String phone, required String code}) async {
    if (otpError != null) throw otpError!;
    return tokens;
  }

  @override
  Future<UserSummary> linkPhone({required String phone, required String code}) async {
    lastLinkedPhone = {'phone': phone, 'code': code};
    return _user;
  }

  @override
  Future<List<IdentitySummary>> listIdentities() async => identities;

  @override
  Future<void> auditBiometricToggle(bool enabled) async {
    lastBiometricAudit = enabled;
  }
}

class _InMemorySecureStorageService extends SecureStorageService {
  _InMemorySecureStorageService() : super(const FlutterSecureStorage());

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

class _FakeGoogleSignInService implements GoogleSignInService {
  String? idTokenToReturn = 'google-id-token';
  bool signOutCalled = false;

  @override
  Future<String?> signIn() async => idTokenToReturn;

  @override
  Future<void> signOut() async => signOutCalled = true;
}

class _FakeFacebookSignInService implements FacebookSignInService {
  String? accessTokenToReturn = 'facebook-access-token';
  bool signOutCalled = false;

  @override
  Future<String?> signIn() async => accessTokenToReturn;

  @override
  Future<void> signOut() async => signOutCalled = true;
}

class _FakeBiometricAuthService implements BiometricAuthService {
  bool available = true;
  bool authenticateResult = true;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async => authenticateResult;
}

List<Override> _overrides({
  AuthApi? api,
  SecureStorageService? storage,
  GoogleSignInService? google,
  FacebookSignInService? facebook,
  BiometricAuthService? biometric,
}) {
  return [
    authApiProvider.overrideWithValue(api ?? _FakeAuthApi()),
    secureStorageServiceProvider.overrideWithValue(storage ?? _InMemorySecureStorageService()),
    googleSignInServiceProvider.overrideWithValue(google ?? _FakeGoogleSignInService()),
    facebookSignInServiceProvider.overrideWithValue(facebook ?? _FakeFacebookSignInService()),
    biometricAuthServiceProvider.overrideWithValue(biometric ?? _FakeBiometricAuthService()),
  ];
}

void main() {
  test('starts logged out when there is no stored session', () async {
    final container = ProviderContainer(overrides: _overrides());
    addTearDown(container.dispose);

    final user = await container.read(authControllerProvider.future);
    expect(user, isNull);
  });

  test('login stores tokens, updates state and the shared token holder', () async {
    final fakeApi = _FakeAuthApi()..loginResult = _FakeAuthApi.tokens;
    final storage = _InMemorySecureStorageService();
    final container = ProviderContainer(overrides: _overrides(api: fakeApi, storage: storage));
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .login(email: 'a@example.com', password: 'password123');

    final state = container.read(authControllerProvider);
    expect(state.value?.email, 'a@example.com');
    expect(await storage.read('auth_access_token'), 'access-1');
    expect(await storage.read('auth_refresh_token'), 'refresh-1');
    expect(container.read(authTokenHolderProvider).accessToken, 'access-1');
  });

  test('failed login surfaces an error and does not store tokens', () async {
    final fakeApi = _FakeAuthApi()..loginError = const AuthException(AuthErrorKey.invalidCredentials);
    final storage = _InMemorySecureStorageService();
    final container = ProviderContainer(overrides: _overrides(api: fakeApi, storage: storage));
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .login(email: 'a@example.com', password: 'wrong');

    final state = container.read(authControllerProvider);
    expect(state.hasError, isTrue);
    expect(await storage.read('auth_access_token'), isNull);
  });

  test('restores the session from a stored access token on start', () async {
    final fakeApi = _FakeAuthApi()..meShouldSucceed = true;
    final storage = _InMemorySecureStorageService();
    await storage.write('auth_access_token', 'stored-access-token');

    final container = ProviderContainer(overrides: _overrides(api: fakeApi, storage: storage));
    addTearDown(container.dispose);

    final user = await container.read(authControllerProvider.future);
    expect(user?.email, 'a@example.com');
    expect(container.read(authTokenHolderProvider).accessToken, 'stored-access-token');
  });

  test('logout clears storage, the token holder, the state, and signs out of provider SDKs', () async {
    final fakeApi = _FakeAuthApi()..loginResult = _FakeAuthApi.tokens;
    final storage = _InMemorySecureStorageService();
    final google = _FakeGoogleSignInService();
    final facebook = _FakeFacebookSignInService();
    final container =
        ProviderContainer(overrides: _overrides(api: fakeApi, storage: storage, google: google, facebook: facebook));
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .login(email: 'a@example.com', password: 'password123');
    await container.read(authControllerProvider.notifier).logout();

    expect(container.read(authControllerProvider).value, isNull);
    expect(await storage.read('auth_access_token'), isNull);
    expect(container.read(authTokenHolderProvider).accessToken, isNull);
    expect(google.signOutCalled, isTrue);
    expect(facebook.signOutCalled, isTrue);
  });

  test('logging in with Google stores tokens from the returned session', () async {
    final fakeApi = _FakeAuthApi();
    final storage = _InMemorySecureStorageService();
    final container = ProviderContainer(overrides: _overrides(api: fakeApi, storage: storage));
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    await container.read(authControllerProvider.notifier).loginWithGoogle('a-google-id-token');

    expect(container.read(authControllerProvider).value?.id, 'u1');
    expect(await storage.read('auth_access_token'), 'access-1');
  });

  test('an invalid Google credential surfaces as an error, not a crash', () async {
    final fakeApi = _FakeAuthApi()..googleError = const AuthException(AuthErrorKey.invalidProviderCredential);
    final container = ProviderContainer(overrides: _overrides(api: fakeApi));
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    await container.read(authControllerProvider.notifier).loginWithGoogle('bad-token');

    expect(container.read(authControllerProvider).hasError, isTrue);
  });

  test('logging in with Facebook stores tokens from the returned session', () async {
    final fakeApi = _FakeAuthApi();
    final storage = _InMemorySecureStorageService();
    final container = ProviderContainer(overrides: _overrides(api: fakeApi, storage: storage));
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    await container.read(authControllerProvider.notifier).loginWithFacebook('a-facebook-token');

    expect(container.read(authControllerProvider).value?.id, 'u1');
    expect(await storage.read('auth_access_token'), 'access-1');
  });

  test('verifying a phone OTP stores tokens from the returned session', () async {
    final fakeApi = _FakeAuthApi();
    final storage = _InMemorySecureStorageService();
    final container = ProviderContainer(overrides: _overrides(api: fakeApi, storage: storage));
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .verifyPhoneOtp(phone: '+77001234567', code: '123456');

    expect(container.read(authControllerProvider).value?.id, 'u1');
    expect(await storage.read('auth_access_token'), 'access-1');
  });

  test('a wrong OTP surfaces as an error and does not store tokens', () async {
    final fakeApi = _FakeAuthApi()..otpError = const AuthException(AuthErrorKey.invalidOtp);
    final storage = _InMemorySecureStorageService();
    final container = ProviderContainer(overrides: _overrides(api: fakeApi, storage: storage));
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .verifyPhoneOtp(phone: '+77001234567', code: '000000');

    expect(container.read(authControllerProvider).hasError, isTrue);
    expect(await storage.read('auth_access_token'), isNull);
  });

  test('linking Google forwards the token and updates the cached user, without touching stored tokens', () async {
    final fakeApi = _FakeAuthApi()..meShouldSucceed = true;
    final storage = _InMemorySecureStorageService();
    await storage.write('auth_access_token', 'existing-token');
    final container = ProviderContainer(overrides: _overrides(api: fakeApi, storage: storage));
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    await container.read(authControllerProvider.notifier).linkGoogle('a-google-id-token');

    expect(fakeApi.lastLinkedGoogleToken, 'a-google-id-token');
    expect(container.read(authControllerProvider).value?.id, 'u1');
    // linking never rotates the caller's own session tokens.
    expect(await storage.read('auth_access_token'), 'existing-token');
  });

  test('linking a phone forwards phone+code', () async {
    final fakeApi = _FakeAuthApi()..meShouldSucceed = true;
    final container = ProviderContainer(overrides: _overrides(api: fakeApi));
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .linkPhone(phone: '+77001234567', code: '654321');

    expect(fakeApi.lastLinkedPhone, {'phone': '+77001234567', 'code': '654321'});
  });

  test('listIdentities returns whatever the backend reports', () async {
    final fakeApi = _FakeAuthApi()..identities = const [IdentitySummary(provider: 'GOOGLE')];
    final container = ProviderContainer(overrides: _overrides(api: fakeApi));
    addTearDown(container.dispose);

    final identities = await container.read(authControllerProvider.notifier).listIdentities();
    expect(identities.single.provider, 'GOOGLE');
  });

  group('biometric unlock', () {
    test('isBiometricAvailable delegates to BiometricAuthService', () async {
      final biometric = _FakeBiometricAuthService()..available = false;
      final container = ProviderContainer(overrides: _overrides(biometric: biometric));
      addTearDown(container.dispose);

      expect(await container.read(authControllerProvider.notifier).isBiometricAvailable(), isFalse);
    });

    test('enabling biometric requires a successful prompt first', () async {
      final biometric = _FakeBiometricAuthService()..authenticateResult = false;
      final storage = _InMemorySecureStorageService();
      final container = ProviderContainer(overrides: _overrides(biometric: biometric, storage: storage));
      addTearDown(container.dispose);

      final enabled = await container.read(authControllerProvider.notifier).enableBiometric();

      expect(enabled, isFalse);
      expect(await storage.read('auth_biometric_enabled') == 'true', isFalse);
    });

    test('enabling biometric persists the flag and audits the toggle once confirmed', () async {
      final fakeApi = _FakeAuthApi();
      final biometric = _FakeBiometricAuthService()..authenticateResult = true;
      final storage = _InMemorySecureStorageService();
      final container =
          ProviderContainer(overrides: _overrides(api: fakeApi, biometric: biometric, storage: storage));
      addTearDown(container.dispose);

      final enabled = await container.read(authControllerProvider.notifier).enableBiometric();
      // The audit call is fire-and-forget; give its microtask a chance to run.
      await Future<void>.delayed(Duration.zero);

      expect(enabled, isTrue);
      expect(await storage.read('auth_biometric_enabled') == 'true', isTrue);
      expect(fakeApi.lastBiometricAudit, isTrue);
    });

    test('disabling biometric clears the flag', () async {
      final storage = _InMemorySecureStorageService();
      await storage.write('auth_biometric_enabled', 'true');
      final container = ProviderContainer(overrides: _overrides(storage: storage));
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).disableBiometric();

      expect(await storage.read('auth_biometric_enabled') == 'true', isFalse);
    });

    test('a successful cold-start biometric prompt restores the stored session', () async {
      final fakeApi = _FakeAuthApi()..meShouldSucceed = true;
      final storage = _InMemorySecureStorageService();
      await storage.write('auth_access_token', 'stored-access-token');
      await storage.write('auth_biometric_enabled', 'true');
      final biometric = _FakeBiometricAuthService()..authenticateResult = true;
      final container = ProviderContainer(overrides: _overrides(api: fakeApi, storage: storage, biometric: biometric));
      addTearDown(container.dispose);

      final user = await container.read(authControllerProvider.future);

      expect(user?.id, 'u1');
    });

    test('a declined cold-start biometric prompt does not restore the session, and never sent it to the backend', () async {
      final fakeApi = _FakeAuthApi()..meShouldSucceed = true;
      final storage = _InMemorySecureStorageService();
      await storage.write('auth_access_token', 'stored-access-token');
      await storage.write('auth_biometric_enabled', 'true');
      final biometric = _FakeBiometricAuthService()..authenticateResult = false;
      final container = ProviderContainer(overrides: _overrides(api: fakeApi, storage: storage, biometric: biometric));
      addTearDown(container.dispose);

      final user = await container.read(authControllerProvider.future);

      expect(user, isNull);
      // The stored session is untouched (not cleared) -- a relaunch can retry the prompt.
      expect(await storage.read('auth_access_token'), 'stored-access-token');
    });

    test('logout turns biometric unlock back off', () async {
      final fakeApi = _FakeAuthApi()..loginResult = _FakeAuthApi.tokens;
      final storage = _InMemorySecureStorageService();
      final container = ProviderContainer(overrides: _overrides(api: fakeApi, storage: storage));
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'a@example.com', password: 'password123');
      await storage.write('auth_biometric_enabled', 'true');
      await container.read(authControllerProvider.notifier).logout();

      expect(await storage.read('auth_biometric_enabled') == 'true', isFalse);
    });
  });
}
