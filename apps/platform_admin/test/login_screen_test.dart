import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/core/network/platform_http.dart';

import 'support/harness.dart';

Finder get _email => find.widgetWithText(TextFormField, 'Email');
Finder get _password => find.widgetWithText(TextFormField, 'Password');
Finder get _signIn => find.widgetWithText(FilledButton, 'Sign in');

Future<void> _signInWith(WidgetTester tester, String email, String password) async {
  await tester.enterText(_email, email);
  await tester.enterText(_password, password);
  await tester.tap(_signIn);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty form asks for both fields and sends nothing', (tester) async {
    final backend = defaultBackend();
    await pumpConsole(tester, backend: backend, signedIn: false);

    await tester.tap(_signIn);
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(backend.calls('POST', loginPath), isEmpty);
  });

  testWidgets('an email without @ is rejected before any request', (tester) async {
    final backend = defaultBackend();
    await pumpConsole(tester, backend: backend, signedIn: false);

    await _signInWith(tester, 'boss.zairo.kz', 'secret123');

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Enter your password'), findsNothing);
    expect(backend.calls('POST', loginPath), isEmpty);
  });

  testWidgets('the email is trimmed and the password is sent exactly as typed', (tester) async {
    final backend = defaultBackend();
    await pumpConsole(tester, backend: backend, signedIn: false);

    await _signInWith(tester, '  boss@zairo.kz  ', ' secret 123 ');

    final body = backend.calls('POST', loginPath).single.data as Map;
    expect(body['email'], 'boss@zairo.kz');
    expect(body['password'], ' secret 123 ');
  });

  testWidgets('too many attempts (429) is explained as a wait, not as a wrong password', (tester) async {
    final backend = defaultBackend()..reply('POST', loginPath, {'message': 'slow down'}, status: 429);
    await pumpConsole(tester, backend: backend, signedIn: false);

    await _signInWith(tester, 'boss@zairo.kz', 'secret123');

    expect(find.text('Too many attempts. Wait a moment and try again.'), findsOneWidget);
    expect(find.textContaining('Wrong email or password'), findsNothing);
  });

  testWidgets('a disabled account (403) gets the same message as a wrong password', (tester) async {
    final backend = defaultBackend()..reply('POST', loginPath, {'message': 'disabled'}, status: 403);
    await pumpConsole(tester, backend: backend, signedIn: false);

    await _signInWith(tester, 'boss@zairo.kz', 'secret123');

    expect(find.textContaining('Wrong email or password'), findsOneWidget);
  });

  testWidgets('a server error (500) says sign-in failed, not that the password is wrong', (tester) async {
    final backend = defaultBackend()..reply('POST', loginPath, {'message': 'boom'}, status: 500);
    await pumpConsole(tester, backend: backend, signedIn: false);

    await _signInWith(tester, 'boss@zairo.kz', 'secret123');

    expect(find.text("Couldn't sign in. Please try again."), findsOneWidget);
    expect(find.textContaining('Wrong email or password'), findsNothing);
  });

  testWidgets('no connection is reported as a network problem', (tester) async {
    final backend = defaultBackend()
      ..on('POST', loginPath, (options) {
        throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
      });
    await pumpConsole(tester, backend: backend, signedIn: false);

    await _signInWith(tester, 'boss@zairo.kz', 'secret123');

    expect(find.text('No connection to the server. Check your internet and try again.'), findsOneWidget);
  });

  testWidgets('after an error the form is usable again and the next try can succeed', (tester) async {
    final backend = defaultBackend()..reply('POST', loginPath, {'message': 'bad'}, status: 401);
    await pumpConsole(tester, backend: backend, signedIn: false);
    await _signInWith(tester, 'boss@zairo.kz', 'wrong');
    expect(find.textContaining('Wrong email or password'), findsOneWidget);

    backend.reply('POST', loginPath, {'accessToken': fakeJwt(), 'admin': adminJson()});
    await tester.enterText(_password, 'secret123');
    await tester.tap(_signIn);
    await tester.pumpAndSettle();

    expect(find.text('Hello, Aida'), findsOneWidget);
    expect(backend.calls('POST', loginPath), hasLength(2));
  });

  testWidgets('the last used email is prefilled; the password never is', (tester) async {
    final storage = MemoryStorage({'platform_last_email': 'boss@zairo.kz', 'locale_code': 'en'});
    await pumpConsole(tester, backend: defaultBackend(), signedIn: false, storage: storage);

    expect(tester.widget<TextField>(find.descendant(of: _email, matching: find.byType(TextField))).controller!.text,
        'boss@zairo.kz');
    expect(tester.widget<TextField>(find.descendant(of: _password, matching: find.byType(TextField))).controller!.text,
        isEmpty);
  });

  testWidgets('the password field hides what is typed', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), signedIn: false);

    final field = tester.widget<TextField>(find.descendant(of: _password, matching: find.byType(TextField)));
    expect(field.obscureText, isTrue);
  });

  testWidgets('switching the language on the login screen translates it and is remembered', (tester) async {
    final storage = MemoryStorage({'locale_code': 'en'});
    await pumpConsole(tester, backend: defaultBackend(), signedIn: false, storage: storage);
    expect(_signIn, findsOneWidget);

    await tester.tap(find.text('Рус'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Войти'), findsOneWidget);
    expect(_signIn, findsNothing);
    expect(storage.values['locale_code'], 'ru');
  });
}
