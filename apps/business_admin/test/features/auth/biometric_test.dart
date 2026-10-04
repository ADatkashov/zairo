import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Override isn't exported from the main flutter_riverpod barrel in Riverpod 3.x.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/auth/data/auth_api.dart';
import 'package:business_admin/features/auth/data/biometric_auth_service.dart';
import 'package:business_admin/features/auth/data/google_sign_in_service.dart';
import 'package:business_admin/features/auth/data/models/auth_tokens.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/auth/presentation/widgets/biometric_offer_host.dart';
import 'package:business_admin/features/settings/presentation/screens/security_settings_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';

const _user = UserSummary(id: 'u1', email: null, displayName: 'Owner', role: 'PROVIDER_OWNER');
const _tokens = AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1', user: _user);

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(DioClient(Dio()));

  bool? lastBiometricAudit;

  @override
  Future<UserSummary> me(String accessToken) async => _user;

  @override
  Future<AuthTokens> loginWithPhonePassword({required String phone, required String password}) async => _tokens;

  @override
  Future<void> auditBiometricToggle(bool enabled) async => lastBiometricAudit = enabled;
}

class _FakeBiometric implements BiometricAuthService {
  bool available = true;
  bool authenticateResult = true;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    prompts++;
    return authenticateResult;
  }
}

class _FakeGoogle implements GoogleSignInService {
  @override
  Future<String?> signIn() async => null;

  @override
  Future<void> signOut() async {}
}

class _InMemoryStorage extends SecureStorageService {
  _InMemoryStorage() : super(const FlutterSecureStorage());

  final Map<String, String> store = {};

  @override
  Future<void> write(String key, String value) async => store[key] = value;

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> delete(String key) async => store.remove(key);

  @override
  Future<void> deleteAll() async => store.clear();
}

List<Override> _overrides(_FakeAuthApi api, _InMemoryStorage storage, _FakeBiometric biometric) => [
      authApiProvider.overrideWithValue(api),
      secureStorageServiceProvider.overrideWithValue(storage),
      biometricAuthServiceProvider.overrideWithValue(biometric),
      googleSignInServiceProvider.overrideWithValue(_FakeGoogle()),
    ];

