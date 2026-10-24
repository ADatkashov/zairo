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
import 'package:zairo/features/catalog/presentation/providers/catalog_providers.dart'
    show catalogApiProvider;
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

/// Answers with 3 providers normally and 2 when "available today only" is on,
/// so the filter sheet's live "Show N options" counter has something to show.
class _CountingDiscoveryApi extends DiscoveryApi {
  _CountingDiscoveryApi() : super(DioClient(Dio()));

  static ProviderSearchResult _provider(String id) => ProviderSearchResult(
    id: id,
    name: 'Studio $id',
    vertical: 'beauty',
    status: 'ACTIVE',
    hasOpenAvailability: true,
    minPrice: 30,
    services: const [],
  );

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
  }) async => [
    _provider('p1'),
    _provider('p2'),
    if (!availableOnly) _provider('p3'),
  ];
}

/// Providers at 1 000 / 8 000 / 21 000 ₸ that honours the price filter the way
/// the backend does (on the provider's cheapest price), and remembers it.
class _PricedDiscoveryApi extends DiscoveryApi {
  _PricedDiscoveryApi({this.prices = const [1000, 8000, 21000]})
    : super(DioClient(Dio()));

  final List<double> prices;
  double? lastMinPrice;
  double? lastMaxPrice;

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
    lastMinPrice = minPrice;
    lastMaxPrice = maxPrice;
    return [
      for (final price in prices)
        if ((minPrice == null || price >= minPrice) &&
            (maxPrice == null || price <= maxPrice))
          ProviderSearchResult(
            id: 'p$price',
            name: 'Studio $price',
            vertical: 'beauty',
            status: 'ACTIVE',
            hasOpenAvailability: true,
            minPrice: price,
            services: [
              ServiceSummary(
                id: 's$price',
                title: 'Cut',
                durationMinutes: 30,
                price: price,
                currency: 'KZT',
              ),
            ],
          ),
    ];
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

      await tester.tap(find.text('Recommended'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Price: low to high').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Available today only'));
      await tester.tap(find.text('Available today only'));
      await tester.ensureVisible(find.text('Show 0 options'));
      await tester.tap(find.text('Show 0 options'));
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

      await tester.tap(find.text('Recommended'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rating').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Minimum rating'));
      await tester.tap(find.text('Minimum rating'));
      await tester.ensureVisible(find.text('Show 0 options'));
      await tester.tap(find.text('Show 0 options'));
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
            catalogApiProvider.overrideWithValue(
              _FakeCatalogApi([_autoCategory]),
            ),
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
      await tester.ensureVisible(find.text('Show 0 options'));
      await tester.tap(find.text('Show 0 options'));
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

