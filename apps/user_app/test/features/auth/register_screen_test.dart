import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/auth_exception.dart';
import 'package:zairo/features/auth/presentation/screens/register_screen.dart';

import '../../helpers/auth_test_harness.dart';

Finder get _submit => find.widgetWithText(FactoryButton, 'Create account');

Future<void> _fill(
  WidgetTester tester, {
  String name = 'Aigerim',
  String email = 'aigerim@example.com',
  String phone = '+7 700 123 45 67',
  String password = 'password123',
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), name);
  await tester.enterText(fields.at(1), email);
  await tester.enterText(fields.at(2), phone);
  await tester.enterText(fields.at(3), password);
}

void main() {
  testWidgets('shows the four fields and the submit button', (tester) async {
    await tester.pumpWidget(wrapAuthScreen(const RegisterScreen(), RecordingAuthApi()));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(_submit, findsOneWidget);
  });

  testWidgets('an empty form shows every validation message and calls nothing', (tester) async {
    final api = RecordingAuthApi();
    await tester.pumpWidget(wrapAuthScreen(const RegisterScreen(), api));
    await tester.pumpAndSettle();

    await tester.ensureVisible(_submit);
    await tester.tap(_submit);
    await tester.pumpAndSettle();

    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Enter your phone'), findsOneWidget);
    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(api.registerCalls, isEmpty);
  });

  testWidgets('a password shorter than 8 characters is rejected', (tester) async {
    final api = RecordingAuthApi();
    await tester.pumpWidget(wrapAuthScreen(const RegisterScreen(), api));
    await tester.pumpAndSettle();

    await _fill(tester, password: '1234567');
    await tester.ensureVisible(_submit);
    await tester.tap(_submit);
    await tester.pumpAndSettle();

    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(find.text('Enter your name'), findsNothing);
    expect(api.registerCalls, isEmpty);
  });

  testWidgets('a password of exactly 8 characters is accepted', (tester) async {
    final api = RecordingAuthApi();
    await tester.pumpWidget(wrapAuthScreen(const RegisterScreen(), api));
    await tester.pumpAndSettle();

    await _fill(tester, password: '12345678');
    await tester.ensureVisible(_submit);
    await tester.tap(_submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.registerCalls, hasLength(1));
  });

  testWidgets('a valid form registers with trimmed name, email and phone', (tester) async {
    final api = RecordingAuthApi();
    await tester.pumpWidget(wrapAuthScreen(const RegisterScreen(), api));
    await tester.pumpAndSettle();

    await _fill(
      tester,
      name: '  Aigerim  ',
      email: ' aigerim@example.com ',
      phone: ' +7 700 123 45 67 ',
    );
    await tester.ensureVisible(_submit);
    await tester.tap(_submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.registerCalls.single, {
      'email': 'aigerim@example.com',
      'password': 'password123',
      'displayName': 'Aigerim',
      'phone': '+7 700 123 45 67',
    });
  });

  testWidgets('an already-registered email shows the localized error', (tester) async {
    final api = RecordingAuthApi()..error = const AuthException(AuthErrorKey.emailAlreadyRegistered);
    await tester.pumpWidget(wrapAuthScreen(const RegisterScreen(), api));
    await tester.pumpAndSettle();

    await _fill(tester);
    await tester.ensureVisible(_submit);
    await tester.tap(_submit);
    await tester.pumpAndSettle();

    expect(find.text('This email is already registered.'), findsOneWidget);
  });

  testWidgets('an unexpected error shows the generic message', (tester) async {
    final api = RecordingAuthApi()..error = StateError('boom');
    await tester.pumpWidget(wrapAuthScreen(const RegisterScreen(), api));
    await tester.pumpAndSettle();

    await _fill(tester);
    await tester.ensureVisible(_submit);
    await tester.tap(_submit);
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('This email is already registered.'), findsNothing);
    expect(api.registerCalls, hasLength(1));
  });
}
