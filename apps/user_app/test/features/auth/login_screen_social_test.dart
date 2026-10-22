import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/apple_sign_in_service.dart';
import 'package:zairo/features/auth/data/auth_api.dart';
import 'package:zairo/features/auth/data/auth_exception.dart';
import 'package:zairo/features/auth/data/biometric_auth_service.dart';
import 'package:zairo/features/auth/data/google_sign_in_service.dart';
import 'package:zairo/features/auth/data/models/auth_tokens.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/auth/presentation/screens/login_screen.dart';
import 'package:zairo/features/auth/presentation/screens/phone_login_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

const _user = UserSummary(
  id: 'u1',
  email: 'a@example.com',
  displayName: 'Dana',
  role: 'CUSTOMER',
);
const _tokens = AuthTokens(
  accessToken: 'access',
  refreshToken: 'refresh',
  user: _user,
);

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(DioClient(Dio()));

  final List<String> calls = [];
  Object? googleError;

  @override
  Future<AuthTokens> loginWithGoogle(String idToken) async {
    calls.add('google $idToken');
    if (googleError != null) throw googleError!;
    return _tokens;
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

class _FakeApple implements AppleSignInService {
  _FakeApple({this.result});

  final AppleSignInResult? result;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<AppleSignInResult?> signIn() async => result;
}

class _FakeGoogle implements GoogleSignInService {
  _FakeGoogle(this.token);

  final String? token;

  @override
  Future<String?> signIn() async => token;

  @override
  Future<void> signOut() async {}
}

class _NoBiometrics implements BiometricAuthService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

/// The login screen sits on top of a "home" route so a finished sign-in can pop back to it.
Future<void> _open(
  WidgetTester tester,
  _FakeAuthApi api, {
  String? googleToken,
  AppleSignInResult? apple,
  List<Override> extraOverrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authApiProvider.overrideWithValue(api),
        secureStorageServiceProvider.overrideWithValue(
          _InMemorySecureStorageService(),
        ),
        appleSignInServiceProvider.overrideWithValue(_FakeApple(result: apple)),
        googleSignInServiceProvider.overrideWithValue(_FakeGoogle(googleToken)),
        biometricAuthServiceProvider.overrideWithValue(_NoBiometrics()),
        ...extraOverrides,
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with Google and Apple switched off their buttons are gone and email/phone remains', (tester) async {
    await _open(
      tester,
      _FakeAuthApi(),
      googleToken: 'g-token',
      apple: const AppleSignInResult(identityToken: 'a-token'),
      extraOverrides: [
        googleSignInEnabledProvider.overrideWithValue(false),
        appleSignInEnabledProvider.overrideWithValue(false),
      ],
    );

    expect(find.byTooltip('Continue with Google'), findsNothing);
    expect(find.byTooltip('Continue with Apple'), findsNothing);
    expect(find.byIcon(Icons.mail_outline), findsOneWidget);
  });

  testWidgets('a phone-only build shows just the phone form: no e-mail, no providers, no sign-up page', (tester) async {
    await _open(
      tester,
      _FakeAuthApi(),
      extraOverrides: [
        emailSignInEnabledProvider.overrideWithValue(false),
        googleSignInEnabledProvider.overrideWithValue(false),
        appleSignInEnabledProvider.overrideWithValue(false),
      ],
    );

    expect(find.byType(PhoneLoginForm), findsOneWidget);
    expect(find.byIcon(Icons.mail_outline), findsNothing);
    expect(find.text('or'), findsNothing);
    expect(find.text("Don't have an account? Register"), findsNothing);
    expect(find.text('Forgot password?'), findsNothing);
  });

  testWidgets('with e-mail off but Google on, the providers row stays and the e-mail button is gone', (tester) async {
    await _open(
      tester,
      _FakeAuthApi(),
      extraOverrides: [emailSignInEnabledProvider.overrideWithValue(false)],
    );

    expect(find.byTooltip('Continue with Google'), findsOneWidget);
    expect(find.byIcon(Icons.mail_outline), findsNothing);
    expect(find.text('or'), findsOneWidget);
  });

  testWidgets('Apple stays hidden when switched off even on a device that supports it', (tester) async {
    await _open(
      tester,
      _FakeAuthApi(),
      extraOverrides: [appleSignInEnabledProvider.overrideWithValue(false)],
    );

    expect(find.byTooltip('Continue with Apple'), findsNothing);
    expect(find.byTooltip('Continue with Google'), findsOneWidget);
  });

  testWidgets('Google sign-in sends the token and closes the sign-in screen', (
    tester,
  ) async {
    final api = _FakeAuthApi();
    await _open(tester, api, googleToken: 'g-token');

    await tester.tap(find.byTooltip('Continue with Google'));
    await tester.pumpAndSettle();

    expect(api.calls, ['google g-token']);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('cancelling the Google picker does nothing', (tester) async {
    final api = _FakeAuthApi();
    await _open(tester, api);

    await tester.tap(find.byTooltip('Continue with Google'));
    await tester.pumpAndSettle();

    expect(api.calls, isEmpty);
    expect(find.byTooltip('Continue with Google'), findsOneWidget);
  });

  testWidgets(
    'Apple sign-in sends the identity token and the name Apple gave',
    (tester) async {
      final api = _FakeAuthApi();
      await _open(
        tester,
        api,
        apple: const AppleSignInResult(
          identityToken: 'a-token',
          displayName: 'Dana K.',
        ),
      );

      await tester.tap(find.byTooltip('Continue with Apple'));
      await tester.pumpAndSettle();

      expect(api.calls, ['apple a-token Dana K.']);
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets('cancelling Apple sign-in does nothing', (tester) async {
    final api = _FakeAuthApi();
    await _open(tester, api);

    await tester.tap(find.byTooltip('Continue with Apple'));
    await tester.pumpAndSettle();

    expect(api.calls, isEmpty);
  });

  testWidgets(
    'an email that already has a password account asks for it, then connects',
    (tester) async {
      final api = _FakeAuthApi()
        ..googleError = const AuthException(AuthErrorKey.accountLinkRequired);
      await _open(tester, api, googleToken: 'g-token');

      await tester.tap(find.byTooltip('Continue with Google'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Connect your account'), findsOneWidget);

      // An empty password is not accepted.
      await tester.tap(find.text('Connect'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Connect your account'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'secret-pass');
      await tester.tap(find.text('Connect'));
      await tester.pump(const Duration(seconds: 1));

      expect(api.calls, ['google g-token', 'link GOOGLE g-token secret-pass']);
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets('cancelling the connect dialog leaves the person signed out', (
    tester,
  ) async {
    final api = _FakeAuthApi()
      ..googleError = const AuthException(AuthErrorKey.accountLinkRequired);
    await _open(tester, api, googleToken: 'g-token');

    await tester.tap(find.byTooltip('Continue with Google'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(seconds: 1));

    expect(api.calls, ['google g-token']);
    expect(find.text('Connect your account'), findsNothing);
  });
}
