import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/app/routes.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

void main() {
  testWidgets('an admin sees the levels, translations, a hint that businesses pick from here, and add buttons', (
    tester,
  ) async {
    await pumpConsole(tester, backend: defaultBackend(), location: ConsoleRoutes.catalog);
    expect(find.textContaining('Businesses pick their category and services from here'), findsOneWidget);
    expect(find.text('💅 Beauty'), findsOneWidget);
    // The other two languages are visible for review.
    expect(find.textContaining('RU: Beauty RU'), findsOneWidget);
    expect(find.textContaining('KK: Beauty KK'), findsOneWidget);
    expect(find.text('New category'), findsOneWidget);

    await tester.tap(find.text('Spheres'));
    await tester.pumpAndSettle();
    expect(find.text('Hair Salon'), findsOneWidget);

    await tester.tap(find.text('Services'));
    await tester.pumpAndSettle();
    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('Under: Barbering'), findsOneWidget);
  });

  testWidgets('new category: the code comes from the name, empty fields are flagged, then it is saved', (tester) async {
    final backend = defaultBackend();
    backend.on('POST', '/platform/categories', (o) => FakeReply(catalogJson('c2', 'Hot Yoga', code: 'hot_yoga')));
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.catalog);

    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name (English)'), 'Hot Yoga');
    await tester.enterText(find.widgetWithText(TextFormField, 'Name (Russian)'), 'Хот-йога');
    await tester.enterText(find.widgetWithText(TextFormField, 'Name (Kazakh)'), 'Хот-йога');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'hot_yoga'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    final body = backend.calls('POST', '/platform/categories').single.data as Map;
    expect(body['code'], 'hot_yoga');
    expect(body['nameKk'], 'Хот-йога');
    expect(body['sortOrder'], 20); // after the existing one at 10
    expect(find.text('Hot Yoga created'), findsOneWidget);
  });

  testWidgets('a taken code gets its own message', (tester) async {
    final backend = defaultBackend();
    backend.reply('POST', '/platform/categories', {'message': 'exists'}, status: 409);
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.catalog);
    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name (English)'), 'Beauty');
    await tester.enterText(find.widgetWithText(TextFormField, 'Name (Russian)'), 'Красота');
    await tester.enterText(find.widgetWithText(TextFormField, 'Name (Kazakh)'), 'Сұлулық');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('This code is already used — change it.'), findsOneWidget);
  });

  testWidgets('editing fixes a translation and keeps the code fixed', (tester) async {
    final backend = defaultBackend();
    backend.on(
      'PATCH',
      '/platform/categories/c1',
      (o) => FakeReply(catalogJson('c1', 'Beauty & Care', code: 'beauty', icon: '💅')),
    );
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.catalog);

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('The code can’t be changed — other data refers to it.'), findsOneWidget);
    final code = tester.widget<TextField>(
      find.descendant(of: find.widgetWithText(TextFormField, 'beauty'), matching: find.byType(TextField)),
    );
    expect(code.readOnly, isTrue);

    await tester.enterText(find.widgetWithText(TextFormField, 'Beauty'), 'Beauty & Care');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final body = backend.calls('PATCH', '/platform/categories/c1').single.data as Map;
    expect(body['nameEn'], 'Beauty & Care');
    expect(body.containsKey('code'), isFalse);
    expect(find.text('Beauty & Care saved'), findsOneWidget);
  });

  testWidgets('hiding asks first and sends the status; the search finds by any language', (tester) async {
    final backend = defaultBackend();
    backend.reply('PATCH', '/platform/categories/c1/status', {});
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.catalog);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Hide 💅 Beauty?'), findsOneWidget);
    expect(backend.calls('PATCH', '/platform/categories/c1/status'), isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Hide'));
    await tester.pumpAndSettle();
    expect((backend.calls('PATCH', '/platform/categories/c1/status').single.data as Map)['status'], 'INACTIVE');

    await tester.enterText(find.byType(TextField).first, 'beauty kk');
    await tester.pumpAndSettle();
    expect(find.text('💅 Beauty'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches your search or filter.'), findsOneWidget);
  });

  testWidgets('a moderator can read the catalog but not change it', (tester) async {
    await pumpConsole(
      tester,
      backend: defaultBackend(role: 'PLATFORM_MODERATOR'),
      location: ConsoleRoutes.catalog,
    );
    expect(find.text('💅 Beauty'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.text('New category'), findsNothing);
    expect(find.textContaining('can view it but not change it'), findsOneWidget);
  });

  testWidgets('lower levels explain what to do first when there is nothing to attach to', (tester) async {
    final backend = defaultBackend();
    backend.reply('GET', '/platform/categories', []);
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.catalog);
    expect(find.text('No categories yet. Add the first one.'), findsOneWidget);
    await tester.tap(find.text('Spheres'));
    await tester.pumpAndSettle();
    expect(find.text('Create a category first.'), findsOneWidget);
    expect(find.text('New sphere'), findsNothing);
  });
}
