import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/auth_exception.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/settings/presentation/screens/delete_account_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController({this.failWith});

  final Object? failWith;
  String? lastPassword;
  String? lastConfirmation;
  int calls = 0;

  @override
  Future<UserSummary?> build() async =>
      const UserSummary(id: 'u1', email: 'a@example.com', displayName: 'Aigerim', role: 'CUSTOMER');

  @override
  Future<void> deleteAccount({String? password, required String confirmation}) async {
    calls++;
    lastPassword = password;
    lastConfirmation = confirmation;
    if (failWith != null) throw failWith!;
  }
}

Widget _wrap(_FakeAuthController controller) => ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => controller)],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DeleteAccountScreen(),
      ),
    );

void main() {
  testWidgets('the delete button stays disabled until DELETE is typed, then sends it with the password',
      (tester) async {
    final controller = _FakeAuthController();
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete my account'));
    await tester.pump();
    expect(controller.calls, 0);

    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
    await tester.enterText(find.widgetWithText(TextFormField, 'Type DELETE to confirm'), 'delete');
    await tester.pump();
    await tester.tap(find.text('Delete my account'));
    await tester.pump();
    expect(controller.calls, 0, reason: 'the confirmation word is case-sensitive');

    await tester.enterText(find.widgetWithText(TextFormField, 'Type DELETE to confirm'), 'DELETE');
    await tester.pump();
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    expect(controller.calls, 1);
    expect(controller.lastPassword, 'secret123');
    expect(controller.lastConfirmation, 'DELETE');
  });

  testWidgets('a blocked deletion shows the server reason and stays on the screen', (tester) async {
    final controller = _FakeAuthController(
      failWith: const DeleteAccountException(statusCode: 409, serverMessage: 'You have upcoming bookings.'),
    );
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Type DELETE to confirm'), 'DELETE');
    await tester.pump();
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    expect(find.text('You have upcoming bookings.'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget); // still on the screen
    expect(controller.lastPassword, isNull); // empty password is sent as null
  });

  testWidgets('a wrong password shows a clear message', (tester) async {
    final controller = _FakeAuthController(failWith: const DeleteAccountException(statusCode: 403));
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Type DELETE to confirm'), 'DELETE');
    await tester.pump();
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect password.'), findsOneWidget);
  });
}
