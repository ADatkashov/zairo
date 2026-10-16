import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:zairo/features/catalog/data/catalog_api.dart';
import 'package:zairo/features/catalog/data/models/category.dart';
import 'package:zairo/features/catalog/presentation/providers/catalog_providers.dart' show catalogApiProvider;
import 'package:zairo/features/discovery/data/discovery_api.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/data/models/service_summary.dart';
import 'package:zairo/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:zairo/features/discovery/presentation/screens/search_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

/// In-memory stand-in — RecentSearchesController persists through
/// SecureStorageService, and this app's tests never talk to the real
/// flutter_secure_storage plugin (no platform channel in a widget test).
class _FakeSecureStorageService extends SecureStorageService {
  _FakeSecureStorageService() : super(const FlutterSecureStorage());

  final Map<String, String> _values = {};

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class _FakeDiscoveryApi extends DiscoveryApi {
  _FakeDiscoveryApi(this._results) : super(DioClient(Dio()));

  final List<ProviderSearchResult> _results;

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
    String? cityCode,
  }) async {
    return _results;
  }
}

class _RecordingDiscoveryApi extends DiscoveryApi {
  _RecordingDiscoveryApi() : super(DioClient(Dio()));

  String? lastVertical;
  String? lastQuery;
  String? lastSort;
  bool? lastAvailableOnly;
  double? lastMinRating;

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
    String? cityCode,
  }) async {
    lastVertical = vertical;
    lastQuery = query;
    lastSort = sort;
    lastAvailableOnly = availableOnly;
    lastMinRating = minRating;
    return const [];
  }
}

class _FakeCatalogApi extends CatalogApi {
  _FakeCatalogApi(this._categories) : super(DioClient(Dio()));

  final List<Category> _categories;

  @override
  Future<List<Category>> listCategories() async => _categories;
}

const _autoCategory = Category(
  id: 'cat-auto',
  code: 'auto',
  nameKk: 'Авто',
  nameRu: 'Авто',
  nameEn: 'Auto',
  icon: null,
  sortOrder: 1,
  status: 'ACTIVE',
);

