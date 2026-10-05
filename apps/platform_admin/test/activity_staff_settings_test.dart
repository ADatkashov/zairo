import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/app/routes.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

void main() {
  testWidgets('activity speaks in words: what, which business, who, from → to', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), location: ConsoleRoutes.activity);
    expect(find.text('Business status changed'), findsOneWidget);
    expect(find.text('Zen Spa'), findsOneWidget); // the target's name, looked up
    expect(find.text('Awaiting approval → Active'), findsOneWidget);
    expect(find.text('by boss@zairo.kz'), findsWidgets);
    expect(find.text('PROVIDER_STATUS_CHANGED'), findsNothing);
  });

  testWidgets('activity filters by area and searches', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), location: ConsoleRoutes.activity);
    await tester.tap(find.widgetWithText(FactoryChip, 'Catalog'));
    await tester.pumpAndSettle();
    expect(find.text('Category created'), findsOneWidget);
    expect(find.text('Business status changed'), findsNothing);

    await tester.tap(find.widgetWithText(FactoryChip, 'All'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'business');
    await tester.pumpAndSettle();
    expect(find.text('Business status changed'), findsOneWidget);
    expect(find.text('Category created'), findsNothing);
  });

  testWidgets('staff: roles legend, named roles, you cannot turn yourself off, turning off asks first', (tester) async {
    final backend = defaultBackend();
    backend.reply('POST', '/platform/admins/a2/deactivate', adminJson(id: 'a2'));
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.staff);

    expect(find.text('What each role can do'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Turn off'), findsOneWidget); // only Mara's row

    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();
    expect(find.text('Turn off Mara Mod?'), findsOneWidget);
    expect(backend.calls('POST', '/platform/admins/a2/deactivate'), isEmpty);
    await tester.enterText(find.widgetWithText(TextFormField, 'Reason (optional)'), 'left the company');
    await tester.tap(find.widgetWithText(FilledButton, 'Turn off'));
    await tester.pumpAndSettle();
    expect((backend.calls('POST', '/platform/admins/a2/deactivate').single.data as Map)['reason'], 'left the company');
  });

  testWidgets('staff: adding validates, then creates', (tester) async {
    final backend = defaultBackend();
    backend.on(
      'POST',
      '/platform/admins',
      (_) => FakeReply(adminJson(id: 'a3', email: 'new@zairo.kz', name: 'Nur New')),
    );
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.staff);

    await tester.tap(find.text('Add staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('At least 8 characters'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Nur New');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'new@zairo.kz');
    await tester.enterText(find.widgetWithText(TextFormField, 'Temporary password'), 'longenough1');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    final body = backend.calls('POST', '/platform/admins').single.data as Map;
    expect(body['email'], 'new@zairo.kz');
    expect(body['role'], 'PLATFORM_SUPPORT'); // the least powerful role is the default
    expect(find.text('Nur New added'), findsOneWidget);
  });

  testWidgets('staff: a duplicate email is explained', (tester) async {
    final backend = defaultBackend();
    backend.reply('POST', '/platform/admins', {'message': 'dup'}, status: 409);
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.staff);
    await tester.tap(find.text('Add staff'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Nur New');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'boss@zairo.kz');
    await tester.enterText(find.widgetWithText(TextFormField, 'Temporary password'), 'longenough1');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('An account with this email already exists.'), findsOneWidget);
  });

  testWidgets('settings: language switches the whole console and is remembered', (tester) async {
    final backend = defaultBackend();
    final storage = await pumpConsole(
      tester,
      backend: backend,
      location: ConsoleRoutes.settings,
      size: const Size(1400, 1600),
    );
    await tester.tap(find.widgetWithText(FactoryChip, 'Русский'));
    await tester.pumpAndSettle();
    expect(find.text('Настройки'), findsWidgets);
    expect(find.text('Settings'), findsNothing);
    expect(storage.values['locale_code'], 'ru');
  });

  testWidgets('settings: the role checklist reflects what the role can do', (tester) async {
    await pumpConsole(
      tester,
      backend: defaultBackend(role: 'PLATFORM_MODERATOR'),
      location: ConsoleRoutes.settings,
      size: const Size(1400, 1600),
    );
    expect(find.text('What your role can do'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2)); // view + moderate
    expect(find.byIcon(Icons.remove_circle_outline_rounded), findsNWidgets(4));
    expect(find.textContaining('http://test/api/v1'), findsOneWidget);
  });

  testWidgets('dashboard: attention items link to where the work is; numbers are formatted', (tester) async {
    await pumpConsole(tester, backend: defaultBackend());
    expect(find.text('Needs your attention'), findsOneWidget);
    expect(find.text('1 business is waiting for approval'), findsOneWidget);
    expect(find.textContaining('1 refund failed'), findsOneWidget);
    expect(find.textContaining('1 payout is waiting to be paid'), findsOneWidget);
    expect(find.text('₸150,000'), findsOneWidget);

    await tester.tap(find.text('Review').first);
    await tester.pumpAndSettle();
    expect(find.text('Glow Salon'), findsOneWidget);
    expect(find.text('Zen Spa'), findsNothing); // opened pre-filtered to pending
  });

  testWidgets('dashboard: when nothing is waiting it says so', (tester) async {
    final backend = defaultBackend();
    backend.reply('GET', '/platform/dashboard', {
      'users': {'total': 3},
      'businesses': {'total': 1, 'active': 1, 'pendingModeration': 0, 'blocked': 0},
      'subscriptions': {},
      'bookings': {},
      'payments': {'refundFailed': 0},
      'revenue': {'mrr': 0, 'currency': null, 'platformCommission': 0, 'platformCommissionCurrency': null},
    });
    backend.reply('GET', '/platform/payouts', []);
    await pumpConsole(tester, backend: backend);
    expect(find.text('All clear — nothing is waiting for you.'), findsOneWidget);
  });
}
