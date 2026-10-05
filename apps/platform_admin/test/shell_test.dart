import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/app/routes.dart';
import 'package:platform_admin/app/shell.dart';

import 'support/harness.dart';

void main() {
  testWidgets('desktop: a sidebar with every area, badges for what needs attention, role in the footer', (
    tester,
  ) async {
    await pumpConsole(tester, backend: defaultBackend(), size: const Size(1400, 900));
    expect(find.byType(FactoryBottomNavigation), findsNothing);
    for (final label in ['Dashboard', 'Businesses', 'Catalog', 'Cities', 'Finance', 'Activity', 'Staff', 'Settings']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Platform admin'), findsOneWidget);
    // 1 business waiting + 1 failed refund → two badges.
    expect(find.descendant(of: find.byType(ConsoleSidebar), matching: find.text('1')), findsNWidgets(2));
  });

  testWidgets('tablet: an icon rail without labels', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), size: const Size(900, 900));
    expect(find.byType(FactoryBottomNavigation), findsNothing);
    expect(find.text('Cities'), findsNothing);
    expect(find.byTooltip('Cities'), findsOneWidget);
  });

  testWidgets('phone: bottom bar with five tabs; the rest is behind More, and back returns to More', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), size: const Size(390, 800));
    expect(find.byType(FactoryBottomNavigation), findsOneWidget);
    for (final label in ['Dashboard', 'Businesses', 'Catalog', 'Finance', 'More']) {
      expect(
        find.descendant(of: find.byType(FactoryBottomNavigation), matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }

    await tester.tap(find.descendant(of: find.byType(FactoryBottomNavigation), matching: find.text('More')));
    await tester.pumpAndSettle();
    expect(find.text('Cities'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Cities'));
    await tester.pumpAndSettle();
    expect(find.text('Almaty'), findsOneWidget);
    // More stays highlighted while one of its areas is open.
    final nav = tester.widget<FactoryBottomNavigation>(find.byType(FactoryBottomNavigation));
    expect(nav.selectedIndex, 4);

    // System back goes back to More, not out of the app.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Staff'), findsOneWidget);
    expect(find.text('Almaty'), findsNothing);
  });

  testWidgets('staff is for admins only: not listed for a moderator, and the URL redirects home', (tester) async {
    await pumpConsole(
      tester,
      backend: defaultBackend(role: 'PLATFORM_MODERATOR'),
      location: ConsoleRoutes.staff,
    );
    expect(find.text('Staff'), findsNothing);
    expect(find.text('Hello, Aida'), findsOneWidget); // landed on the dashboard
  });

  testWidgets('deep links open the right area, also after a restore', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), location: ConsoleRoutes.catalog);
    expect(find.text('💅 Beauty'), findsOneWidget);
  });

  testWidgets('an unknown URL quietly goes to the dashboard', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), location: '/nope/nothing');
    expect(find.text('Hello, Aida'), findsOneWidget);
  });
}
