import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/app/routes.dart';

import 'support/harness.dart';

/// Every area, in every language, at the narrowest realistic phone and at a
/// small tablet, must lay out without an overflow — and a tap on a control
/// that sits off-screen counts as a failure, not a warning.
void main() {
  const areas = [
    ConsoleRoutes.dashboard,
    ConsoleRoutes.businesses,
    ConsoleRoutes.catalog,
    ConsoleRoutes.cities,
    '${ConsoleRoutes.finance}?tab=payouts',
    '${ConsoleRoutes.finance}?tab=refunds',
    ConsoleRoutes.activity,
    ConsoleRoutes.staff,
    ConsoleRoutes.settings,
    ConsoleRoutes.more,
  ];

  for (final locale in const ['en', 'ru', 'kk']) {
    for (final size in const [Size(360, 740), Size(768, 1024)]) {
      testWidgets('no overflow: $locale at ${size.width.toInt()}px', (tester) async {
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
        for (final area in areas) {
          await pumpConsole(tester, backend: defaultBackend(), locale: Locale(locale), size: size, location: area);
          final error = tester.takeException();
          expect(error, isNull, reason: '$area overflowed');
        }
      });
    }
  }

  testWidgets('login screen fits a phone in every language', (tester) async {
    for (final locale in const ['en', 'ru', 'kk']) {
      await pumpConsole(
        tester,
        backend: defaultBackend(),
        signedIn: false,
        locale: Locale(locale),
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull, reason: locale);
    }
  });

  testWidgets('dialogs fit a phone: new category, new city, add staff, mark paid', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), size: const Size(360, 740), location: ConsoleRoutes.catalog);
    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await pumpConsole(tester, backend: defaultBackend(), size: const Size(360, 740), location: ConsoleRoutes.cities);
    await tester.tap(find.text('Add city'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await pumpConsole(tester, backend: defaultBackend(), size: const Size(360, 740), location: ConsoleRoutes.staff);
    await tester.tap(find.text('Add staff'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await pumpConsole(tester, backend: defaultBackend(), size: const Size(360, 740), location: ConsoleRoutes.finance);
    await tester.tap(find.widgetWithText(FilledButton, 'Mark as paid'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
