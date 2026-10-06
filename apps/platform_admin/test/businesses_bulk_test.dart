import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/app/routes.dart';

import 'support/harness.dart';

void main() {
  _tabTests();
  testWidgets('select all, then Approve touches only rows it would change', (tester) async {
    final backend = defaultBackend();
    await pumpConsole(
      tester,
      backend: backend,
      location: ConsoleRoutes.businesses,
      size: const Size(1400, 900),
    );

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    // Glow Salon is pending, Zen Spa already active: only Glow is sent.
    await tester.tap(find.text('Approve').first);
    await tester.pumpAndSettle();

    expect(backend.calls('PATCH', '/platform/businesses/p1/status').single.data['status'], 'ACTIVE');
    expect(backend.calls('PATCH', '/platform/businesses/p2/status'), isEmpty);
    expect(find.text('1 business updated'), findsOneWidget);
    expect(find.text('2 selected'), findsNothing);
  });

  testWidgets('a filter can be saved as a view and applied again', (tester) async {
    await pumpConsole(
      tester,
      backend: defaultBackend(),
      location: ConsoleRoutes.businesses,
      size: const Size(1400, 900),
    );

    await tester.enterText(find.byType(TextField).first, 'zen');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save view'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'View name'), 'Spas');
    await tester.tap(find.widgetWithText(FilledButton, 'Save view'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Spas'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    expect(find.text('Glow Salon'), findsOneWidget);

    await tester.tap(find.widgetWithText(InputChip, 'Spas'));
    await tester.pumpAndSettle();
    expect(find.text('Zen Spa'), findsOneWidget);
    expect(find.text('Glow Salon'), findsNothing);
  });
}

void _tabTests() {
  testWidgets('status tabs show counts and filter; Suspended is its own tab', (tester) async {
    await pumpConsole(
      tester,
      backend: defaultBackend(),
      location: ConsoleRoutes.businesses,
      size: const Size(1400, 900),
    );

    // Two businesses: one pending, one active, none suspended.
    expect(find.widgetWithText(InkWell, 'All'), findsOneWidget);
    // The tab row precedes the table, whose rows also contain an "Active" badge.
    await tester.tap(find.widgetWithText(InkWell, 'Active').first);
    await tester.pumpAndSettle();
    expect(find.text('Zen Spa'), findsOneWidget);
    expect(find.text('Glow Salon'), findsNothing);

    await tester.tap(find.widgetWithText(InkWell, 'Suspended'));
    await tester.pumpAndSettle();
    expect(find.text('Zen Spa'), findsNothing);
    expect(find.text('Glow Salon'), findsNothing);

    await tester.tap(find.widgetWithText(InkWell, 'All'));
    await tester.pumpAndSettle();
    expect(find.text('Glow Salon'), findsOneWidget);
    expect(find.text('Zen Spa'), findsOneWidget);
  });
}
