import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/app/routes.dart';

import 'support/harness.dart';

void main() {
  testWidgets('a pending row keeps Approve and Suspend on one line, as tall as the other rows', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), location: ConsoleRoutes.businesses);

    final approve = find.widgetWithText(FilledButton, 'Approve');
    final suspend = find.widgetWithText(TextButton, 'Suspend');
    // Glow Salon (pending) shows both; Zen Spa (active) only Suspend.
    expect(suspend, findsNWidgets(2));
    expect(tester.getCenter(approve).dy, closeTo(tester.getCenter(suspend.first).dy, 1));
    final glow = tester.getRect(find.ancestor(of: find.text('Glow Salon'), matching: find.byType(InkWell)).first);
    final zen = tester.getRect(find.ancestor(of: find.text('Zen Spa'), matching: find.byType(InkWell)).first);
    expect(glow.height, closeTo(zen.height, 1));
  });

  testWidgets('words not codes; pending first with a banner; approve in one tap', (tester) async {
    final backend = defaultBackend();
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.businesses);

    expect(find.text('PENDING'), findsNothing);
    expect(find.text('1 business is waiting for approval'), findsOneWidget);
    expect(find.text('Awaiting approval'), findsWidgets);
    expect(tester.getTopLeft(find.text('Glow Salon')).dy, lessThan(tester.getTopLeft(find.text('Zen Spa')).dy));

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(backend.calls('PATCH', '/platform/businesses/p1/status').single.data['status'], 'ACTIVE');
    expect(find.text('Glow Salon approved'), findsOneWidget);
    expect(find.textContaining('waiting for approval'), findsNothing);
  });

  testWidgets('suspending asks first and sends the reason', (tester) async {
    final backend = defaultBackend();
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.businesses);

    // Zen Spa is the active one: its Suspend button is the only one.
    await tester.tap(find.widgetWithText(TextButton, 'Suspend').first);
    await tester.pumpAndSettle();
    expect(find.text('Suspend Glow Salon?'), findsOneWidget);
    expect(backend.calls('PATCH', '/platform/businesses/p1/status'), isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(backend.calls('PATCH', '/platform/businesses/p1/status'), isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'Suspend').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Reason (optional)'), 'fake photos');
    await tester.tap(find.widgetWithText(FilledButton, 'Suspend'));
    await tester.pumpAndSettle();

    final body = backend.calls('PATCH', '/platform/businesses/p1/status').single.data as Map;
    expect(body['status'], 'SUSPENDED');
    expect(body['reason'], 'fake photos');
  });

  testWidgets('search and status filter narrow the list; the banner filters to pending', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), location: ConsoleRoutes.businesses);

    await tester.enterText(find.byType(TextField).first, 'zen');
    await tester.pumpAndSettle();
    expect(find.text('Zen Spa'), findsOneWidget);
    expect(find.text('Glow Salon'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'nope');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches your search or filter.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 business is waiting for approval'));
    await tester.pumpAndSettle();
    expect(find.text('Glow Salon'), findsOneWidget);
    expect(find.text('Zen Spa'), findsNothing);
  });

  testWidgets('a deep link opens pre-filtered', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), location: '${ConsoleRoutes.businesses}?status=ACTIVE');
    expect(find.text('Zen Spa'), findsOneWidget);
    expect(find.text('Glow Salon'), findsNothing);
  });

  testWidgets('details show what the business is owed', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), location: ConsoleRoutes.businesses);
    await tester.tap(find.text('Zen Spa'));
    await tester.pumpAndSettle();
    expect(find.text('Owner ID'), findsOneWidget);
    expect(find.text('Payouts'), findsOneWidget);
    expect(find.text('To pay'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
  });

  testWidgets('support sees businesses but no action buttons', (tester) async {
    await pumpConsole(
      tester,
      backend: defaultBackend(role: 'PLATFORM_SUPPORT'),
      location: ConsoleRoutes.businesses,
    );
    expect(find.text('Glow Salon'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Suspend'), findsNothing);
  });

  testWidgets('a failed load says so and offers to retry', (tester) async {
    final backend = defaultBackend();
    backend.reply('GET', '/platform/businesses', {'message': 'boom'}, status: 500);
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.businesses);
    expect(find.textContaining('server had a problem'), findsOneWidget);

    backend.reply('GET', '/platform/businesses', [businessJson('p1', 'Glow Salon', 'ACTIVE')]);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Glow Salon'), findsOneWidget);
  });
}
