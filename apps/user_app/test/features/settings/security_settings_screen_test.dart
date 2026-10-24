import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/apple_sign_in_service.dart';
import 'package:zairo/features/auth/data/google_sign_in_service.dart';
import 'package:zairo/features/auth/data/models/identity_summary.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/auth/presentation/screens/phone_login_screen.dart';
import 'package:zairo/features/settings/presentation/screens/security_settings_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeAuth extends AuthController {
  _FakeAuth({
    this.biometricAvailable = true,
    this.identities = const [],
    this.identitiesFail = false,
    this.enableResult = true,
  });

  final bool biometricAvailable;
  bool biometricEnabled = false;
  final List<IdentitySummary> identities;
  final bool identitiesFail;
  final bool enableResult;
  final List<String> linked = [];
  Object? linkError;

  @override
  Future<UserSummary?> build() async =>
      const UserSummary(id: 'u1', email: 'a@example.com', displayName: 'A', role: 'CUSTOMER');

  @override
  Future<bool> isBiometricAvailable() async => biometricAvailable;

  @override
  Future<bool> isBiometricEnabled() async => biometricEnabled;

  @override
  Future<bool> enableBiometric() async {
    biometricEnabled = enableResult;
    return enableResult;
  }

  @override
  Future<void> disableBiometric() async => biometricEnabled = false;

  @override
  Future<List<IdentitySummary>> listIdentities() async {
    if (identitiesFail) throw Exception('offline');
    return identities;
  }

  @override
  Future<void> linkGoogle(String idToken) async {
    if (linkError != null) throw linkError!;
    linked.add('google:$idToken');
  }

  @override
  Future<void> linkApple(String identityToken) async {
    if (linkError != null) throw linkError!;
    linked.add('apple:$identityToken');
  }
}

class _Google implements GoogleSignInService {
  _Google(this.token);

  final String? token;

  @override
  Future<String?> signIn() async => token;

  @override
  Future<void> signOut() async {}
}

class _Apple implements AppleSignInService {
  _Apple({this.available = true, this.token = 'apple-token'});

  final bool available;
  final String? token;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<AppleSignInResult?> signIn() async => token == null ? null : AppleSignInResult(identityToken: token!);
}

Future<void> _pump(
  WidgetTester tester,
  _FakeAuth auth, {
  String? googleToken = 'google-token',
  bool appleAvailable = false,
  String? appleToken = 'apple-token',
  List<Override> extraOverrides = const [],
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authControllerProvider.overrideWith(() => auth),
        googleSignInServiceProvider.overrideWithValue(_Google(googleToken)),
        appleSignInServiceProvider.overrideWithValue(_Apple(available: appleAvailable, token: appleToken)),
        ...extraOverrides,
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SecuritySettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with Google and Apple switched off their rows are not offered for linking', (tester) async {
    await _pump(
      tester,
      _FakeAuth(),
      appleAvailable: true,
      extraOverrides: [
        googleSignInEnabledProvider.overrideWithValue(false),
        appleSignInEnabledProvider.overrideWithValue(false),
      ],
    );

    expect(find.text('Continue with Google'), findsNothing);
    expect(find.byIcon(Icons.apple), findsNothing);
  });

  testWidgets('without biometrics on the device it says so instead of a dead switch', (tester) async {
    await _pump(tester, _FakeAuth(biometricAvailable: false));

    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text(AppLocalizations.of(tester.element(find.byType(Scaffold)))!.securityBiometricUnavailable),
        findsOneWidget);
  });

  testWidgets('the biometric switch turns on and off, and stays off when the person cancels the prompt', (tester) async {
    final auth = _FakeAuth();
    await _pump(tester, auth);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
  });

  testWidgets('a cancelled biometric prompt leaves the switch off', (tester) async {
    await _pump(tester, _FakeAuth(enableResult: false));

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
  });

  testWidgets('already linked methods show a check, the others offer to link', (tester) async {
    await _pump(
      tester,
      _FakeAuth(identities: const [IdentitySummary(provider: 'GOOGLE'), IdentitySummary(provider: 'PHONE')]),
      appleAvailable: true,
    );

    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    // Only Apple is left to link.
    expect(find.byType(TextButton), findsOneWidget);
    // Rows are named by the provider, not by the login button's wording, and linked ones say so.
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Linked'), findsNWidgets(2));
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('the Apple row only exists where Apple sign-in does', (tester) async {
    await _pump(tester, _FakeAuth());

    expect(find.byIcon(Icons.apple), findsNothing);
  });

  testWidgets('linking Google sends its token and refreshes the list', (tester) async {
    final auth = _FakeAuth();
    await _pump(tester, auth);

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();

    expect(auth.linked, ['google:google-token']);
  });

  testWidgets('cancelling the Google sheet links nothing and shows no error', (tester) async {
    final auth = _FakeAuth();
    await _pump(tester, auth, googleToken: null);

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();

    expect(auth.linked, isEmpty);
    expect(find.text('Something went wrong'), findsNothing);
  });

  testWidgets('linking Apple sends its identity token', (tester) async {
    final auth = _FakeAuth();
    await _pump(tester, auth, appleAvailable: true);

    await tester.tap(find.widgetWithText(TextButton, 'Link').at(1));
    await tester.pumpAndSettle();

    expect(auth.linked, ['apple:apple-token']);
  });

  testWidgets('cancelling the Apple sheet links nothing', (tester) async {
    final auth = _FakeAuth();
    await _pump(tester, auth, appleAvailable: true, appleToken: null);

    await tester.tap(find.widgetWithText(TextButton, 'Link').at(1));
    await tester.pumpAndSettle();

    expect(auth.linked, isEmpty);
  });

  testWidgets('a failed link shows a general error', (tester) async {
    final auth = _FakeAuth()..linkError = Exception('boom');
    await _pump(tester, auth);

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('a failed Apple link shows the same error', (tester) async {
    final auth = _FakeAuth()..linkError = Exception('boom');
    await _pump(tester, auth, appleAvailable: true);

    await tester.tap(find.widgetWithText(TextButton, 'Link').at(1));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('if the linked methods cannot be read the screen still works', (tester) async {
    await _pump(tester, _FakeAuth(identitiesFail: true));

    expect(find.byType(FactoryLoadingState), findsNothing);
    expect(find.byType(TextButton), findsWidgets);
  });

  testWidgets('linking a phone opens the phone screen in linking mode and re-reads the methods on return', (tester) async {
    await _pump(tester, _FakeAuth());

    await tester.tap(find.widgetWithText(TextButton, 'Link').last);
    await tester.pumpAndSettle();
    expect(find.byType(PhoneLoginScreen), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(PhoneLoginScreen), findsNothing);
  });
}
