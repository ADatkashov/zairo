import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/app/routes.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

void main() {
  testWidgets('payouts: the to-pay list names the business and totals per currency', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), location: ConsoleRoutes.finance);
    expect(find.text('Zen Spa'), findsOneWidget);
    expect(find.text('To pay'), findsWidgets);
    expect(find.textContaining('1 payout'), findsOneWidget);
    expect(find.text('PAYABLE'), findsNothing);
  });

  testWidgets('mark paid asks for the transfer reference and warns that it records, not moves, money', (tester) async {
    final backend = defaultBackend();
    backend.on('POST', '/platform/payouts/po1/mark-paid', (_) => FakeReply(payoutJson('po1', 'PAID')));
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.finance);

    await tester.tap(find.widgetWithText(FilledButton, 'Mark as paid'));
    await tester.pumpAndSettle();
    expect(find.textContaining('actually received the money'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Transfer reference (optional)'), 'kaspi-77');
    await tester.tap(find.widgetWithText(FilledButton, 'Mark as paid').last);
    await tester.pumpAndSettle();

    expect(
      (backend.calls('POST', '/platform/payouts/po1/mark-paid').single.data as Map)['providerReference'],
      'kaspi-77',
    );
    expect(find.text('Marked as paid'), findsOneWidget);
  });

  testWidgets('mark failed sends the reason; start transfer marks it in progress', (tester) async {
    final backend = defaultBackend();
    backend.on('POST', '/platform/payouts/po1/mark-failed', (_) => FakeReply(payoutJson('po1', 'FAILED')));
    backend.on('POST', '/platform/payouts/po1/mark-processing', (_) => FakeReply(payoutJson('po1', 'PROCESSING')));
    await pumpConsole(tester, backend: backend, location: ConsoleRoutes.finance);

    await tester.tap(find.text('Start transfer'));
    await tester.pumpAndSettle();
    expect(backend.calls('POST', '/platform/payouts/po1/mark-processing'), hasLength(1));

    await tester.tap(find.widgetWithText(TextButton, 'Mark as failed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'What went wrong (optional)'), 'wrong IBAN');
    await tester.tap(find.widgetWithText(FilledButton, 'Mark as failed'));
    await tester.pumpAndSettle();
    expect((backend.calls('POST', '/platform/payouts/po1/mark-failed').single.data as Map)['reason'], 'wrong IBAN');
  });

  testWidgets('status chips switch the list; paid payouts have no actions', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), location: ConsoleRoutes.finance);
    await tester.tap(find.widgetWithText(FactoryChip, 'Paid'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Transfer reference: kaspi-1'), findsOneWidget);
    expect(find.text('Mark as paid'), findsNothing);
  });

  testWidgets('support can read payouts but not settle them', (tester) async {
    await pumpConsole(
      tester,
      backend: defaultBackend(role: 'PLATFORM_SUPPORT'),
      location: ConsoleRoutes.finance,
    );
    expect(find.text('Zen Spa'), findsOneWidget);
    expect(find.text('Mark as paid'), findsNothing);
    expect(find.text('Start transfer'), findsNothing);
  });

  testWidgets('refunds: failed payments explain who is owed; any role can reconcile; a mismatch is described', (
    tester,
  ) async {
    final backend = defaultBackend(role: 'PLATFORM_SUPPORT');
    await pumpConsole(tester, backend: backend, location: '${ConsoleRoutes.finance}?tab=refunds');
    expect(find.text('Refund failed'), findsOneWidget);
    expect(find.text('Provider timeout'), findsOneWidget);
    expect(find.text('3 attempts so far'), findsOneWidget);

    await tester.tap(find.text('Check with payment provider'));
    await tester.pumpAndSettle();
    expect(find.text('Statuses differ'), findsOneWidget);
    expect(find.textContaining('Nothing was changed automatically'), findsOneWidget);
    expect(find.text('In ZAIRO: Refund failed'), findsOneWidget);
    expect(find.text('At the provider: Succeeded'), findsOneWidget);
    expect(backend.calls('POST', '/platform/payments/pay-9/reconcile'), hasLength(1));
  });

  testWidgets('refund queue: the retry state shows next attempt and last error', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), location: '${ConsoleRoutes.finance}?tab=refunds');
    await tester.tap(find.widgetWithText(FactoryChip, 'Will retry'));
    await tester.pumpAndSettle();
    expect(find.text('pg_status=error'), findsOneWidget);
    expect(find.textContaining('Next attempt:'), findsOneWidget);
    await tester.tap(find.widgetWithText(FactoryChip, 'Waiting'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing in this state'), findsOneWidget);
  });

  testWidgets('no failed refunds is good news, not an empty void', (tester) async {
    final backend = defaultBackend();
    backend.reply('GET', '/platform/payments/failed-refunds', []);
    await pumpConsole(tester, backend: backend, location: '${ConsoleRoutes.finance}?tab=refunds');
    expect(find.text('No failed refunds'), findsOneWidget);
  });

group('commission', () {
  testWidgets('shows the 0% default and each category with its own or inherited rate', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), location: '${ConsoleRoutes.finance}?tab=commission');
    expect(find.text('Default commission'), findsOneWidget);
    expect(find.text('0%'), findsWidgets);
    expect(find.text('Beauty'), findsOneWidget);
    expect(find.text('8%'), findsOneWidget);
    expect(find.text('Own rate for this category'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Follows the default'), findsOneWidget);
  });

  testWidgets('an admin sets a category rate; a comma decimal is sent as a number', (tester) async {
    final backend = defaultBackend();
    backend.on('PUT', '/platform/commission/categories/c-auto', (_) => FakeReply(commissionJson()));
    await pumpConsole(tester, backend: backend, location: '${ConsoleRoutes.finance}?tab=commission');

    // Auto is the second card; its "Change" button is the last one.
    await tester.tap(find.widgetWithText(FilledButton, 'Change').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Percent (%)'), '7,5');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect((backend.calls('PUT', '/platform/commission/categories/c-auto').single.data as Map)['ratePercent'], 7.5);
    expect(find.text('Commission updated'), findsOneWidget);
  });

  testWidgets('an out-of-range percent is rejected before anything is sent', (tester) async {
    final backend = defaultBackend();
    await pumpConsole(tester, backend: backend, location: '${ConsoleRoutes.finance}?tab=commission');

    await tester.tap(find.widgetWithText(FilledButton, 'Change').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Percent (%)'), '150');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(backend.calls('PUT', '/platform/commission/default'), isEmpty);
    expect(find.textContaining('from 0 to 100'), findsWidgets);
  });

  testWidgets('removing a category rate calls DELETE', (tester) async {
    final backend = defaultBackend();
    backend.on('DELETE', '/platform/commission/categories/c-beauty', (_) => FakeReply(commissionJson(beautyPercent: null)));
    await pumpConsole(tester, backend: backend, location: '${ConsoleRoutes.finance}?tab=commission');

    await tester.tap(find.text('Use default'));
    await tester.pumpAndSettle();
    expect(backend.calls('DELETE', '/platform/commission/categories/c-beauty'), hasLength(1));
  });

  testWidgets('support can read the rates but not change them', (tester) async {
    await pumpConsole(
      tester,
      backend: defaultBackend(role: 'PLATFORM_SUPPORT'),
      location: '${ConsoleRoutes.finance}?tab=commission',
    );
    expect(find.text('Beauty'), findsOneWidget);
    expect(find.text('Change'), findsNothing);
    expect(find.text('Use default'), findsNothing);
  });
});
}
