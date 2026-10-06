import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/auth_api.dart';
import 'package:zairo/features/auth/data/auth_exception.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(DioClient(Dio()));

  String? lastForgotPasswordEmail;
  Map<String, String>? lastResetPasswordCall;
  Object? errorOnReset;

  @override
  Future<void> forgotPassword(String email) async {
    lastForgotPasswordEmail = email;
  }

  @override
  Future<void> resetPassword({required String token, required String newPassword}) async {
    if (errorOnReset != null) throw errorOnReset!;
    lastResetPasswordCall = {'token': token, 'newPassword': newPassword};
  }
}

Widget _wrap(AuthApi fakeApi) {
  return ProviderScope(
    overrides: [authApiProvider.overrideWithValue(fakeApi)],
    child: MaterialApp(
      // The real app always runs on the Factory theme; the brand block reads it.
      theme: factoryLightTheme(profile: FactoryAppProfile.consumer),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('requesting a code advances to the reset step', (tester) async {
    final fakeApi = _FakeAuthApi();
    await tester.pumpWidget(_wrap(fakeApi));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Send code'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastForgotPasswordEmail, 'test@example.com');
    expect(find.text('Reset code'), findsOneWidget);
    expect(find.text('New password'), findsOneWidget);
  });

  testWidgets('shows a validation error for an invalid email', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAuthApi()));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('submitting a code and new password resets the password and pops', (tester) async {
    final fakeApi = _FakeAuthApi();
    await tester.pumpWidget(_wrap(fakeApi));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Reset code'), 'the-reset-code');
    await tester.enterText(find.widgetWithText(TextFormField, 'New password'), 'newpassword123');
    await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastResetPasswordCall, {'token': 'the-reset-code', 'newPassword': 'newpassword123'});
    expect(find.text('Password changed. Log in with your new password.'), findsOneWidget);
    // Popped back to the screen underneath.
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('shows a readable error when the reset code is invalid', (tester) async {
    final fakeApi = _FakeAuthApi()..errorOnReset = const AuthException(AuthErrorKey.invalidResetToken);
    await tester.pumpWidget(_wrap(fakeApi));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Reset code'), 'bad-code');
    await tester.enterText(find.widgetWithText(TextFormField, 'New password'), 'newpassword123');
    await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
    await tester.pumpAndSettle();

    expect(find.text('This code is invalid or has expired. Request a new one.'), findsOneWidget);
    // Still on the reset step, not popped.
    expect(find.text('open'), findsNothing);
  });
}
