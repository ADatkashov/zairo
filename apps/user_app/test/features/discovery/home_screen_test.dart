import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/booking/data/booking_api.dart';
import 'package:zairo/features/booking/data/models/book_again_suggestion.dart';
import 'package:zairo/features/booking/presentation/providers/booking_providers.dart';
import 'package:zairo/features/catalog/data/catalog_api.dart';
import 'package:zairo/features/catalog/data/models/business_type.dart';
import 'package:zairo/features/catalog/data/models/category.dart';
import 'package:zairo/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zairo/features/discovery/data/discovery_api.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:zairo/features/discovery/presentation/screens/home_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeDiscoveryApi extends DiscoveryApi {
  _FakeDiscoveryApi(this._results) : super(DioClient(Dio()));

  final List<ProviderSearchResult> _results;
  String? lastVertical;

  @override
  Future<List<ProviderSearchResult>> searchProviders({
    String? vertical,
    String? businessTypeId,
    String? catalogServiceId,
    String? query,
    double? lat,
    double? lng,
    double? minPrice,
    double? maxPrice,
    double? maxDistanceKm,
    double? minRating,
    bool availableOnly = false,
    String? sort,
  }) async {
    lastVertical = vertical;
    return _results;
  }
}

class _FakeCatalogApi extends CatalogApi {
  _FakeCatalogApi(this._categories) : super(DioClient(Dio()));

  final List<Category> _categories;

  @override
  Future<List<Category>> listCategories() async => _categories;

  @override
  Future<List<BusinessType>> listBusinessTypes(String categoryId) async => const [];
}

class _LoggedInAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(id: 'user-1', email: 'aigerim@example.com', displayName: 'Aigerim K.', role: 'CUSTOMER');
  }
}

class _FakeBookingApiWithSuggestions extends BookingApi {
  _FakeBookingApiWithSuggestions(this._suggestions) : super(DioClient(Dio()));

  final List<BookAgainSuggestion> _suggestions;

  @override
  Future<List<BookAgainSuggestion>> listBookAgainSuggestions(String userId) async => _suggestions;
}

const _open = ProviderSearchResult(
  id: 'p1',
  name: 'Aigerim Beauty Studio',
  vertical: 'beauty',
  status: 'ACTIVE',
  hasOpenAvailability: true,
  minPrice: 8000,
  services: [],
  distanceKm: 1.2,
);
const _closed = ProviderSearchResult(
  id: 'p2',
  name: 'Nail Bar 21',
  vertical: 'beauty',
  status: 'ACTIVE',
  hasOpenAvailability: false,
  minPrice: 6000,
  services: [],
  distanceKm: 0.6,
);

void main() {
  testWidgets('shows the curated "top rated" row and the location label', (tester) async {
    final fakeApi = _FakeDiscoveryApi([_open, _closed]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Almaty'), findsOneWidget);
    expect(find.text('What service are you looking for?'), findsOneWidget);
    expect(find.text('Top rated near you'), findsOneWidget);
    expect(find.text('Aigerim Beauty Studio'), findsOneWidget);
    expect(find.text('Nail Bar 21'), findsOneWidget);
  });

  testWidgets('shows the availability hero only when something is open today', (tester) async {
    final fakeApi = _FakeDiscoveryApi([_open, _closed]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('provider'), findsWidgets);
    expect(find.textContaining('open slots today'), findsOneWidget);
  });

  testWidgets('shows an empty state when there is nothing to discover yet', (tester) async {
    final fakeApi = _FakeDiscoveryApi(const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No providers yet'), findsOneWidget);
  });

  testWidgets('category tiles come from the catalog API, not a hardcoded literal', (tester) async {
    final fakeDiscoveryApi = _FakeDiscoveryApi([_open, _closed]);
    final fakeCatalogApi = _FakeCatalogApi(const [
      Category(
        id: 'cat-1',
        code: 'beauty',
        nameKk: 'Сұлулық',
        nameRu: 'Красота',
        nameEn: 'Beauty',
        icon: '💇',
        sortOrder: 1,
        status: 'ACTIVE',
      ),
      Category(
        id: 'cat-2',
        code: 'auto',
        nameKk: 'Авто',
        nameRu: 'Авто',
        nameEn: 'Auto',
        icon: '🚗',
        sortOrder: 2,
        status: 'ACTIVE',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryApiProvider.overrideWithValue(fakeDiscoveryApi),
          catalogApiProvider.overrideWithValue(fakeCatalogApi),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beauty'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);

    await tester.tap(find.text('Beauty'));
    await tester.pumpAndSettle();

    expect(fakeDiscoveryApi.lastVertical, 'beauty');
  });

  testWidgets('shows a Book Again card for a logged-in user with a completed booking', (tester) async {
    final fakeDiscoveryApi = _FakeDiscoveryApi(const []);
    final fakeBookingApi = _FakeBookingApiWithSuggestions([
      BookAgainSuggestion(
        providerId: 'p1',
        providerName: 'Aigerim Beauty Studio',
        vertical: 'beauty',
        serviceId: 's1',
        serviceTitle: 'Haircut',
        durationMinutes: 30,
        price: 25.0,
        currency: 'USD',
        lastVisitAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryApiProvider.overrideWithValue(fakeDiscoveryApi),
          bookingApiProvider.overrideWithValue(fakeBookingApi),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Book again'), findsOneWidget);
    expect(find.text('Aigerim Beauty Studio'), findsOneWidget);
    expect(find.text('Haircut'), findsOneWidget);
  });
}
