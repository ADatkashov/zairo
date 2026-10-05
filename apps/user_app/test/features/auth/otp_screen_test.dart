import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/auth_api.dart';
import 'package:zairo/features/auth/data/auth_exception.dart';
import 'package:zairo/features/auth/data/biometric_auth_service.dart';
import 'package:zairo/features/auth/data/models/auth_tokens.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/auth/presentation/screens/otp_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(DioClient(Dio()));

  Object? verifyError;
  Object? linkError;
  Map<String, String>? lastVerifyCall;
  Map<String, String>? lastLinkCall;

  static const _user = UserSummary(id: 'u1', email: null, displayName: '+77001234567', role: 'CUSTOMER');
  static const _tokens = AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1', user: _user);

  @override
  Future<AuthTokens> verifyPhoneOtp({required String phone, required String code}) async {
    if (verifyError != null) throw verifyError!;
    lastVerifyCall = {'phone': phone, 'code': code};
    return _tokens;
  }

  @override
  Future<UserSummary> linkPhone({required String phone, required String code}) async {
    if (linkError != null) throw linkError!;
    lastLinkCall = {'phone': phone, 'code': code};
    return _user;
  }

  @override
  Future<void> requestPhoneOtp(String phone) async {}
}

/// Biometrics unavailable — keeps the post-login "Enable Face ID?" dialog
/// out of the way for tests that aren't about it (see biometric_gate tests
/// in auth_controller_test.dart for that behavior itself).
class _UnavailableBiometricAuthService implements BiometricAuthService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

/// See phone_login_screen_test.dart's identical fake for why this is needed.
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

Widget _wrap(AuthApi fakeApi, {bool linking = false}) {
  return ProviderScope(
    overrides: [
      authApiProvider.overrideWithValue(fakeApi),
      biometricAuthServiceProvider.overrideWithValue(_UnavailableBiometricAuthService()),
      secureStorageServiceProvider.overrideWithValue(_InMemorySecureStorageService()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OtpScreen(phone: '+77001234567', linking: linking),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Bounded pumps instead of pumpAndSettle throughout this file: OtpScreen
/// starts a Timer.periodic resend countdown in initState, which never lets
/// pumpAndSettle's "no more scheduled frames" condition become true.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('starts with the resend button disabled and counting down', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAuthApi()));
    await tester.tap(find.text('open'));
    await _settle(tester);

    expect(find.text('Resend code in 60s'), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);
  });

  testWidgets('rejects a code that is not 6 digits', (tester) async {
    final fakeApi = _FakeAuthApi();
    await tester.pumpWidget(_wrap(fakeApi));
    await tester.tap(find.text('open'));
    await _settle(tester);

    await tester.enterText(find.byType(TextFormField).first, '123');
    await tester.tap(find.text('Verify'));
    await _settle(tester);

    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    expect(fakeApi.lastVerifyCall, isNull);
  });

  testWidgets('a correct code signs in and pops back to the caller', (tester) async {
    final fakeApi = _FakeAuthApi();
    await tester.pumpWidget(_wrap(fakeApi));
    await tester.tap(find.text('open'));
    await _settle(tester);

    await tester.enterText(find.byType(TextFormField).first, '482913');
    await tester.tap(find.text('Verify'));
    await _settle(tester);
    await _settle(tester);

    expect(fakeApi.lastVerifyCall, {'phone': '+77001234567', 'code': '482913'});
    // Popped back to the screen underneath.
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a wrong code shows a readable error and stays on screen', (tester) async {
    final fakeApi = _FakeAuthApi()..verifyError = const AuthException(AuthErrorKey.invalidOtp);
    await tester.pumpWidget(_wrap(fakeApi));
    await tester.tap(find.text('open'));
    await _settle(tester);

    await tester.enterText(find.byType(TextFormField).first, '000000');
    await tester.tap(find.text('Verify'));
    await _settle(tester);
    await _settle(tester);

    expect(find.text('That code is incorrect. Please try again.'), findsOneWidget);
    expect(find.text('open'), findsNothing);
  });

  testWidgets('in linking mode, a correct code links and pops with a confirmation', (tester) async {
    final fakeApi = _FakeAuthApi();
    await tester.pumpWidget(_wrap(fakeApi, linking: true));
    await tester.tap(find.text('open'));
    await _settle(tester);

    await tester.enterText(find.byType(TextFormField).first, '482913');
    await tester.tap(find.text('Verify'));
    await _settle(tester);
    await _settle(tester);

    expect(fakeApi.lastLinkCall, {'phone': '+77001234567', 'code': '482913'});
    expect(find.text('Linked to your account.'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('in linking mode, an already-linked identity shows a readable conflict error', (tester) async {
    final fakeApi = _FakeAuthApi()..linkError = const AuthException(AuthErrorKey.identityAlreadyLinked);
    await tester.pumpWidget(_wrap(fakeApi, linking: true));
    await tester.tap(find.text('open'));
    await _settle(tester);

    await tester.enterText(find.byType(TextFormField).first, '482913');
    await tester.tap(find.text('Verify'));
    await _settle(tester);
    await _settle(tester);

    expect(find.text('That account is already linked to a different ZAIRO user.'), findsOneWidget);
    expect(find.text('open'), findsNothing);
  });

  testWidgets('shows the step and lets the user go back to change the number', (tester) async {
    final fakeApi = _FakeAuthApi();
    await tester.pumpWidget(_wrap(fakeApi));
    await tester.tap(find.text('open'));
    await _settle(tester);

    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(find.text('+77001234567'), findsOneWidget);

    await tester.tap(find.text('Change number'));
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 500)); // let the pop transition finish

    expect(find.text('open'), findsOneWidget);
    expect(find.text('Step 2 of 2'), findsNothing);
  });
}
