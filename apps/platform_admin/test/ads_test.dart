import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/app/routes.dart';
import 'package:platform_admin/features/ads/data/ad_banner.dart';
import 'package:platform_admin/features/ads/presentation/ad_dialog.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

FakeBackend _backend({String role = 'PLATFORM_ADMIN', List<Map<String, Object?>>? banners}) {
  final backend = defaultBackend(role: role);
  backend.reply(
    'GET',
    '/platform/ads',
    banners ??
        [
          adJson('a1', 'AI & Digital Bridge', subtitle: 'Watch the highlights', videoUrl: 'https://v.example/1'),
          adJson('a2', 'Draft promo', status: 'DRAFT', cityCode: 'almaty'),
          adJson('a3', 'Salon deal', status: 'REJECTED', providerId: 'p2', rejectionReason: 'Misleading claim'),
        ],
  );
  return backend;
}

Future<void> _openMenu(WidgetTester tester, String title) async {
  final tile = find.ancestor(of: find.text(title), matching: find.byType(FactorySelectableTile)).first;
  await tester.tap(find.descendant(of: tile, matching: find.byType(PopupMenuButton<String>)));
  await tester.pumpAndSettle();
}

void main() {
  group('AdBanner / isHttpsUrl', () {
    test('only https links are accepted', () {
      expect(isHttpsUrl('https://cdn.example/a.jpg'), isTrue);
      expect(isHttpsUrl('  https://cdn.example/a.jpg  '), isTrue);
      expect(isHttpsUrl('http://cdn.example/a.jpg'), isFalse);
      expect(isHttpsUrl('javascript:alert(1)'), isFalse);
      expect(isHttpsUrl('https://'), isFalse);
      expect(isHttpsUrl('not a url'), isFalse);
      expect(isHttpsUrl(''), isFalse);
      expect(isHttpsUrl(null), isFalse);
    });

    test('the console offers the moves the backend lifecycle allows', () {
      AdBanner of(String status) => AdBanner.fromJson(adJson('x', 'T', status: status));

      expect([for (final s in ['DRAFT', 'PENDING_REVIEW', 'ACTIVE', 'PAUSED', 'REJECTED']) of(s).canPublish], [
        true,
        true,
        false,
        true,
        false,
      ]);
      expect(of('ACTIVE').canPause, isTrue);
      expect(of('PAUSED').canPause, isFalse);
      expect([for (final s in ['DRAFT', 'PENDING_REVIEW', 'ACTIVE', 'PAUSED', 'REJECTED']) of(s).canReject], [
        false,
        true,
        true,
        true,
        false,
      ]);
      expect(of('ACTIVE').isActive, isTrue);
      expect(of('DRAFT').isActive, isFalse);
    });
  });

  testWidgets('lists banners with status, city, video and the rejection reason', (tester) async {
    await pumpConsole(tester, backend: _backend(), location: ConsoleRoutes.ads);

    expect(find.text('AI & Digital Bridge'), findsOneWidget);
    expect(find.text('Watch the highlights'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Rejected: Misleading claim'), findsOneWidget);
    expect(find.text('Business ad'), findsOneWidget);
    // City name resolved from the code; "Every city" for a banner without one.
    expect(find.textContaining('Almaty ·'), findsOneWidget);
    expect(find.textContaining('Every city ·'), findsNWidgets(2));
  });

  testWidgets('shows an empty state with a hint for someone who can add banners', (tester) async {
    await pumpConsole(tester, backend: _backend(banners: []), location: ConsoleRoutes.ads);

    expect(find.text('No banners yet'), findsOneWidget);
    expect(find.text("Create one to show it on the customers' Home screen."), findsOneWidget);
    expect(find.text('Add banner'), findsOneWidget);
  });

  testWidgets('support staff can read banners but not change them', (tester) async {
    await pumpConsole(tester, backend: _backend(role: 'PLATFORM_SUPPORT'), location: ConsoleRoutes.ads);

    expect(find.text('AI & Digital Bridge'), findsOneWidget);
    expect(find.text('Add banner'), findsNothing);
    expect(find.descendant(of: find.byType(FactorySelectableTile), matching: find.byType(PopupMenuButton<String>)), findsNothing);
  });

  testWidgets('a moderator can manage banners', (tester) async {
    await pumpConsole(tester, backend: _backend(role: 'PLATFORM_MODERATOR'), location: ConsoleRoutes.ads);

    expect(find.text('Add banner'), findsOneWidget);
  });

  testWidgets('add banner: sends the whole banner and publishes it when asked', (tester) async {
    final backend = _backend();
    backend.on('POST', '/platform/ads', (_) => FakeReply(adJson('a9', 'New promo')));
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.ads);

    await tester.tap(find.text('Add banner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'New promo');
    await tester.enterText(find.widgetWithText(TextFormField, 'Cover image link (https)'), 'https://cdn.example/n.jpg');
    await tester.enterText(find.widgetWithText(TextFormField, 'Video link (https, optional)'), 'https://v.example/n');
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    final body = backend.calls('POST', '/platform/ads').single.data as Map;
    expect(body['title'], 'New promo');
    expect(body['subtitle'], isNull);
    expect(body['imageUrl'], 'https://cdn.example/n.jpg');
    expect(body['videoUrl'], 'https://v.example/n');
    expect(body['cityCode'], isNull);
    expect(body['status'], 'ACTIVE');
    expect(body['sortOrder'], 0);
    final starts = DateTime.parse(body['startsAt'] as String);
    final ends = DateTime.parse(body['endsAt'] as String);
    expect(ends.isAfter(starts), isTrue);
    expect(find.text('“New promo” created'), findsOneWidget);
  });

  testWidgets('add banner starts as a draft unless "publish right away" is on', (tester) async {
    final backend = _backend();
    backend.on('POST', '/platform/ads', (_) => FakeReply(adJson('a9', 'Plain')));
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.ads);

    await tester.tap(find.text('Add banner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Plain');
    await tester.enterText(find.widgetWithText(TextFormField, 'Cover image link (https)'), 'https://cdn.example/p.jpg');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    final body = backend.calls('POST', '/platform/ads').single.data as Map;
    expect(body['status'], 'DRAFT');
    expect(body['videoUrl'], isNull);
  });

  testWidgets('add banner: a non-https link or a missing title is stopped before the request', (tester) async {
    final backend = _backend();
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.ads);

    await tester.tap(find.text('Add banner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Cover image link (https)'), 'http://cdn.example/n.jpg');
    await tester.enterText(find.widgetWithText(TextFormField, 'Video link (https, optional)'), 'ftp://v.example/n');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a link that starts with https://'), findsNWidgets(2));
    expect(find.text('Required'), findsOneWidget);
    expect(backend.calls('POST', '/platform/ads'), isEmpty);
  });

  testWidgets('a server error is shown in the form and the dialog stays open', (tester) async {
    final backend = _backend();
    backend.on('POST', '/platform/ads', (_) => const FakeReply({'message': 'Unknown city: nope'}, status: 400));
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.ads);

    await tester.tap(find.text('Add banner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'T');
    await tester.enterText(find.widgetWithText(TextFormField, 'Cover image link (https)'), 'https://cdn.example/n.jpg');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('New banner'), findsOneWidget);
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
  });

  testWidgets('edit: the form is prefilled and the whole banner is sent back', (tester) async {
    final backend = _backend();
    backend.on('PUT', '/platform/ads/a1', (_) => FakeReply(adJson('a1', 'Renamed')));
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.ads);

    await tester.tap(find.text('AI & Digital Bridge'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'AI & Digital Bridge'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'https://v.example/1'), findsOneWidget);
    expect(find.text('Publish right away'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'AI & Digital Bridge'), 'Renamed');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final body = backend.calls('PUT', '/platform/ads/a1').single.data as Map;
    expect(body['title'], 'Renamed');
    expect(body['subtitle'], 'Watch the highlights');
    expect(body['videoUrl'], 'https://v.example/1');
    expect(body['sortOrder'], 2);
    expect(body.containsKey('status'), isFalse);
    expect(find.text('“Renamed” saved'), findsOneWidget);
  });

  testWidgets('publish and pause move the banner through the status endpoint', (tester) async {
    final backend = _backend();
    backend.on('PATCH', '/platform/ads/a2/status', (_) => FakeReply(adJson('a2', 'Draft promo')));
    backend.on('PATCH', '/platform/ads/a1/status', (_) => FakeReply(adJson('a1', 'AI & Digital Bridge')));
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.ads);

    await _openMenu(tester, 'Draft promo');
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();
    expect((backend.calls('PATCH', '/platform/ads/a2/status').single.data as Map)['status'], 'ACTIVE');
    expect(find.text('“Draft promo” is live'), findsOneWidget);

    await _openMenu(tester, 'AI & Digital Bridge');
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect((backend.calls('PATCH', '/platform/ads/a1/status').single.data as Map)['status'], 'PAUSED');
    expect(find.text('“AI & Digital Bridge” paused'), findsOneWidget);
  });

  testWidgets('the menu only offers the moves that make sense for the status', (tester) async {
    await pumpConsole(tester, backend: _backend(), location: ConsoleRoutes.ads);

    await _openMenu(tester, 'Salon deal'); // REJECTED: only edit / delete
    expect(find.text('Publish'), findsNothing);
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Reject…'), findsNothing);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('rejecting needs a reason, which is sent with the status change', (tester) async {
    final backend = _backend();
    backend.on('PATCH', '/platform/ads/a1/status', (_) => FakeReply(adJson('a1', 'AI & Digital Bridge')));
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.ads);

    await _openMenu(tester, 'AI & Digital Bridge');
    await tester.tap(find.text('Reject…'));
    await tester.pumpAndSettle();
    expect(find.text('Reject “AI & Digital Bridge”?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
    expect(backend.calls('PATCH', '/platform/ads/a1/status'), isEmpty);

    await tester.enterText(find.widgetWithText(TextFormField, 'Reason'), '  Misleading claim ');
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();

    final body = backend.calls('PATCH', '/platform/ads/a1/status').single.data as Map;
    expect(body['status'], 'REJECTED');
    expect(body['reason'], 'Misleading claim');
    expect(find.text('“AI & Digital Bridge” rejected'), findsOneWidget);
  });

  testWidgets('cancelling the rejection changes nothing', (tester) async {
    final backend = _backend();
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.ads);

    await _openMenu(tester, 'AI & Digital Bridge');
    await tester.tap(find.text('Reject…'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(backend.calls('PATCH', '/platform/ads/a1/status'), isEmpty);
  });

  testWidgets('a refused status change shows an error and not the success message', (tester) async {
    final backend = _backend();
    backend.on('PATCH', '/platform/ads/a2/status', (_) => const FakeReply({'message': 'Not allowed'}, status: 409));
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.ads);

    await _openMenu(tester, 'Draft promo');
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    expect(find.text('That conflicts with something that already exists.'), findsOneWidget);
    expect(find.text('“Draft promo” is live'), findsNothing);
  });

  testWidgets('delete asks first, then removes the banner', (tester) async {
    final backend = _backend();
    backend.on('DELETE', '/platform/ads/a3', (_) => const FakeReply({}, status: 200));
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.ads);

    await _openMenu(tester, 'Salon deal');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Salon deal”?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(backend.calls('DELETE', '/platform/ads/a3'), isEmpty);

    await _openMenu(tester, 'Salon deal');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(backend.calls('DELETE', '/platform/ads/a3'), hasLength(1));
    expect(find.text('“Salon deal” deleted'), findsOneWidget);
  });

  testWidgets('a failing list shows the retry state', (tester) async {
    final backend = _backend();
    backend.reply('GET', '/platform/ads', {'message': 'boom'}, status: 500);
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.ads);

    expect(find.byType(FactoryErrorState), findsOneWidget);
    expect(find.text('AI & Digital Bridge'), findsNothing);
  });
}
