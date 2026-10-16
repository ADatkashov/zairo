import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/app/routes.dart';
import 'package:platform_admin/features/reviews/data/review_report.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

Map<String, Object?> _row(String id, String status, {String business = 'Glow Salon', String? hiddenReason}) => {
  'id': id,
  'bookingId': 'b-$id',
  'providerId': 'p-$id',
  'providerName': business,
  'rating': 1,
  'comment': 'Awful experience',
  'createdAt': '2026-10-12T10:00:00Z',
  'businessReply': null,
  'reportReason': 'Abusive language',
  'reportedAt': '2026-10-13T10:00:00Z',
  'reportResolvedAt': status == 'OPEN' ? null : '2026-10-14T10:00:00Z',
  'status': status,
  'hiddenAt': status == 'HIDDEN' ? '2026-10-14T10:00:00Z' : null,
  'hiddenReason': hiddenReason,
};

FakeBackend _backend({
  String role = 'PLATFORM_ADMIN',
  Map<String, List<Map<String, Object?>>> queues = const {},
}) {
  final backend = defaultBackend(role: role);
  backend.on('GET', '/platform/reviews', (request) {
    final status = request.queryParameters['status'] as String;
    return FakeReply({'content': queues[status] ?? const []});
  });
  return backend;
}

void main() {
  test('ReviewReport reads the queue row and knows its state', () {
    final open = ReviewReport.fromJson(_row('r1', 'OPEN'));
    expect(open.isOpen, isTrue);
    expect(open.isHidden, isFalse);
    expect(open.reportReason, 'Abusive language');
    expect(open.reportedAt, isNotNull);
    expect(open.businessReply, isNull);

    final hidden = ReviewReport.fromJson(_row('r2', 'HIDDEN', hiddenReason: 'Contains abuse'));
    expect(hidden.isHidden, isTrue);
    expect(hidden.hiddenReason, 'Contains abuse');

    final kept = ReviewReport.fromJson({..._row('r3', 'DISMISSED'), 'reportedAt': null, 'comment': null});
    expect(kept.isDismissed, isTrue);
    expect(kept.reportedAt, isNull);
    expect(kept.comment, isNull);
  });

  testWidgets('lists the reports waiting for a decision with the business and why it was reported', (tester) async {
    await pumpConsole(
      tester,
      backend: _backend(queues: {'OPEN': [_row('r1', 'OPEN')]}),
      location: ConsoleRoutes.reviews,
    );

    expect(find.text('Glow Salon'), findsOneWidget);
    expect(find.text('Awful experience'), findsOneWidget);
    expect(find.text('Reported: Abusive language'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
    expect(find.text('Keep'), findsOneWidget);
  });

  testWidgets('says so when nothing is waiting, and in each other tab', (tester) async {
    await pumpConsole(tester, backend: _backend(), location: ConsoleRoutes.reviews);
    expect(find.text('No reported reviews waiting'), findsOneWidget);

    await tester.tap(find.text('Hidden'));
    await tester.pumpAndSettle();
    expect(find.text('No hidden reviews'), findsOneWidget);

    await tester.tap(find.text('Kept'));
    await tester.pumpAndSettle();
    expect(find.text('No kept reviews'), findsOneWidget);
  });

  testWidgets('hiding asks for an optional note and sends it, then the queue is reloaded', (tester) async {
    final backend = _backend(queues: {'OPEN': [_row('r1', 'OPEN')]});
    backend.reply('POST', '/platform/reviews/r1/hide', null, status: 204);
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.reviews);

    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();
    expect(find.text('Hide this review?'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Note (optional)'), 'Contains abuse');
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Hide')));
    await tester.pumpAndSettle();

    expect(backend.calls('POST', '/platform/reviews/r1/hide').single.data, {'reason': 'Contains abuse'});
    expect(find.text('Review hidden from every rating'), findsOneWidget);
    expect(backend.calls('GET', '/platform/reviews').length, greaterThan(1));
  });

  testWidgets('cancelling the hide dialog sends nothing', (tester) async {
    final backend = _backend(queues: {'OPEN': [_row('r1', 'OPEN')]});
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.reviews);

    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(backend.calls('POST', '/platform/reviews/r1/hide'), isEmpty);
  });

  testWidgets('keeping a review closes the report without asking anything', (tester) async {
    final backend = _backend(queues: {'OPEN': [_row('r1', 'OPEN')]});
    backend.reply('POST', '/platform/reviews/r1/dismiss', null, status: 204);
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.reviews);

    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();

    expect(backend.calls('POST', '/platform/reviews/r1/dismiss'), hasLength(1));
    expect(find.text('Review kept'), findsOneWidget);
  });

  testWidgets('a hidden review shows why and can be restored', (tester) async {
    final backend = _backend(queues: {'HIDDEN': [_row('r2', 'HIDDEN', hiddenReason: 'Contains abuse')]});
    backend.reply('POST', '/platform/reviews/r2/restore', null, status: 204);
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.reviews);

    await tester.tap(find.text('Hidden'));
    await tester.pumpAndSettle();
    expect(find.text('Hidden: Contains abuse'), findsOneWidget);
    expect(find.text('Keep'), findsNothing);

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(backend.calls('POST', '/platform/reviews/r2/restore'), hasLength(1));
    expect(find.text('Review restored'), findsOneWidget);
  });

  testWidgets('a kept review can still be hidden but not kept again', (tester) async {
    await pumpConsole(
      tester,
      backend: _backend(queues: {'DISMISSED': [_row('r3', 'DISMISSED')]}),
      location: ConsoleRoutes.reviews,
    );

    await tester.tap(find.text('Kept'));
    await tester.pumpAndSettle();

    expect(find.text('Hide'), findsOneWidget);
    expect(find.text('Keep'), findsNothing);
  });

  testWidgets('a refused decision is reported instead of failing silently', (tester) async {
    final backend = _backend(queues: {'OPEN': [_row('r1', 'OPEN')]});
    backend.reply('POST', '/platform/reviews/r1/dismiss', {'message': 'No open report on this review'}, status: 409);
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.reviews);

    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();

    expect(find.text('Review kept'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('support staff can read the queue but not decide', (tester) async {
    await pumpConsole(
      tester,
      backend: _backend(role: 'PLATFORM_SUPPORT', queues: {'OPEN': [_row('r1', 'OPEN')]}),
      location: ConsoleRoutes.reviews,
    );

    expect(find.text('Reported: Abusive language'), findsOneWidget);
    expect(find.byType(FactoryButton), findsNothing);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    final backend = defaultBackend()..reply('GET', '/platform/reviews', {'message': 'boom'}, status: 500);
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.reviews);

    expect(find.byType(FactoryErrorState), findsOneWidget);
  });

  testWidgets('the refresh button asks the backend again', (tester) async {
    final backend = _backend(queues: {'OPEN': [_row('r1', 'OPEN')]});
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.reviews);
    final before = backend.calls('GET', '/platform/reviews').length;

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();

    expect(backend.calls('GET', '/platform/reviews').length, before + 1);
  });

  testWidgets('pulling down reloads the queue', (tester) async {
    final backend = _backend(queues: {'OPEN': [_row('r1', 'OPEN')]});
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.reviews);
    final before = backend.calls('GET', '/platform/reviews').length;

    await tester.fling(find.text('Awful experience'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(backend.calls('GET', '/platform/reviews').length, before + 1);
  });

  testWidgets('the queue reads well on a narrow phone', (tester) async {
    await pumpConsole(
      tester,
      backend: _backend(queues: {'OPEN': [_row('r1', 'OPEN', business: 'A Very Long Business Name That Keeps Going')]}),
      location: ConsoleRoutes.reviews,
      size: const Size(320, 640),
    );

    expect(find.text('Reported: Abusive language'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
