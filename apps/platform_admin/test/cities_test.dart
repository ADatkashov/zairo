import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/app/routes.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

void main() {
  testWidgets('lists cities with their facts; a switched-off one is marked hidden', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), location: ConsoleRoutes.cities);
    expect(find.text('Almaty'), findsOneWidget);
    expect(find.text('Shymkent'), findsOneWidget);
    expect(find.text('KZ · Asia/Almaty · KZT'), findsNWidgets(2));
    expect(find.text('Hidden'), findsOneWidget);
  });

  testWidgets('add city: prefilled timezone and currency, code from the name', (tester) async {
    final backend = defaultBackend();
    backend.on('POST', '/platform/cities', (_) => FakeReply(cityJson('astana', 'Astana')));
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.cities);

    await tester.tap(find.text('Add city'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Astana');
    await tester.enterText(find.widgetWithText(TextFormField, 'Name (Kazakh)'), 'Астана');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'astana'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Asia/Almaty'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    final body = backend.calls('POST', '/platform/cities').single.data as Map;
    expect(body['code'], 'astana');
    expect(body['name_kk'], 'Астана');
    expect(body['country_code'], 'KZ');
    expect(body['currency'], 'KZT');
    expect(find.text('Astana added'), findsOneWidget);
  });

  testWidgets('hiding a city asks first and sends the WHOLE city (the backend overwrites every field)', (tester) async {
    final backend = defaultBackend();
    backend.on('PUT', '/platform/cities/almaty', (_) => FakeReply(cityJson('almaty', 'Almaty', active: false)));
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.cities);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('Hide Almaty from customers?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Hide'));
    await tester.pumpAndSettle();

    final body = backend.calls('PUT', '/platform/cities/almaty').single.data as Map;
    expect(body['active'], false);
    expect(body['name'], 'Almaty');
    expect(body['name_kk'], 'Almaty KK');
    expect(body['timezone'], 'Asia/Almaty');
    expect(body['latitude'], 43.2);
    expect(body['default_search_radius_km'], 50);
  });

  testWidgets('deleting is permanent: it warns, offers hiding instead, and only then deletes', (tester) async {
    final backend = defaultBackend();
    backend.reply('DELETE', '/platform/cities/almaty', {}, status: 204);
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.cities);

    await tester.tap(find.byTooltip('More actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Almaty?'), findsOneWidget);
    expect(find.textContaining('hide it instead'), findsOneWidget);
    expect(backend.calls('DELETE', '/platform/cities/almaty'), isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(backend.calls('DELETE', '/platform/cities/almaty'), hasLength(1));
  });

  testWidgets('a moderator sees cities but cannot change them', (tester) async {
    await pumpConsole(
      tester,
      backend: defaultBackend(role: 'PLATFORM_MODERATOR'),
      location: ConsoleRoutes.cities,
    );
    expect(find.text('Almaty'), findsOneWidget);
    expect(find.text('Add city'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });
}
