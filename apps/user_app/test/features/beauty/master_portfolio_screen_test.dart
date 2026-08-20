import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/beauty/data/beauty_api.dart';
import 'package:zairo/features/beauty/data/models/portfolio_item.dart';
import 'package:zairo/features/beauty/presentation/providers/beauty_providers.dart';
import 'package:zairo/features/beauty/presentation/screens/master_portfolio_screen.dart';

class _FakeBeautyApi extends BeautyApi {
  _FakeBeautyApi(this._items) : super(DioClient(Dio()));

  final List<PortfolioItem> _items;

  @override
  Future<List<PortfolioItem>> listPortfolio(String masterId) async => _items;
}

void main() {
  testWidgets('shows an empty state when the master has no portfolio items', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [beautyApiProvider.overrideWithValue(_FakeBeautyApi(const []))],
        child: const MaterialApp(
          home: MasterPortfolioScreen(masterId: 'master-1', masterName: 'Jamie'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No portfolio photos yet.'), findsOneWidget);
  });

  testWidgets('shows portfolio item captions once loaded', (tester) async {
    final fakeApi = _FakeBeautyApi(const [
      PortfolioItem(
        id: 'item-1',
        masterId: 'master-1',
        imageUrl: 'https://example.com/photo.jpg',
        caption: 'Balayage look',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [beautyApiProvider.overrideWithValue(fakeApi)],
        child: const MaterialApp(
          home: MasterPortfolioScreen(masterId: 'master-1', masterName: 'Jamie'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Balayage look'), findsOneWidget);
  });
}
