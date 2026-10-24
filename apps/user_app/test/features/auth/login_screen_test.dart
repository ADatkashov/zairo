import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_storage/core_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:zairo/l10n/app_localizations.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(DioClient(Dio()));

  int loginCalls = 0;
  String? lastEmail;
  String? lastPassword;
  Object? loginError;

  static const _user = UserSummary(
    id: 'u1',
    email: 'a@example.com',
    displayName: 'Test User',
    role: 'CUSTOMER',
  );

  @override
  Future<AuthTokens> login({required String email, required String password}) async {
    loginCalls++;
    lastEmail = email;
    lastPassword = password;
    if (loginError != null) throw loginError!;
    return const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1', user: _user);
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

class _NoAppleSignIn implements AppleSignInService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<AppleSignInResult?> signIn() async => null;
}

class _FakeGoogleSignInService implements GoogleSignInService {
  @override
  Future<String?> signIn() async => null; // the user cancels the picker

  @override
  Future<void> signOut() async {}
}

class _NoBiometrics implements BiometricAuthService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

Widget _wrap(_FakeAuthApi api) {
  return ProviderScope(
    overrides: [
      authApiProvider.overrideWithValue(api),
      secureStorageServiceProvider.overrideWithValue(_InMemorySecureStorageService()),
      appleSignInServiceProvider.overrideWithValue(_NoAppleSignIn()),
      googleSignInServiceProvider.overrideWithValue(_FakeGoogleSignInService()),
      biometricAuthServiceProvider.overrideWithValue(_NoBiometrics()),
    ],
    child: MaterialApp(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LoginScreen(),
    ),
  );
}

Future<void> _openEmailForm(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Continue with email'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts on the phone form: no email or password fields', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAuthApi()));
    await tester.pumpAndSettle();

    // "Email" is only the caption under the envelope button, not a field label.
    expect(find.widgetWithText(TextField, 'Email'), findsNothing);
    expect(find.text('Password'), findsNothing);
    expect(find.byTooltip('Continue with email'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text("Don't have an account? Register"), findsOneWidget);
  });

  testWidgets('the email button swaps in the email form and offers password reset', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAuthApi()));
    await tester.pumpAndSettle();

    await _openEmailForm(tester);

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    // The captions under the method buttons make the page a little taller.
    await tester.scrollUntilVisible(find.text('Forgot password?'), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.byTooltip('Continue with phone'), findsOneWidget);
    // The toggle now says where it leads: "Phone".
    expect(find.text('Phone'), findsOneWidget);
  });

  testWidgets('the phone button brings the phone form back', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAuthApi()));
    await tester.pumpAndSettle();
    await _openEmailForm(tester);

    await tester.tap(find.byTooltip('Continue with phone'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Email'), findsNothing);
    expect(find.text('Forgot password?'), findsNothing);
  });

  testWidgets('submitting an empty email form validates and does not call the API', (tester) async {
    final api = _FakeAuthApi();
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();
    await _openEmailForm(tester);

    await tester.tap(find.widgetWithText(FactoryButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(api.loginCalls, 0);
  });

  testWidgets('an email without @ is rejected', (tester) async {
    final api = _FakeAuthApi();
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();
    await _openEmailForm(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(FactoryButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(api.loginCalls, 0);
  });

  testWidgets('a valid email and password are sent to the API, with the email trimmed', (tester) async {
    final api = _FakeAuthApi();
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();
    await _openEmailForm(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '  a@example.com  ');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(FactoryButton, 'Log in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(api.loginCalls, 1);
    expect(api.lastEmail, 'a@example.com');
    expect(api.lastPassword, 'secret123');
  });

  testWidgets('wrong credentials show the localized error and keep the form', (tester) async {
    final api = _FakeAuthApi()..loginError = const AuthException(AuthErrorKey.invalidCredentials);
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();
    await _openEmailForm(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'a@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.widgetWithText(FactoryButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('the password field hides what is typed', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAuthApi()));
    await tester.pumpAndSettle();
    await _openEmailForm(tester);

    final password = tester.widget<TextField>(find.descendant(
      of: find.byType(TextFormField).at(1),
      matching: find.byType(TextField),
    ));
    expect(password.obscureText, isTrue);
  });
}
