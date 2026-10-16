import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/loyalty/data/models/loyalty.dart';
import 'package:zairo/features/loyalty/data/models/page.dart';
import 'package:zairo/features/loyalty/presentation/providers/loyalty_providers.dart';
import 'package:zairo/features/loyalty/presentation/screens/loyalty_history_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

LoyaltyTransaction _tx(
  String id,
  LoyaltyTransactionType type,
  int delta,
  int balance, {
  String reason = 'Visit',
  DateTime? expiresAt,
}) => LoyaltyTransaction(
  id: id,
  type: type,
  pointsDelta: delta,
  balanceAfter: balance,
  reason: reason,
  createdAt: DateTime(2026, 10, 1, 12),
  expiresAt: expiresAt,
);

Page<LoyaltyTransaction> _page(List<LoyaltyTransaction> rows, {int number = 0, int totalPages = 1}) => Page(
  content: rows,
  totalElements: rows.length,
  totalPages: totalPages,
  number: number,
  size: 20,
  first: number == 0,
  last: number + 1 >= totalPages,
);

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoyaltyHistoryScreen(providerId: 'p1', providerName: 'Glow'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty ledger says there is no activity yet', (tester) async {
    await _pump(tester, [loyaltyHistoryProvider(('p1', 0)).overrideWith((ref) async => _page(const []))]);

    expect(find.text('No activity yet'), findsOneWidget);
  });

  testWidgets('rows show type, reason, signed points, balance and when points expire', (tester) async {
    await _pump(tester, [
      loyaltyHistoryProvider(('p1', 0)).overrideWith(
        (ref) async => _page([
          _tx('1', LoyaltyTransactionType.earned, 50, 150, reason: 'Haircut', expiresAt: DateTime(2027, 1, 1)),
          _tx('2', LoyaltyTransactionType.redeemed, -30, 120, reason: 'Free coffee'),
          _tx('3', LoyaltyTransactionType.bonus, 10, 130),
          _tx('4', LoyaltyTransactionType.expired, -5, 125),
          _tx('5', LoyaltyTransactionType.refund, 20, 145),
          _tx('6', LoyaltyTransactionType.adjustment, 0, 145, reason: 'Fix'),
          _tx('7', LoyaltyTransactionType.reversal, -20, 125),
        ]),
      ),
    ]);

    for (final label in ['Earned', 'Redeemed', 'Bonus', 'Expired', 'Refunded', 'Adjustment', 'Reversal']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('+50'), findsOneWidget);
    expect(find.text('-30'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('Balance: 150'), findsOneWidget);
    expect(find.textContaining('Expires'), findsOneWidget);
  });

  testWidgets('"Load more" appends the next page and goes away on the last one', (tester) async {
    await _pump(tester, [
      loyaltyHistoryProvider(('p1', 0)).overrideWith(
        (ref) async => _page([_tx('1', LoyaltyTransactionType.earned, 10, 10, reason: 'First')], totalPages: 2),
      ),
      loyaltyHistoryProvider(('p1', 1)).overrideWith(
        (ref) async => _page([_tx('2', LoyaltyTransactionType.earned, 20, 30, reason: 'Second')], number: 1, totalPages: 2),
      ),
    ]);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Load more'), findsOneWidget);

    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('a failed load offers a retry that loads the history', (tester) async {
    var fail = true;
    await _pump(tester, [
      loyaltyHistoryProvider(('p1', 0)).overrideWith((ref) async {
        if (fail) throw Exception('offline');
        return _page([_tx('1', LoyaltyTransactionType.earned, 10, 10, reason: 'Back')]);
      }),
    ]);
    expect(find.byType(FactoryErrorState), findsOneWidget);

    fail = false;
    await tester.tap(find.byType(FactoryButton));
    await tester.pumpAndSettle();

    expect(find.text('Back'), findsOneWidget);
  });
}
