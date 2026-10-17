import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/app/routes.dart';

import 'support/harness.dart';

void main() {
  Finder inBar(Finder f) => find.descendant(of: find.byType(AppBar), matching: f);

  testWidgets('on a wide window the area title is left-aligned and the actions do not touch the edge', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), location: ConsoleRoutes.dashboard);

    final bar = tester.getRect(find.byType(AppBar));
    final title = tester.getRect(inBar(find.text('Dashboard')));
    // Next to the sidebar, not in the middle of the pane.
    expect(title.left - bar.left, lessThan(48));
    final lastAction = tester.getRect(inBar(find.byType(IconButton)).last);
    expect(bar.right - lastAction.right, greaterThanOrEqualTo(8));
  });

  testWidgets('on a phone the title stays centred', (tester) async {
    await pumpConsole(
      tester,
      backend: defaultBackend(),
      size: const Size(390, 844),
      location: ConsoleRoutes.dashboard,
    );

    final bar = tester.getRect(find.byType(AppBar));
    final title = tester.getRect(inBar(find.text('Dashboard')));
    expect((title.center.dx - bar.center.dx).abs(), lessThan(60));
  });
}
