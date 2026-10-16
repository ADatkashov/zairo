import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/auth_api.dart';
import 'package:zairo/features/auth/data/auth_exception.dart';
import 'package:zairo/features/auth/data/biometric_auth_service.dart';
import 'package:zairo/features/auth/data/facebook_sign_in_service.dart';
import 'package:zairo/features/auth/data/google_sign_in_service.dart';
import 'package:zairo/features/auth/data/models/auth_tokens.dart';
import 'package:zairo/features/auth/data/models/phone_status.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';

const _user = UserSummary(
  id: 'u1',
  email: 'a@example.com',
  displayName: 'Dana',
  role: 'CUSTOMER',
);
const _renamed = UserSummary(
  id: 'u1',
  email: 'a@example.com',
  displayName: 'Dana K.',
  role: 'CUSTOMER',
);
const _tokens = AuthTokens(
  accessToken: 'access-1',
  refreshToken: 'refresh-1',
  user: _user,
);
const _refreshed = AuthTokens(
  accessToken: 'access-2',
  refreshToken: 'refresh-2',
  user: _user,
);

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(DioClient(Dio()));

  final List<String> calls = [];
  bool refreshWorks = true;
  Object? deleteError;

  @override
  Future<UserSummary> me(String accessToken) async =>
      throw const AuthException(AuthErrorKey.invalidCredentials);

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    calls.add('refresh $refreshToken');
    if (!refreshWorks) {
      throw const AuthException(AuthErrorKey.invalidCredentials);
    }
    return _refreshed;
  }

  @override
  Future<AuthTokens> loginWithApple(
    String identityToken, {
    String? displayName,
  }) async {
    calls.add('apple $identityToken $displayName');
    return _tokens;
  }

  @override
  Future<AuthTokens> linkProviderWithPassword({
    required String provider,
    required String token,
    required String password,
  }) async {
    calls.add('link $provider $token $password');
    return _tokens;
  }

  @override
  Future<AuthTokens> loginWithPhonePassword({
    required String phone,
    required String password,
  }) async {
    calls.add('phone-login $phone $password');
    return _tokens;
  }

  @override
  Future<AuthTokens> registerWithPhone({
    required String phone,
    required String code,
    required String displayName,
    required String password,
  }) async {
    calls.add('register $phone $code $displayName $password');
    return _tokens;
  }

  @override
  Future<void> resetPasswordWithPhone({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    calls.add('reset $phone $code $newPassword');
  }

  @override
  Future<PhoneStatus> phoneStatus(String phone) async =>
      const PhoneStatus(registered: true, hasPassword: true);

  @override
  Future<void> requestPhoneOtp(String phone) async => calls.add('otp $phone');

  @override
  Future<UserSummary> linkApple(String identityToken) async {
    calls.add('link-apple $identityToken');
    return _renamed;
  }

  @override
  Future<UserSummary> linkFacebook(String accessToken) async {
    calls.add('link-facebook $accessToken');
    return _renamed;
  }

  @override
  Future<UserSummary> updateProfile({
    String? displayName,
    String? email,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? gender,
    bool? marketingConsent,
  }) async {
    calls.add(
      'profile $displayName $email $clearBirthDate $gender $marketingConsent',
    );
    return _renamed;
  }

  @override
  Future<UserSummary> updateAvatar(String? avatarUrl) async {
    calls.add('avatar $avatarUrl');
    return _renamed;
  }

  @override
  Future<void> deleteAccount({
    String? password,
    required String confirmation,
  }) async {
    if (deleteError != null) throw deleteError!;
    calls.add('delete $password $confirmation');
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

class _NoSignIn implements GoogleSignInService, FacebookSignInService {
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

List<Override> _overrides(
  _FakeAuthApi api,
  _InMemorySecureStorageService storage,
) => [
  authApiProvider.overrideWithValue(api),
  secureStorageServiceProvider.overrideWithValue(storage),
  googleSignInServiceProvider.overrideWithValue(_NoSignIn()),
  facebookSignInServiceProvider.overrideWithValue(_NoSignIn()),
  biometricAuthServiceProvider.overrideWithValue(_NoBiometrics()),
];

Future<(ProviderContainer, _FakeAuthApi, _InMemorySecureStorageService)>
_start({bool storedRefresh = false, bool refreshWorks = true}) async {
  final api = _FakeAuthApi()..refreshWorks = refreshWorks;
  final storage = _InMemorySecureStorageService();
  if (storedRefresh) {
    await storage.write('auth_access_token', 'stale-access');
    await storage.write('auth_refresh_token', 'old-refresh');
  }
  final container = ProviderContainer(overrides: _overrides(api, storage));
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);
  return (container, api, storage);
}

void main() {
  group('restoring a session', () {
    test('an expired access token is silently refreshed and the new tokens are stored', () async {
      final (container, api, storage) = await _start(storedRefresh: true);

      expect(
        container.read(authControllerProvider).value?.email,
        'a@example.com',
      );
      expect(api.calls, ['refresh old-refresh']);
      expect(await storage.read('auth_access_token'), 'access-2');
      expect(container.read(authTokenHolderProvider).accessToken, 'access-2');
    });

    test('a refresh token that no longer works signs the person out and clears storage', () async {
      final (container, _, storage) = await _start(
        storedRefresh: true,
        refreshWorks: false,
      );

      expect(container.read(authControllerProvider).value, isNull);
      expect(await storage.read('auth_refresh_token'), isNull);
      expect(container.read(authTokenHolderProvider).accessToken, isNull);
    });
  });

  group('signing in', () {
    test('Apple sign-in sends the identity token and the name', () async {
      final (container, api, storage) = await _start();

      await container
          .read(authControllerProvider.notifier)
          .loginWithApple('a-token', displayName: 'Dana');

      expect(api.calls, ['apple a-token Dana']);
      expect(container.read(authControllerProvider).value?.id, 'u1');
      expect(await storage.read('auth_access_token'), 'access-1');
    });

    test('connecting a provider to a password account signs in with the returned session', () async {
      final (container, api, _) = await _start();

      await container
          .read(authControllerProvider.notifier)
          .linkProviderWithPassword(
            provider: 'GOOGLE',
            token: 'g',
            password: 'secret',
          );

      expect(api.calls, ['link GOOGLE g secret']);
      expect(container.read(authControllerProvider).value?.id, 'u1');
    });

    test(
      'phone: status, code, register, password login and reset go to the API',
      () async {
        final (container, api, _) = await _start();
        final controller = container.read(authControllerProvider.notifier);

        final status = await controller.phoneStatus('+7700');
        await controller.requestPhoneOtp('+7700');
        await controller.registerWithPhone(
          phone: '+7700',
          code: '123456',
          displayName: 'Dana',
          password: 'longpassword',
        );
        await controller.loginWithPhonePassword(
          phone: '+7700',
          password: 'longpassword',
        );
        await controller.resetPasswordWithPhone(
          phone: '+7700',
          code: '123456',
          newPassword: 'newlongpassword',
        );

        expect(status.hasPassword, isTrue);
        expect(api.calls, [
          'otp +7700',
          'register +7700 123456 Dana longpassword',
          'phone-login +7700 longpassword',
          'reset +7700 123456 newlongpassword',
        ]);
        expect(container.read(authControllerProvider).value?.id, 'u1');
      },
    );
  });

  group('the account', () {
    test('linking Apple and Facebook refreshes the cached person', () async {
      final (container, api, _) = await _start();
      final controller = container.read(authControllerProvider.notifier);

      await controller.linkApple('a-token');
      expect(
        container.read(authControllerProvider).value?.displayName,
        'Dana K.',
      );
      await controller.linkFacebook('f-token');

      expect(api.calls, ['link-apple a-token', 'link-facebook f-token']);
    });

    test(
      'editing the profile and the avatar updates the cached person',
      () async {
        final (container, api, _) = await _start();
        final controller = container.read(authControllerProvider.notifier);

        await controller.updateProfile(
          displayName: 'Dana K.',
          gender: 'FEMALE',
          marketingConsent: true,
        );
        expect(
          container.read(authControllerProvider).value?.displayName,
          'Dana K.',
        );
        await controller.updateAvatar('https://img/x.png');
        await controller.updateAvatar(null);

        expect(api.calls, [
          'profile Dana K. null false FEMALE true',
          'avatar https://img/x.png',
          'avatar null',
        ]);
      },
    );

    test(
      'deleting the account signs out locally; a refusal changes nothing',
      () async {
        final (container, api, storage) = await _start();
        await container
            .read(authControllerProvider.notifier)
            .loginWithPhonePassword(phone: '+7700', password: 'p');
        expect(await storage.read('auth_access_token'), 'access-1');

        api.deleteError = Exception('refused');
        await expectLater(
          container
              .read(authControllerProvider.notifier)
              .deleteAccount(password: 'p', confirmation: 'DELETE'),
          throwsException,
        );
        expect(container.read(authControllerProvider).value, isNotNull);
        expect(await storage.read('auth_access_token'), 'access-1');

        api.deleteError = null;
        await container
            .read(authControllerProvider.notifier)
            .deleteAccount(password: 'p', confirmation: 'DELETE');
        expect(container.read(authControllerProvider).value, isNull);
        expect(await storage.read('auth_access_token'), isNull);
      },
    );
  });
}
