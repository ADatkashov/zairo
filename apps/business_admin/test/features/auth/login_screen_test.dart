import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/auth/presentation/screens/login_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';

class _RecordingAuthController extends AuthController {
  String? lastEmail;
  String? lastPassword;

  @override
  Future<UserSummary?> build() async => null;

  @override
  Future<void> login({required String email, required String password}) async {
    lastEmail = email;
    lastPassword = password;
  }
}

Widget _wrap(AuthController controller) => ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => controller)],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoginScreen(),
      ),
    );

void main() {
  testWidgets('validates the form and blocks an empty submit', (tester) async {
    final controller = _RecordingAuthController();
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

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

    await tester.enterText(find.widgetWithText(FactoryTextField, 'Email'), 'owner@example.com');
    await tester.enterText(find.widgetWithText(FactoryTextField, 'Password'), 'hunter2222');
    await tester.tap(find.text('Log in'));
    await tester.pump();

    expect(controller.lastEmail, 'owner@example.com');
    expect(controller.lastPassword, 'hunter2222');
  });
}
