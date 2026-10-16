import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/discovery/data/models/service_summary.dart';
import 'package:zairo/features/favorites/data/favorites_api.dart';
import 'package:zairo/features/favorites/data/models/favorite_provider.dart';
import 'package:zairo/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:zairo/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:zairo/features/workers/data/models/favorite_worker.dart';
import 'package:zairo/features/workers/data/workers_api.dart';
import 'package:zairo/features/workers/presentation/providers/workers_providers.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeFavoritesApi extends FavoritesApi {
  _FakeFavoritesApi(this._favorites) : super(DioClient(Dio()));

  final List<FavoriteProvider> _favorites;
  final List<String> removedProviderIds = [];

  @override
  Future<List<FavoriteProvider>> listFavorites(String userId) async => _favorites;

  @override
  Future<void> removeFavorite(String userId, String providerId) async {
    removedProviderIds.add(providerId);
    _favorites.removeWhere((f) => f.id == providerId);
  }
}

class _FakeWorkersApi extends WorkersApi {
  _FakeWorkersApi(this._masters, {this.fail = false}) : super(DioClient(Dio()));

  final List<FavoriteWorker> _masters;
  final bool fail;

  @override
  Future<List<FavoriteWorker>> listFavoriteWorkers(String userId) async {
    if (fail) throw Exception('offline');
    return _masters;
  }
}

const _master = FavoriteWorker(
  id: 'w1',
  kind: 'MASTER',
  providerId: 'p1',
  providerName: 'Studio',
  displayName: 'Aigerim K.',
  photoUrl: null,
  averageRating: 4.8,
  reviewCount: 9,
);

class _LoggedInAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(id: 'user-1', email: 'a@example.com', displayName: 'A', role: 'CUSTOMER');
  }
}

class _LoggedOutAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async => null;
}

void main() {
  testWidgets('shows a login gate when logged out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesApiProvider.overrideWithValue(_FakeFavoritesApi(const [])),
          authControllerProvider.overrideWith(_LoggedOutAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FavoritesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log in to see your favorites'), findsOneWidget);
  });

  testWidgets('shows an empty state with no favorites', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesApiProvider.overrideWithValue(_FakeFavoritesApi(const [])),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FavoritesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No favorites yet'), findsOneWidget);
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
        overrides: [
          favoritesApiProvider.overrideWithValue(_FakeFavoritesApi([favorite])),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FavoritesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Favorite Salon renders via the shared ProviderCard — title, price and
    // availability only; per-service chips aren't part of that component
    // (see core_ui's FactoryProviderCard spec), so "Haircut" itself isn't
    // asserted.
    expect(find.text('Favorite Salon'), findsOneWidget);
    expect(find.text('Available today'), findsOneWidget);
  });

  testWidgets('clear all removes every favorite after confirmation', (tester) async {
    final favorites = [
      FavoriteProvider(
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
      ),
      FavoriteProvider(
        id: 'provider-2',
        name: 'Favorite Barber',
        vertical: 'beauty',
        status: 'ACTIVE',
        hasOpenAvailability: false,
        minPrice: 20,
        services: const [],
        favoritedAt: DateTime(2026, 1, 2),
      ),
    ];
    final fakeApi = _FakeFavoritesApi(favorites);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesApiProvider.overrideWithValue(fakeApi),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FavoritesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    // Confirmation dialog — dismissing with "Keep favorites" doesn't call the API.
    expect(find.text('Clear all favorites?'), findsOneWidget);
    await tester.tap(find.text('Keep favorites'));
    await tester.pumpAndSettle();
    expect(fakeApi.removedProviderIds, isEmpty);
    expect(find.text('Favorite Salon'), findsOneWidget);

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear all'));
    await tester.pumpAndSettle();

    expect(fakeApi.removedProviderIds, unorderedEquals(['provider-1', 'provider-2']));
    expect(find.text('No favorites yet'), findsOneWidget);
  });

  Widget mastersApp(List<FavoriteProvider> providers, _FakeWorkersApi workers) => ProviderScope(
    retry: (_, _) => null,
    overrides: [
      favoritesApiProvider.overrideWithValue(_FakeFavoritesApi(providers)),
      workersApiProvider.overrideWithValue(workers),
      authControllerProvider.overrideWith(_LoggedInAuthController.new),
    ],
    child: MaterialApp.router(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const FavoritesScreen()),
          GoRoute(
            path: '/worker/:id',
            builder: (_, state) => Scaffold(body: Text('worker ${state.pathParameters['id']}')),
          ),
        ],
      ),
    ),
  );

  testWidgets('"My masters" shows the hearted masters above the businesses; a tap opens the master', (tester) async {
    final favorite = FavoriteProvider(
      id: 'provider-1',
      name: 'Favorite Salon',
      vertical: 'beauty',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      minPrice: 30,
      services: const [],
      favoritedAt: DateTime(2026, 1, 1),
    );
    await tester.pumpWidget(mastersApp([favorite], _FakeWorkersApi([_master])));
    await tester.pumpAndSettle();

    expect(find.text('My masters'), findsOneWidget);
    expect(find.text('Aigerim K.'), findsOneWidget);
    expect(find.text('Favorite Salon'), findsOneWidget);

    await tester.tap(find.text('Aigerim K.'));
    await tester.pumpAndSettle();
    expect(find.text('worker w1'), findsOneWidget);
  });

  testWidgets('masters are shown even when no business is favorited yet', (tester) async {
    await tester.pumpWidget(mastersApp(const [], _FakeWorkersApi([_master])));
    await tester.pumpAndSettle();

    expect(find.text('My masters'), findsOneWidget);
    expect(find.text('Aigerim K.'), findsOneWidget);
    expect(find.text('No favorites yet'), findsOneWidget);
  });

  testWidgets('no masters rail when there are none or the list cannot be loaded', (tester) async {
    await tester.pumpWidget(mastersApp(const [], _FakeWorkersApi(const [])));
    await tester.pumpAndSettle();
    expect(find.text('My masters'), findsNothing);
    expect(find.text('No favorites yet'), findsOneWidget);

    await tester.pumpWidget(mastersApp(const [], _FakeWorkersApi(const [], fail: true)));
    await tester.pumpAndSettle();
    expect(find.text('My masters'), findsNothing);
    expect(find.text('No favorites yet'), findsOneWidget);
  });
}
