import 'package:business_admin/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/pump_app.dart';

/// Opens the screen from a button so that leaving it (pop) can be observed.
Future<void> _open(WidgetTester tester, FakeHttp http) async {
  useTallScreen(tester);
  await tester.pumpWidget(appOn(
    http,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder get _email => find.widgetWithText(TextField, en.emailLabel);
Finder get _code => find.widgetWithText(TextField, en.resetCodeLabel);
Finder get _newPassword => find.widgetWithText(TextField, en.newPasswordLabel);
Finder get _sendCode => find.widgetWithText(FactoryButton, en.forgotPasswordSendCodeButton);
Finder get _reset => find.widgetWithText(FactoryButton, en.forgotPasswordResetButton);

FakeHttp _backend() {
  final http = FakeHttp();
  http.reply('POST', '/auth/forgot-password', <String, Object?>{});
  http.reply('POST', '/auth/reset-password', <String, Object?>{});
  return http;
}

Future<void> _toResetStep(WidgetTester tester) async {
  await tester.enterText(_email, 'owner@example.com');
  await tester.tap(_sendCode);
  await tester.pumpAndSettle();
}

void main() {
  group('step 1: ask for a code', () {
    testWidgets('starts with the email form', (tester) async {
      await _open(tester, _backend());

      expect(find.text(en.forgotPasswordTitle), findsOneWidget);
      expect(_email, findsOneWidget);
      expect(_code, findsNothing);
    });

    testWidgets('an email without @ is rejected before anything is sent', (tester) async {
      final http = _backend();
      await _open(tester, http);

      await tester.enterText(_email, 'not-an-email');
      await tester.tap(_sendCode);
      await tester.pumpAndSettle();

      expect(find.text(en.validationEmailInvalid), findsOneWidget);
      expect(http.calls('POST', '/auth/forgot-password'), isEmpty);
      expect(_code, findsNothing);
    });

    testWidgets('a valid email is sent trimmed and the form moves on to the code step', (tester) async {
      final http = _backend();
      await _open(tester, http);

      await tester.enterText(_email, '  owner@example.com  ');
      await tester.tap(_sendCode);
      await tester.pumpAndSettle();

      expect(http.bodyOf('POST', '/auth/forgot-password'), {'email': 'owner@example.com'});
      expect(_code, findsOneWidget);
      expect(_newPassword, findsOneWidget);
      expect(_email, findsNothing);
    });

    testWidgets('a failure shows the generic message and stays on the email step', (tester) async {
      final http = _backend();
      http.fail('POST', '/auth/forgot-password', 500);
      await _open(tester, http);

      await _toResetStep(tester);

      expect(find.text(en.errorAuthGeneric), findsOneWidget);
      expect(_email, findsOneWidget);
      expect(_code, findsNothing);
    });
  });

  group('step 2: set a new password', () {
    testWidgets('both the code and a password of 8+ characters are required', (tester) async {
      final http = _backend();
      await _open(tester, http);
      await _toResetStep(tester);

      await tester.tap(_reset);
      await tester.pumpAndSettle();
      expect(find.text(en.validationResetCodeRequired), findsOneWidget);
      expect(find.text(en.validationPasswordMinLength), findsOneWidget);

      await tester.enterText(_code, '123456');
      await tester.enterText(_newPassword, '1234567');
      await tester.tap(_reset);
      await tester.pumpAndSettle();
      expect(find.text(en.validationResetCodeRequired), findsNothing);
      expect(find.text(en.validationPasswordMinLength), findsOneWidget);

      expect(http.calls('POST', '/auth/reset-password'), isEmpty);
    });

    testWidgets('a valid code and password reset the password, confirm, and leave the screen', (tester) async {
      final http = _backend();
      await _open(tester, http);
      await _toResetStep(tester);

      await tester.enterText(_code, '  123456 ');
      await tester.enterText(_newPassword, 'newpass123');
      await tester.tap(_reset);
      await tester.pumpAndSettle();

      expect(http.bodyOf('POST', '/auth/reset-password'), {'token': '123456', 'newPassword': 'newpass123'});
      expect(find.text(en.forgotPasswordSuccessMessage), findsOneWidget);
      expect(find.byType(ForgotPasswordScreen), findsNothing); // popped back to where it was opened
    });

    testWidgets('a wrong or expired code shows its own message and stays on the form', (tester) async {
      final http = _backend();
      http.fail('POST', '/auth/reset-password', 401);
      await _open(tester, http);
      await _toResetStep(tester);

      await tester.enterText(_code, '000000');
      await tester.enterText(_newPassword, 'newpass123');
      await tester.tap(_reset);
      await tester.pumpAndSettle();

      expect(find.text(en.errorAuthInvalidResetToken), findsOneWidget);
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(find.text(en.forgotPasswordSuccessMessage), findsNothing);
    });

    testWidgets('any other failure shows the generic message', (tester) async {
      final http = _backend();
      http.fail('POST', '/auth/reset-password', 500);
      await _open(tester, http);
      await _toResetStep(tester);

      await tester.enterText(_code, '123456');
      await tester.enterText(_newPassword, 'newpass123');
      await tester.tap(_reset);
      await tester.pumpAndSettle();

      expect(find.text(en.errorAuthGeneric), findsOneWidget);
      expect(find.text(en.errorAuthInvalidResetToken), findsNothing);
    });
  });
}