void main() {
  testWidgets('shows provider results once loaded', (tester) async {
    final fakeApi = _FakeDiscoveryApi([
      const ProviderSearchResult(
        id: 'p1',
        name: 'Hair Studio',
        vertical: 'beauty',
        status: 'ACTIVE',
        hasOpenAvailability: true,
        minPrice: 30,
        services: [
          ServiceSummary(
            id: 's1',
            title: 'Haircut',
            durationMinutes: 30,
            price: 30,
            currency: 'USD',
          ),
        ],
        distanceKm: 3.7,
        latitude: 43.24,
        longitude: 76.9,
        averageRating: 4.7,
        reviewCount: 128,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchScreen(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Hair Studio'), findsOneWidget);
    expect(find.text('Available today'), findsOneWidget);
    expect(find.text('3.7 km'), findsOneWidget);
    expect(find.text('30 ₸'), findsOneWidget);
    expect(find.text('4.7'), findsOneWidget);
    expect(find.text('(128)'), findsOneWidget);
  });

  testWidgets('shows results as a multi-column grid at desktop width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeApi = _FakeDiscoveryApi([
      const ProviderSearchResult(
        id: 'p1',
        name: 'Hair Studio',
        vertical: 'beauty',
        status: 'ACTIVE',
        hasOpenAvailability: true,
        minPrice: 30,
        services: [
          ServiceSummary(
            id: 's1',
            title: 'Haircut',
            durationMinutes: 30,
            price: 30,
            currency: 'USD',
          ),
        ],
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.text('Hair Studio'), findsOneWidget);
  });

  testWidgets(
    'the desktop grid does not overflow at a large accessibility text scale',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeApi = _FakeDiscoveryApi([
        const ProviderSearchResult(
          id: 'p1',
          name: 'Rossano Ferretti Signature Salon and Spa',
          vertical: 'beauty',
          status: 'ACTIVE',
          hasOpenAvailability: true,
          minPrice: 30,
          services: [
            ServiceSummary(
              id: 's1',
              title: 'Haircut',
              durationMinutes: 30,
              price: 30,
              currency: 'USD',
            ),
          ],
          distanceKm: 12.3,
          averageRating: 4.9,
          reviewCount: 2140,
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: MaterialApp(
              theme: factoryLightTheme(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SearchScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows popular searches above the results, not instead of them', (
    tester,
  ) async {
    final fakeApi = _FakeDiscoveryApi([
      const ProviderSearchResult(
        id: 'p1',
        name: 'Hair Studio',
        vertical: 'beauty',
        status: 'ACTIVE',
        hasOpenAvailability: true,
        services: [],
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Popular searches'), findsOneWidget);
    expect(find.text('Haircut'), findsOneWidget);
    // Still there, unchanged from before this feature existed.
    expect(find.text('Hair Studio'), findsOneWidget);
  });

  testWidgets('tapping a popular search query runs that search', (
    tester,
  ) async {
    final fakeApi = _RecordingDiscoveryApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Massage'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Massage'), findsOneWidget);
    expect(find.text('No results for "Massage"'), findsOneWidget);
  });

  testWidgets(
    'a submitted search is saved to recent searches and can be cleared',
    (tester) async {
      final fakeApi = _RecordingDiscoveryApi();
      final fakeStorage = _FakeSecureStorageService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryApiProvider.overrideWithValue(fakeApi),
            secureStorageServiceProvider.overrideWithValue(fakeStorage),
          ],
          child: MaterialApp(
            theme: factoryLightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'sauna');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Back to the pristine screen (clearing the field re-enters it) to see
      // the search just made show up as a recent one.
      await tester.enterText(find.byType(TextField), '');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.text('sauna'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Recent searches'), findsNothing);
    },
  );

  testWidgets('shows a "no results" state that names the query', (
    tester,
  ) async {
    final fakeApi = _FakeDiscoveryApi(const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'massage');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('No results for "massage"'), findsOneWidget);
  });

  testWidgets(
    'opening filters, picking a sort and available-only re-runs the search with them',
    (tester) async {
      final fakeApi = _RecordingDiscoveryApi();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
          child: MaterialApp(
            theme: factoryLightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fakeApi.lastSort, 'RECOMMENDED');
      expect(fakeApi.lastAvailableOnly, false);

      await tester.tap(find.byIcon(Symbols.tune_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Price: low to high'));
      await tester.ensureVisible(find.text('Available today only'));
      await tester.tap(find.text('Available today only'));
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(fakeApi.lastSort, 'PRICE_ASC');
      expect(fakeApi.lastAvailableOnly, true);
    },
  );

  testWidgets(
    'picking rating sort and enabling min-rating re-runs the search with them',
    (tester) async {
      final fakeApi = _RecordingDiscoveryApi();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
          child: MaterialApp(
            theme: factoryLightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Symbols.tune_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rating'));
      await tester.ensureVisible(find.text('Minimum rating'));
      await tester.tap(find.text('Minimum rating'));
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(fakeApi.lastSort, 'RATING');
      expect(fakeApi.lastMinRating, 4.0);
    },
  );

  testWidgets(
    'picking the Auto category filter re-runs the search with vertical=auto',
    (tester) async {
      final fakeApi = _RecordingDiscoveryApi();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryApiProvider.overrideWithValue(fakeApi),
            // The filter sheet's category chips are sourced from the
            // master catalog (v2 design audit fix), not hardcoded, so this
            // test needs its own "Auto" category to tap.
            catalogApiProvider.overrideWithValue(_FakeCatalogApi([_autoCategory])),
          ],
          child: MaterialApp(
            theme: factoryLightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fakeApi.lastVertical, isNull);

      await tester.tap(find.byIcon(Symbols.tune_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Auto'));
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(fakeApi.lastVertical, 'auto');

      // Reopening the dialog and clearing goes back to no vertical filter.
      await tester.tap(find.byIcon(Symbols.tune_rounded));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Clear'));
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(fakeApi.lastVertical, isNull);
    },
  );

  testWidgets('a category carried in from Home is applied as the vertical filter',
      (tester) async {
    final api = _RecordingDiscoveryApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchScreen(initialVertical: 'auto'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.lastVertical, 'auto');
  });

  testWidgets('empty results for a query offer to reset the search',
      (tester) async {
    final api = _RecordingDiscoveryApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchScreen(initialVertical: 'auto'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.lastVertical, 'auto');

    await tester.tap(find.text('Reset search and filters'));
    await tester.pumpAndSettle();

    expect(api.lastVertical, isNull);
  });

  testWidgets('the clear button empties the query', (tester) async {
    final api = _RecordingDiscoveryApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'massage');
    await tester.pump();
    await tester.tap(find.byIcon(Symbols.close_rounded));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('results follow the text after a pause, without saving half-typed words', (tester) async {
    final api = _RecordingDiscoveryApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.lastQuery, isNull);

    await tester.enterText(find.byType(TextField), 'm');
    await tester.pump(const Duration(milliseconds: 600));
    expect(api.lastQuery, isNull, reason: 'one character is not enough to search');

    await tester.enterText(find.byType(TextField), 'massage');
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.lastQuery, isNull, reason: 'still within the pause');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(api.lastQuery, 'massage');
  });
}