  testWidgets(
    'the filter sheet shows eight categories and a "More" chip for the rest',
    (tester) async {
      Category category(int i) => Category(
        id: 'c$i',
        code: 'cat$i',
        nameKk: 'Cat $i',
        nameRu: 'Cat $i',
        nameEn: 'Cat $i',
        icon: null,
        sortOrder: i,
        status: 'ACTIVE',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryApiProvider.overrideWithValue(_RecordingDiscoveryApi()),
            catalogApiProvider.overrideWithValue(
              _FakeCatalogApi([for (var i = 1; i <= 12; i++) category(i)]),
            ),
          ],
          child: MaterialApp(
            theme: factoryLightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // A chosen category beyond the eighth must stay visible.
            home: const SearchScreen(initialVertical: 'cat11'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Symbols.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Cat 1'), findsOneWidget);
      expect(find.text('Cat 8'), findsOneWidget);
      expect(find.text('Cat 9'), findsNothing);
      expect(find.text('Cat 12'), findsNothing);
      // Chip in the sheet and the active-filter chip behind it.
      expect(find.text('Cat 11'), findsNWidgets(2));

      await tester.ensureVisible(find.text('More'));
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      expect(find.text('Cat 12'), findsOneWidget);
      expect(find.text('More'), findsNothing);
    },
  );

  testWidgets(
    'a category carried in from Home is applied as the vertical filter',
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
    },
  );

  testWidgets(
    'the category that narrows the results is shown as a chip that removes it',
    (tester) async {
      final api = _RecordingDiscoveryApi();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryApiProvider.overrideWithValue(api),
            catalogApiProvider.overrideWithValue(
              _FakeCatalogApi([_autoCategory]),
            ),
          ],
          child: MaterialApp(
            theme: factoryLightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SearchScreen(initialVertical: 'auto'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Auto'), findsOneWidget);

      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();

      expect(api.lastVertical, isNull);
      expect(find.text('Auto'), findsNothing);
    },
  );

  testWidgets('empty results for a query offer to reset the search', (
    tester,
  ) async {
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

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets(
    'results follow the text after a pause, without saving half-typed words',
    (tester) async {
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
      expect(
        api.lastQuery,
        isNull,
        reason: 'one character is not enough to search',
      );

      await tester.enterText(find.byType(TextField), 'massage');
      await tester.pump(const Duration(milliseconds: 100));
      expect(api.lastQuery, isNull, reason: 'still within the pause');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(api.lastQuery, 'massage');
    },
  );

  testWidgets(
    'Search results fit a 320 px phone with a large font in the dark theme',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fakeApi = _FakeDiscoveryApi([
        for (var i = 0; i < 4; i++)
          ProviderSearchResult(
            id: 'p$i',
            name: 'Hair Studio With A Long Name Number $i',
            vertical: 'beauty',
            status: 'ACTIVE',
            hasOpenAvailability: i.isEven,
            minPrice: 30,
            services: const [
              ServiceSummary(
                id: 's1',
                title: 'Haircut',
                durationMinutes: 30,
                price: 30,
                currency: 'USD',
              ),
            ],
            distanceKm: 3.7,
            averageRating: 4.7,
            reviewCount: 128,
          ),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
          child: MaterialApp(
            theme: factoryDarkTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const SearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );

  Future<void> openFilters(
    WidgetTester tester,
    DiscoveryApi api, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Symbols.tune_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the filter sheet\'s main button says how many providers match and follows the choices',
    (tester) async {
      await openFilters(tester, _CountingDiscoveryApi());

      expect(find.text('Show 3 options'), findsOneWidget);

      await tester.ensureVisible(find.text('Available today only'));
      await tester.tap(find.text('Available today only'));
      await tester.pumpAndSettle();

      expect(find.text('Show 2 options'), findsOneWidget);
      expect(find.text('Show 3 options'), findsNothing);
    },
  );

  testWidgets(
    'the close button dismisses the filter sheet without applying the choices',
    (tester) async {
      await openFilters(tester, _CountingDiscoveryApi());

      await tester.ensureVisible(find.text('Available today only'));
      await tester.tap(find.text('Available today only'));
      await tester.pumpAndSettle();
      expect(find.text('Show 2 options'), findsOneWidget);

      await tester.tap(find.byTooltip('Close filters'));
      await tester.pumpAndSettle();
      expect(find.text('Filters'), findsNothing);

      // Reopened, the form starts from the unchanged search — nothing was kept.
      await tester.tap(find.byIcon(Symbols.tune_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Show 3 options'), findsOneWidget);
    },
  );

  testWidgets(
    'title, close and the main button stay on screen at 320px with a large font',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await openFilters(tester, _CountingDiscoveryApi(), textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.byTooltip('Close filters'), findsOneWidget);
      expect(find.text('Show 3 options'), findsOneWidget);
      expect(
        tester.getRect(find.text('Show 3 options')).bottom,
        lessThanOrEqualTo(640),
      );
    },
  );

  testWidgets(
    'the price filter is a range slider over the prices actually on offer',
    (tester) async {
      final api = _PricedDiscoveryApi();
      await openFilters(tester, api);

      final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
      expect(slider.min, 1000);
      expect(slider.max, 21000);
      expect(slider.values, const RangeValues(1000, 21000));
      expect(
        find.byType(TextField),
        findsNWidgets(3),
      ); // the search field + the From / To boxes
      expect(find.text('Show 3 options'), findsOneWidget);

      slider.onChanged!(const RangeValues(5000, 21000));
      await tester.pump();
      slider.onChangeEnd!(const RangeValues(5000, 21000));
      await tester.pumpAndSettle();
      expect(find.text('Show 2 options'), findsOneWidget);

      await tester.tap(find.text('Show 2 options'));
      await tester.pumpAndSettle();

      // Only the end that was moved is a limit; the other stays open.
      expect(api.lastMinPrice, 5000);
      expect(api.lastMaxPrice, isNull);
    },
  );

  testWidgets('dragging an end back to its limit lifts that limit', (
    tester,
  ) async {
    final api = _PricedDiscoveryApi();
    await openFilters(tester, api);

    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    slider.onChanged!(const RangeValues(1000, 9000));
    await tester.pump();
    slider.onChangeEnd!(const RangeValues(1000, 9000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show 2 options'));
    await tester.pumpAndSettle();
    expect(api.lastMinPrice, isNull);
    expect(api.lastMaxPrice, 9000);
  });

  testWidgets(
    'a price limit already applied is shown on the slider when the sheet reopens',
    (tester) async {
      final api = _PricedDiscoveryApi();
      await openFilters(tester, api);

      final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
      slider.onChanged!(const RangeValues(5000, 21000));
      await tester.pump();
      slider.onChangeEnd!(const RangeValues(5000, 21000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show 2 options'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Symbols.tune_rounded));
      await tester.pumpAndSettle();
      expect(
        tester.widget<RangeSlider>(find.byType(RangeSlider)).values,
        const RangeValues(5000, 21000),
      );
    },
  );

  testWidgets('no slider when every provider costs the same', (tester) async {
    await openFilters(tester, _PricedDiscoveryApi(prices: const [5000, 5000]));

    expect(find.byType(RangeSlider), findsNothing);
    // Nothing to slide between, but exact prices can still be typed.
    expect(find.text('Price range'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Show 2 options'), findsOneWidget);
  });

  testWidgets('the price slider and its label fit 320px with a large font', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openFilters(tester, _PricedDiscoveryApi(), textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.byType(RangeSlider), findsOneWidget);
    expect(find.text('Show 3 options'), findsOneWidget);
  });

  testWidgets('typed prices apply as the limits and move the slider', (
    tester,
  ) async {
    final api = _PricedDiscoveryApi();
    await openFilters(tester, api);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '5000');
    await tester.enterText(fields.at(2), '9000');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(
      tester.widget<RangeSlider>(find.byType(RangeSlider)).values,
      const RangeValues(5000, 9000),
    );
    expect(find.text('Show 1 option'), findsOneWidget);

    await tester.tap(find.text('Show 1 option'));
    await tester.pumpAndSettle();
    expect(api.lastMinPrice, 5000);
    expect(api.lastMaxPrice, 9000);
  });

  testWidgets(
    'moving the slider fills the price boxes, an end at its limit leaves its box empty',
    (tester) async {
      await openFilters(tester, _PricedDiscoveryApi());

      final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
      slider.onChanged!(const RangeValues(5000, 21000));
      await tester.pump();

      String text(int i) => tester
          .widget<TextField>(find.byType(TextField).at(i))
          .controller!
          .text;
      expect(text(1), '5000');
      expect(text(2), '');
    },
  );

  testWidgets(
    'prices typed the wrong way round are read as a range, not as nothing',
    (tester) async {
      final api = _PricedDiscoveryApi();
      await openFilters(tester, api);

      await tester.enterText(find.byType(TextField).at(1), '9000');
      await tester.enterText(find.byType(TextField).at(2), '5000');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show 1 option'));
      await tester.pumpAndSettle();

      expect(api.lastMinPrice, 5000);
      expect(api.lastMaxPrice, 9000);
    },
  );

  testWidgets(
    'sorting is a select: it shows the current choice and applies the picked one',
    (tester) async {
      final api = _RecordingDiscoveryApi();
      await openFilters(tester, api);

      expect(
        find.byType(DropdownButtonFormField<DiscoverySort>),
        findsOneWidget,
      );
      await tester.tap(find.text('Recommended'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Distance').last);
      await tester.pumpAndSettle();
      // The chosen option is what the select now shows.
      expect(find.text('Distance'), findsOneWidget);

      await tester.tap(find.text('Show 0 options'));
      await tester.pumpAndSettle();
      expect(api.lastSort, 'DISTANCE');
    },
  );
}
