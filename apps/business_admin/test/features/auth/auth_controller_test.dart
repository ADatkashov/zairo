import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/auth/data/auth_api.dart';
import 'package:business_admin/features/auth/data/auth_exception.dart';
import 'package:business_admin/features/auth/data/models/auth_tokens.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(DioClient(Dio()));

  AuthTokens? loginResult;
  Object? loginError;
  bool meShouldSucceed = false;

  static const _user = UserSummary(
    id: 'u1',
    email: 'owner@example.com',
    displayName: 'Test Owner',
    role: 'PROVIDER_OWNER',
  );

  static const tokens = AuthTokens(
    accessToken: 'access-1',
    refreshToken: 'refresh-1',
    user: _user,
  );

  @override
  Future<UserSummary> me(String accessToken) async {
    if (meShouldSucceed) return _user;
    throw const AuthException('no session');
  }

  @override
  Future<AuthTokens> login({required String email, required String password}) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
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

void main() {
  test('starts logged out when there is no stored session', () async {
    final container = ProviderContainer(overrides: [
      authApiProvider.overrideWithValue(_FakeAuthApi()),
      secureStorageServiceProvider.overrideWithValue(_InMemorySecureStorageService()),
    ]);
    addTearDown(container.dispose);

    final user = await container.read(authControllerProvider.future);
    expect(user, isNull);
  });

  test('login stores tokens, updates state and the shared token holder', () async {
    final fakeApi = _FakeAuthApi()..loginResult = _FakeAuthApi.tokens;
    final storage = _InMemorySecureStorageService();
    final container = ProviderContainer(overrides: [
      authApiProvider.overrideWithValue(fakeApi),
      secureStorageServiceProvider.overrideWithValue(storage),
    ]);
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .login(email: 'owner@example.com', password: 'password123');

    final state = container.read(authControllerProvider);
    expect(state.value?.email, 'owner@example.com');
    expect(state.value?.role, 'PROVIDER_OWNER');
    expect(await storage.read('auth_access_token'), 'access-1');
    expect(container.read(authTokenHolderProvider).accessToken, 'access-1');
  });

  test('failed login surfaces an error and does not store tokens', () async {
    final fakeApi = _FakeAuthApi()..loginError = const AuthException('Invalid email or password.');
    final storage = _InMemorySecureStorageService();
    final container = ProviderContainer(overrides: [
      authApiProvider.overrideWithValue(fakeApi),
      secureStorageServiceProvider.overrideWithValue(storage),
    ]);
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .login(email: 'owner@example.com', password: 'wrong');

    final state = container.read(authControllerProvider);
    expect(state.hasError, isTrue);
    expect(await storage.read('auth_access_token'), isNull);
  });

  test('logout clears storage, the token holder, and the state', () async {
    final fakeApi = _FakeAuthApi()..loginResult = _FakeAuthApi.tokens;
    final storage = _InMemorySecureStorageService();
    final container = ProviderContainer(overrides: [
      authApiProvider.overrideWithValue(fakeApi),
      secureStorageServiceProvider.overrideWithValue(storage),
    ]);
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .login(email: 'owner@example.com', password: 'password123');
    await container.read(authControllerProvider.notifier).logout();

    expect(container.read(authControllerProvider).value, isNull);
    expect(await storage.read('auth_access_token'), isNull);
    expect(container.read(authTokenHolderProvider).accessToken, isNull);
  });
}
