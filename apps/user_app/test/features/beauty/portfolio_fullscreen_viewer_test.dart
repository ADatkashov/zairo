import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/beauty/data/beauty_api.dart';
import 'package:zairo/features/beauty/data/models/portfolio_item.dart';
import 'package:zairo/features/beauty/presentation/providers/beauty_providers.dart';
import 'package:zairo/features/beauty/presentation/screens/master_portfolio_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeBeautyApi extends BeautyApi {
  _FakeBeautyApi(this._items) : super(DioClient(Dio()));

  final List<PortfolioItem> _items;

  @override
  Future<List<PortfolioItem>> listPortfolio(String masterId) async => _items;
}

const _items = [
  PortfolioItem(
    id: 'item-1',
    masterId: 'master-1',
    imageUrl: 'https://example.com/photo1.jpg',
    caption: 'Balayage look',
  ),
  PortfolioItem(
    id: 'item-2',
    masterId: 'master-1',
    imageUrl: 'https://example.com/photo2.jpg',
    caption: 'Bob cut',
  ),
];

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [beautyApiProvider.overrideWithValue(_FakeBeautyApi(_items))],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MasterPortfolioScreen(masterId: 'master-1', masterName: 'Jamie'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping a photo opens the fullscreen viewer at the right index', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Bob cut'));
    await tester.pumpAndSettle();

    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('Bob cut'), findsOneWidget);
  });

  testWidgets('next/previous buttons navigate between photos and hide at the ends', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Balayage look'));
    await tester.pumpAndSettle();

    expect(find.text('1 of 2'), findsOneWidget);
    // First photo: no previous button, only next.
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('2 of 2'), findsOneWidget);
    // Last photo: no next button, only previous.
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('1 of 2'), findsOneWidget);
  });

  testWidgets('swiping advances to the next photo', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Balayage look'));
    await tester.pumpAndSettle();

    expect(find.text('1 of 2'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('2 of 2'), findsOneWidget);
  });

  testWidgets('the close button returns to the portfolio grid', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Balayage look'));
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsNothing);
    expect(find.text('Balayage look'), findsOneWidget);
  });
}
