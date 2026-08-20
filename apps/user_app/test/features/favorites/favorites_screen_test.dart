import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/discovery/data/models/service_summary.dart';
import 'package:zairo/features/favorites/data/favorites_api.dart';
import 'package:zairo/features/favorites/data/models/favorite_provider.dart';
import 'package:zairo/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:zairo/features/favorites/presentation/screens/favorites_screen.dart';

class _FakeFavoritesApi extends FavoritesApi {
  _FakeFavoritesApi(this._favorites) : super(DioClient(Dio()));

  final List<FavoriteProvider> _favorites;

  @override
  Future<List<FavoriteProvider>> listFavorites(String userId) async => _favorites;
}

void main() {
  testWidgets('shows an empty state with no favorites', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [favoritesApiProvider.overrideWithValue(_FakeFavoritesApi(const []))],
        child: const MaterialApp(home: FavoritesScreen(userId: 'user-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No favorites yet.'), findsOneWidget);
  });

  testWidgets('lists favorited providers as cards', (tester) async {
    final favorite = FavoriteProvider(
      id: 'provider-1',
      name: 'Favorite Salon',
      vertical: 'beauty',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      minPrice: 30,
      services: const [
        ServiceSummary(id: 's1', title: 'Haircut', durationMinutes: 30, price: 30, currency: 'USD'),
      ],
      favoritedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [favoritesApiProvider.overrideWithValue(_FakeFavoritesApi([favorite]))],
        child: const MaterialApp(home: FavoritesScreen(userId: 'user-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Favorite Salon'), findsOneWidget);
    expect(find.text('Haircut'), findsOneWidget);
  });
}
