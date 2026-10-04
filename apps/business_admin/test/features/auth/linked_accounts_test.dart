import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/auth/data/auth_exception.dart';
import 'package:business_admin/features/auth/data/biometric_auth_service.dart';
import 'package:business_admin/features/auth/data/google_sign_in_service.dart';
import 'package:business_admin/features/auth/data/models/identity_summary.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/settings/presentation/screens/security_settings_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';

class _RecordingController extends AuthController {
  List<IdentitySummary> identities = const [IdentitySummary(provider: 'GOOGLE')];
  String? linkedGoogleToken;
  String? requestedPhone;
  String? linkedPhone;
  String? linkedCode;
  Object? linkGoogleError;

  @override
  Future<UserSummary?> build() async =>
      const UserSummary(id: 'u1', email: null, displayName: 'Owner', role: 'PROVIDER_OWNER');

  @override
  Future<List<IdentitySummary>> listIdentities() async => identities;

  @override
  Future<void> linkGoogle(String idToken) async {
    if (linkGoogleError != null) throw linkGoogleError!;
    linkedGoogleToken = idToken;
    identities = [...identities, const IdentitySummary(provider: 'GOOGLE')];
  }

  @override
  Future<void> requestPhoneOtp(String phone) async => requestedPhone = phone;

  @override
  Future<void> linkPhone({required String phone, required String code}) async {
    linkedPhone = phone;
    linkedCode = code;
    identities = [...identities, const IdentitySummary(provider: 'PHONE')];
  }
}

class _FakeGoogle implements GoogleSignInService {
  @override
  Future<String?> signIn() async => 'google-id-token';

  @override
  Future<void> signOut() async {}
}

class _NoBiometrics implements BiometricAuthService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

Widget _wrap(_RecordingController controller) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => controller),
        googleSignInServiceProvider.overrideWithValue(_FakeGoogle()),
        biometricAuthServiceProvider.overrideWithValue(_NoBiometrics()),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SecuritySettingsScreen(),
      ),
    );

Finder _rowFor(String title) => find.ancestor(of: find.text(title), matching: find.byType(ListTile));

void main() {
  testWidgets('lists the linked sign-in methods: a check for the linked one, a Link button for the others', (tester) async {
    await tester.pumpWidget(_wrap(_RecordingController()));
    await tester.pumpAndSettle();

    expect(find.text('Linked accounts'), findsOneWidget);
    expect(find.descendant(of: _rowFor('Continue with Google'), matching: find.byIcon(Icons.check_circle)), findsOneWidget);
    expect(find.descendant(of: _rowFor('Continue with phone'), matching: find.text('Link')), findsOneWidget);
  });

  testWidgets('linking Google calls the controller with the Google token, then refreshes the list', (tester) async {
    final controller = _RecordingController()..identities = const [];
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: _rowFor('Continue with Google'), matching: find.text('Link')));
    await tester.pumpAndSettle();

    expect(controller.linkedGoogleToken, 'google-id-token');
    expect(find.descendant(of: _rowFor('Continue with Google'), matching: find.byIcon(Icons.check_circle)), findsOneWidget);
  });

  testWidgets('a rejected link (already linked to someone else) shows the error', (tester) async {
    final controller = _RecordingController()
      ..identities = const []
      ..linkGoogleError = const AuthException(AuthErrorKey.identityAlreadyLinked);
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: _rowFor('Continue with Google'), matching: find.text('Link')));
    await tester.pumpAndSettle();

    expect(find.text('That account is already linked to a different ZAIRO user.'), findsOneWidget);
  });

  testWidgets('adding a phone: number, SMS code, then back on Security with the phone linked', (tester) async {
    final controller = _RecordingController();
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: _rowFor('Continue with phone'), matching: find.text('Link')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '+7 700 123 45 67');
    await tester.tap(find.text('Continue'));
    // Bounded pumps: the code screen runs a resend countdown timer that never "settles".
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // let the page transition finish
    expect(controller.requestedPhone, '+7 700 123 45 67');

    await tester.enterText(find.widgetWithText(FactoryTextField, '6-digit code'), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(controller.linkedPhone, '+7 700 123 45 67');
    expect(controller.linkedCode, '123456');
    expect(find.text('Linked accounts'), findsOneWidget); // back on the Security screen
    expect(find.descendant(of: _rowFor('Continue with phone'), matching: find.byIcon(Icons.check_circle)), findsOneWidget);
  });
}
