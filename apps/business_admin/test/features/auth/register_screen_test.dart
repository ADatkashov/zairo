import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/auth/presentation/screens/register_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';

class _RecordingAuthController extends AuthController {
  Map<String, String>? lastCall;

  @override
  Future<UserSummary?> build() async => null;

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String phone,
  }) async {
    lastCall = {'email': email, 'password': password, 'displayName': displayName, 'phone': phone};
  }
}

void main() {
  testWidgets('validates all four fields and blocks an empty submit', (tester) async {
    final controller = _RecordingAuthController();
    await tester.pumpWidget(ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => controller)],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RegisterScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create business account'));
    await tester.pump();

    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Enter your phone'), findsOneWidget);
    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(controller.lastCall, isNull);
  });

  testWidgets('submits all four fields once the form is valid', (tester) async {
    final controller = _RecordingAuthController();
    await tester.pumpWidget(ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => controller)],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RegisterScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(FactoryTextField, 'Your name'), 'Jamie Owner');
    await tester.enterText(find.widgetWithText(FactoryTextField, 'Email'), 'jamie@example.com');
    await tester.enterText(find.widgetWithText(FactoryTextField, 'Phone'), '+1 555 0100');
    await tester.enterText(find.widgetWithText(FactoryTextField, 'Password'), 'hunter2222');
    await tester.tap(find.text('Create business account'));
    await tester.pump();

    expect(controller.lastCall, {
      'email': 'jamie@example.com',
      'password': 'hunter2222',
      'displayName': 'Jamie Owner',
      'phone': '+1 555 0100',
    });
  });
}
