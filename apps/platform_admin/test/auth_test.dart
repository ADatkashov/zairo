import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/app/routes.dart';
import 'package:platform_admin/core/network/platform_http.dart';
import 'package:platform_admin/features/auth/data/jwt_expiry.dart';

import 'support/harness.dart';

void main() {
  test('jwtExpiry reads the exp claim and tolerates garbage', () {
    final token = fakeJwt(validFor: const Duration(minutes: 10));
    final expiry = jwtExpiry(token)!;
    expect(expiry.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 9))), isTrue);
    expect(jwtExpiry('not-a-jwt'), isNull);
    expect(jwtExpiry('a.b.c'), isNull);
  });

  testWidgets('signed out: starts at the login screen, and a wrong password is explained', (tester) async {
    final backend = defaultBackend();
    backend.reply('POST', loginPath, {'message': 'bad credentials'}, status: 401);
    await pumpConsole(tester, backend: backend, signedIn: false);

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Dashboard'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'boss@zairo.kz');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Wrong email or password'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('signing in opens the dashboard and remembers the email', (tester) async {
    final backend = defaultBackend();
    final storage = await pumpConsole(tester, backend: backend, signedIn: false);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'boss@zairo.kz');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Aida'), findsOneWidget);
    expect(storage.values['platform_access_token'], isNotNull);
    expect(storage.values['platform_last_email'], 'boss@zairo.kz');
    // The password is never stored.
    expect(storage.values.values.any((v) => v == 'secret123'), isFalse);
  });

  testWidgets('a deep link survives the login: sign in lands on the page that was asked for', (tester) async {
    final backend = defaultBackend();
    await pumpConsole(tester, backend: backend, signedIn: false, location: '${ConsoleRoutes.finance}?tab=refunds');

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'boss@zairo.kz');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Finance'), findsWidgets);
    expect(find.text('Provider timeout'), findsOneWidget); // refunds tab content
  });

  testWidgets('a stored, still-valid token restores the session without asking for a password', (tester) async {
    final backend = defaultBackend();
    await pumpConsole(tester, backend: backend);
    expect(find.text('Hello, Aida'), findsOneWidget);
    expect(backend.calls('GET', '/platform/auth/me'), hasLength(1));
    expect(backend.calls('POST', loginPath), isEmpty);
  });

  testWidgets('a stored token the server rejects is dropped and the login screen shows', (tester) async {
    final backend = defaultBackend();
    backend.reply('GET', '/platform/auth/me', {'message': 'expired'}, status: 401);
    final storage = await pumpConsole(tester, backend: backend);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(storage.values.containsKey('platform_access_token'), isFalse);
  });

  testWidgets('an expired stored token is not even tried', (tester) async {
    final backend = defaultBackend();
    final storage = MemoryStorage({'platform_access_token': fakeJwt(validFor: const Duration(minutes: -5))});
    await pumpConsole(tester, backend: backend, storage: storage);
    expect(backend.calls('GET', '/platform/auth/me'), isEmpty);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('a 401 mid-session signs out, says why, and keeps the page for after the next sign-in', (tester) async {
    final backend = defaultBackend();
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.businesses);
    expect(find.text('Glow Salon'), findsOneWidget);

    // The token stops being accepted; the next refresh fails with 401.
    backend.reply('GET', '/platform/businesses', {'message': 'expired'}, status: 401);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(find.textContaining('session ended'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('sign out asks first, then returns to the login screen', (tester) async {
    final backend = defaultBackend();
    final storage = await pumpConsole(
      tester,
      backend: backend,
      location: ConsoleRoutes.settings,
      size: const Size(1400, 2000),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(storage.values.containsKey('platform_access_token'), isFalse);
  });
}