void main() {
  group('biometric unlock (controller)', () {
    test('enabling requires a successful prompt first', () async {
      final storage = _InMemoryStorage();
      final biometric = _FakeBiometric()..authenticateResult = false;
      final container = ProviderContainer(overrides: _overrides(_FakeAuthApi(), storage, biometric));
      addTearDown(container.dispose);

      final enabled = await container.read(authControllerProvider.notifier).enableBiometric();

      expect(enabled, isFalse);
      expect(storage.store['auth_biometric_enabled'], isNull);
    });

    test('enabling persists the flag and audits the toggle', () async {
      final api = _FakeAuthApi();
      final storage = _InMemoryStorage();
      final container = ProviderContainer(overrides: _overrides(api, storage, _FakeBiometric()));
      addTearDown(container.dispose);

      final enabled = await container.read(authControllerProvider.notifier).enableBiometric();
      await Future<void>.delayed(Duration.zero);

      expect(enabled, isTrue);
      expect(storage.store['auth_biometric_enabled'], 'true');
      expect(api.lastBiometricAudit, isTrue);
    });

    test('disabling clears the flag', () async {
      final storage = _InMemoryStorage()..store['auth_biometric_enabled'] = 'true';
      final container = ProviderContainer(overrides: _overrides(_FakeAuthApi(), storage, _FakeBiometric()));
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).disableBiometric();

      expect(storage.store['auth_biometric_enabled'], isNull);
    });

    test('a successful cold-start prompt restores the stored session', () async {
      final storage = _InMemoryStorage()
        ..store['auth_access_token'] = 'stored'
        ..store['auth_biometric_enabled'] = 'true';
      final container = ProviderContainer(overrides: _overrides(_FakeAuthApi(), storage, _FakeBiometric()));
      addTearDown(container.dispose);

      final user = await container.read(authControllerProvider.future);

      expect(user?.id, 'u1');
    });

    test('a declined cold-start prompt does not restore the session and keeps the stored tokens', () async {
      final storage = _InMemoryStorage()
        ..store['auth_access_token'] = 'stored'
        ..store['auth_biometric_enabled'] = 'true';
      final biometric = _FakeBiometric()..authenticateResult = false;
      final container = ProviderContainer(overrides: _overrides(_FakeAuthApi(), storage, biometric));
      addTearDown(container.dispose);

      final user = await container.read(authControllerProvider.future);

      expect(user, isNull);
      expect(storage.store['auth_access_token'], 'stored');
    });

    test('without the flag there is no prompt at start', () async {
      final storage = _InMemoryStorage()..store['auth_access_token'] = 'stored';
      final biometric = _FakeBiometric();
      final container = ProviderContainer(overrides: _overrides(_FakeAuthApi(), storage, biometric));
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);

      expect(biometric.prompts, 0);
    });

    test('logout turns biometric unlock back off', () async {
      final storage = _InMemoryStorage()..store['auth_biometric_enabled'] = 'true';
      final container = ProviderContainer(overrides: _overrides(_FakeAuthApi(), storage, _FakeBiometric()));
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).logout();

      expect(storage.store['auth_biometric_enabled'], isNull);
    });

    test('an interactive sign-in requests the enable-fingerprint offer; a silent restore does not', () async {
      final storage = _InMemoryStorage()..store['auth_access_token'] = 'stored';
      final container = ProviderContainer(overrides: _overrides(_FakeAuthApi(), storage, _FakeBiometric()));
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);
      expect(container.read(biometricOfferPendingProvider), isFalse);

      await container
          .read(authControllerProvider.notifier)
          .loginWithPhonePassword(phone: '+77001234567', password: 'password123');

      expect(container.read(biometricOfferPendingProvider), isTrue);
    });
  });

  group('biometric UI', () {
    Widget wrap(List<Override> overrides, Widget home) => ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            theme: factoryLightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home,
          ),
        );

    testWidgets('after an interactive sign-in the home offers fingerprint unlock, and accepting enables it', (tester) async {
      final storage = _InMemoryStorage();
      final api = _FakeAuthApi();
      final container = ProviderContainer(overrides: _overrides(api, storage, _FakeBiometric()));
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      await container
          .read(authControllerProvider.notifier)
          .loginWithPhonePassword(phone: '+77001234567', password: 'password123');

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BiometricOfferHost(child: Scaffold(body: Text('owner home'))),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Enable biometric login?'), findsOneWidget);
      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();

      expect(storage.store['auth_biometric_enabled'], 'true');
      expect(container.read(biometricOfferPendingProvider), isFalse);
    });

    testWidgets('no offer without a fresh sign-in', (tester) async {
      await tester.pumpWidget(wrap(
        _overrides(_FakeAuthApi(), _InMemoryStorage(), _FakeBiometric()),
        const BiometricOfferHost(child: Scaffold(body: Text('owner home'))),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Enable biometric login?'), findsNothing);
    });

    testWidgets('the Security screen toggles biometric unlock', (tester) async {
      final storage = _InMemoryStorage();
      await tester.pumpWidget(wrap(
        _overrides(_FakeAuthApi(), storage, _FakeBiometric()),
        const SecuritySettingsScreen(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(storage.store['auth_biometric_enabled'], 'true');

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(storage.store['auth_biometric_enabled'], isNull);
    });

    testWidgets('the Security screen says so when biometrics are not available', (tester) async {
      await tester.pumpWidget(wrap(
        _overrides(_FakeAuthApi(), _InMemoryStorage(), _FakeBiometric()..available = false),
        const SecuritySettingsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsNothing);
      expect(find.textContaining("isn't available on this device"), findsOneWidget);
    });
  });
}
