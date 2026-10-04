import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/auth/data/auth_exception.dart';
import 'package:business_admin/features/auth/data/google_sign_in_service.dart';
import 'package:business_admin/features/auth/data/models/phone_status.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/auth/presentation/screens/login_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';

class _RecordingAuthController extends AuthController {
  String? lastEmail;
  String? lastPassword;
  String? linkedProvider;
  String? linkedPassword;
  String? requestedOtpPhone;
  PhoneStatus phone = const PhoneStatus(registered: false, hasPassword: false);
  Object? googleError;

  @override
  Future<UserSummary?> build() async => null;

  @override
  Future<void> login({required String email, required String password}) async {
    lastEmail = email;
    lastPassword = password;
  }

  @override
  Future<PhoneStatus> phoneStatus(String phone) async => this.phone;

  @override
  Future<void> requestPhoneOtp(String phone) async => requestedOtpPhone = phone;

  @override
  Future<void> loginWithGoogle(String idToken) async {
    if (googleError != null) throw googleError!;
  }

  @override
  Future<void> linkProviderWithPassword({
    required String provider,
    required String token,
    required String password,
  }) async {
    linkedProvider = provider;
    linkedPassword = password;
  }
}

class _FakeGoogleSignIn implements GoogleSignInService {
  @override
  Future<String?> signIn() async => 'google-id-token';

  @override
  Future<void> signOut() async {}
}

Widget _wrap(AuthController controller) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => controller),
        googleSignInServiceProvider.overrideWithValue(_FakeGoogleSignIn()),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoginScreen(),
      ),
    );

Future<void> _showEmailForm(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Continue with email'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone is the default sign-in method; email is behind the round email button', (tester) async {
    await tester.pumpWidget(_wrap(_RecordingAuthController()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FactoryTextField, 'Phone'), findsOneWidget);
    expect(find.widgetWithText(FactoryTextField, 'Email'), findsNothing);
    expect(find.byTooltip('Continue with Google'), findsOneWidget);

    await _showEmailForm(tester);

    expect(find.widgetWithText(FactoryTextField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(FactoryTextField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(FactoryTextField, 'Phone'), findsNothing);
  });

  testWidgets('validates the email form and blocks an empty submit', (tester) async {
    final controller = _RecordingAuthController();
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();
    await _showEmailForm(tester);

    await tester.tap(find.text('Log in'));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(controller.lastEmail, isNull);
  });

  testWidgets('submits the entered email and password once the form is valid', (tester) async {
    final controller = _RecordingAuthController();
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();
    await _showEmailForm(tester);

    await tester.enterText(find.widgetWithText(FactoryTextField, 'Email'), 'owner@example.com');
    await tester.enterText(find.widgetWithText(FactoryTextField, 'Password'), 'hunter2222');
    await tester.tap(find.text('Log in'));
    await tester.pump();

    expect(controller.lastEmail, 'owner@example.com');
    expect(controller.lastPassword, 'hunter2222');
  });

  testWidgets('a phone with a password goes to the password screen, with no SMS', (tester) async {
    final controller = _RecordingAuthController()..phone = const PhoneStatus(registered: true, hasPassword: true);
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '+7 700 123 45 67');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Enter password'), findsOneWidget);
    expect(controller.requestedOtpPhone, isNull);
  });

  testWidgets('a new phone requests an SMS code and opens registration', (tester) async {
    final controller = _RecordingAuthController();
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '+7 700 123 45 67');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(controller.requestedOtpPhone, '+7 700 123 45 67');
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('Google sign-in onto an email-registered account asks for that password, then connects', (tester) async {
    final controller = _RecordingAuthController()
      ..googleError = const AuthException(AuthErrorKey.accountLinkRequired);
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Continue with Google'));
    // Not pumpAndSettle: the Google button shows a spinner for as long as the
    // dialog waits for the password, which never "settles".
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Connect your account'), findsOneWidget);

    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField)), 'secret-pass-1');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(controller.linkedProvider, 'GOOGLE');
    expect(controller.linkedPassword, 'secret-pass-1');
  });

  testWidgets('a failed Google sign-in shows the error under the buttons', (tester) async {
    final controller = _RecordingAuthController()
      ..googleError = const AuthException(AuthErrorKey.invalidProviderCredential);
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't verify"), findsOneWidget);
  });
}
