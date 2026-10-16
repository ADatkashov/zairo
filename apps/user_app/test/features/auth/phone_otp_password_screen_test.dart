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
import 'package:zairo/features/auth/data/models/sms_mode.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/auth/presentation/screens/phone_otp_password_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

const _user = UserSummary(id: 'u1', email: 'a@example.com', displayName: 'Dana', role: 'CUSTOMER');
const _tokens = AuthTokens(accessToken: 'access', refreshToken: 'refresh', user: _user);

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(DioClient(Dio()));

  final List<String> calls = [];
  Object? registerError;
  Object? resetError;
  Object? resendError;
  Object? loginError;

  @override
  Future<SmsMode> smsMode() async => SmsMode.real;

  @override
  Future<void> requestPhoneOtp(String phone) async {
    if (resendError != null) throw resendError!;
    calls.add('otp $phone');
  }

  @override
  Future<AuthTokens> registerWithPhone({
    required String phone,
    required String code,
    required String displayName,
    required String password,
  }) async {
    if (registerError != null) throw registerError!;
    calls.add('register $phone $code $displayName $password');
    return _tokens;
  }

  @override
  Future<void> resetPasswordWithPhone({required String phone, required String code, required String newPassword}) async {
    if (resetError != null) throw resetError!;
    calls.add('reset $phone $code $newPassword');
  }

  @override
  Future<AuthTokens> loginWithPhonePassword({required String phone, required String password}) async {
    if (loginError != null) throw loginError!;
    calls.add('login $phone $password');
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

class _NoBiometrics implements BiometricAuthService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

/// The screen sits on top of a "home" route, as in the real chain, so signing in pops back to it.
Future<void> _open(WidgetTester tester, _FakeAuthApi api, {required bool isNewAccount}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authApiProvider.overrideWithValue(api),
        secureStorageServiceProvider.overrideWithValue(_InMemorySecureStorageService()),
        biometricAuthServiceProvider.overrideWithValue(_NoBiometrics()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PhoneOtpPasswordScreen(phone: '+77001234567', isNewAccount: isNewAccount),
                  ),
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

Future<void> _fill(WidgetTester tester, {String code = '123456', String? name, String password = 'longpassword'}) async {
  await tester.enterText(find.widgetWithText(TextField, '6-digit code'), code);
  if (name != null) await tester.enterText(find.widgetWithText(TextField, 'Name'), name);
  final passwordLabel = name != null ? 'Password' : 'New password';
  await tester.enterText(find.widgetWithText(TextField, passwordLabel), password);
}

void main() {
  testWidgets('a new account: code, name and password register and close the sign-in chain', (tester) async {
    final api = _FakeAuthApi();
    await _open(tester, api, isNewAccount: true);
    expect(find.text('Create account'), findsOneWidget);

    await _fill(tester, name: 'Dana', password: 'longpassword');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(api.calls, ['register +77001234567 123456 Dana longpassword']);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('a forgotten password: the new password is set and the person is signed in with it', (tester) async {
    final api = _FakeAuthApi();
    await _open(tester, api, isNewAccount: false);
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Name'), findsNothing);

    await _fill(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(api.calls, ['reset +77001234567 123456 longpassword', 'login +77001234567 longpassword']);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('an empty form shows what is missing and sends nothing', (tester) async {
    final api = _FakeAuthApi();
    await _open(tester, api, isNewAccount: true);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('a wrong code on registration shows the error and stays on the screen', (tester) async {
    final api = _FakeAuthApi()..registerError = const AuthException(AuthErrorKey.invalidOtp);
    await _open(tester, api, isNewAccount: true);

    await _fill(tester, name: 'Dana');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.byType(FilledButton), findsWidgets);
    expect(find.textContaining('code'), findsWidgets);
  });

  testWidgets('a wrong code when resetting shows the error and never tries to sign in', (tester) async {
    final api = _FakeAuthApi()..resetError = const AuthException(AuthErrorKey.invalidOtp);
    await _open(tester, api, isNewAccount: false);

    await _fill(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(api.calls, isEmpty);
    expect(find.text('Reset password'), findsOneWidget);
  });

  testWidgets('a failed sign-in right after the reset shows an error', (tester) async {
    final api = _FakeAuthApi()..loginError = const AuthException(AuthErrorKey.invalidCredentials);
    await _open(tester, api, isNewAccount: false);

    await _fill(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(api.calls, ['reset +77001234567 123456 longpassword']);
    expect(find.text('Reset password'), findsOneWidget);
  });

  testWidgets('an unexpected error shows the generic message', (tester) async {
    final api = _FakeAuthApi()..resetError = Exception('boom');
    await _open(tester, api, isNewAccount: false);

    await _fill(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('Resend code asks for a new code; a failure is shown', (tester) async {
    final api = _FakeAuthApi();
    await _open(tester, api, isNewAccount: true);

    await tester.tap(find.text('Resend code'));
    await tester.pumpAndSettle();
    expect(api.calls, ['otp +77001234567']);

    api.resendError = Exception('network');
    await tester.tap(find.text('Resend code'));
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('the form fits a 320 px phone with a large font in the dark theme', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _FakeAuthApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(api),
          secureStorageServiceProvider.overrideWithValue(_InMemorySecureStorageService()),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const PhoneOtpPasswordScreen(phone: '+77001234567', isNewAccount: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
