import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/payments/data/models/saved_card.dart';
import 'package:zairo/features/payments/data/payments_api.dart';
import 'package:zairo/features/payments/presentation/providers/payments_providers.dart';
import 'package:zairo/features/payments/presentation/screens/saved_cards_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakePaymentsApi extends PaymentsApi {
  _FakePaymentsApi() : super(DioClient(Dio()));

  var _cards = [const SavedCard(id: 'card-1', brand: 'VISA', last4: '4242')];
  var _save = false;
  var canPay = true;
  final removed = <String>[];

  @override
  Future<SavedCards> getSavedCards() async =>
      SavedCards(cards: List.of(_cards), saveOnNextPayment: _save, canPayWithSavedCard: canPay);

  @override
  Future<SavedCards> setSaveOnNextPayment(bool value) async {
    _save = value;
    return getSavedCards();
  }

  @override
  Future<void> removeSavedCard(String cardId) async {
    removed.add(cardId);
    _cards = _cards.where((c) => c.id != cardId).toList();
  }
}

Future<void> _pump(WidgetTester tester, _FakePaymentsApi api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [paymentsApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SavedCardsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists saved cards by brand and last four digits only', (tester) async {
    await _pump(tester, _FakePaymentsApi());

    expect(find.text('VISA •••• 4242'), findsOneWidget);
    expect(find.textContaining('payment page; your saved cards'), findsNothing);
  });

  testWidgets('the save switch is stored on the server', (tester) async {
    final api = _FakePaymentsApi();
    await _pump(tester, api);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(api._save, isTrue);
  });

  testWidgets('removing a card asks first, then forgets it', (tester) async {
    final api = _FakePaymentsApi();
    await _pump(tester, api);

    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this card?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Remove').last);
    await tester.pumpAndSettle();

    expect(api.removed, ['card-1']);
    expect(find.text('VISA •••• 4242'), findsNothing);
    expect(find.text('No saved cards yet'), findsOneWidget);
    // With a way forward, not just a grey line.
    expect(find.textContaining('saved the next time you pay online'), findsOneWidget);
  });

  testWidgets('when cards cannot be charged yet, it says payments still use the payment page', (tester) async {
    await _pump(tester, _FakePaymentsApi()..canPay = false);

    expect(find.textContaining('payments still open the payment page'), findsOneWidget);
  });
}
