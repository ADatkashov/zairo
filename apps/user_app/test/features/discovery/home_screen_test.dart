import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:zairo/features/ads/data/ads_api.dart';
import 'package:zairo/features/ads/data/models/ad_banner.dart';
import 'package:zairo/features/ads/presentation/providers/ads_providers.dart';
import 'package:zairo/features/ads/presentation/screens/ad_video_screen.dart';
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
import 'package:zairo/features/catalog/presentation/screens/all_categories_screen.dart';
import 'package:zairo/features/discovery/presentation/screens/home_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

/// Home now stacks a 4×2 launcher and a promo strip above the category row and
/// the rails, so the default 800×600 window builds none of them. Tall window
/// for the tests that look at those sections (not the scroll/collapse ones).
void _useTallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

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

class _FakeAdsApi extends AdsApi {
  _FakeAdsApi(this._banners) : super(DioClient(Dio()));

  final List<AdBanner> _banners;

  @override
  Future<List<AdBanner>> listBanners({String? cityCode}) async => _banners;
}

class _NeverCatalogApi extends CatalogApi {
  _NeverCatalogApi() : super(DioClient(Dio()));

  @override
  Future<List<Category>> listCategories() => Completer<List<Category>>().future;
}

class _FailingCatalogApi extends CatalogApi {
  _FailingCatalogApi() : super(DioClient(Dio()));

  @override
  Future<List<Category>> listCategories() async => throw Exception('offline');
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
    _useTallWindow(tester);
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

  testWidgets('the hero collapses into a pinned bar on scroll and keeps the city + actions visible', (tester) async {
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

    final expandedHeight = tester.getSize(find.byType(FlexibleSpaceBar)).height;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final collapsedHeight = tester.getSize(find.byType(FlexibleSpaceBar)).height;

    expect(collapsedHeight, lessThan(expandedHeight));
    expect(find.text('Almaty'), findsOneWidget);
    // The quick-action grid has a heart of its own; this one is the bar's.
    expect(
      find.descendant(of: find.byType(SliverAppBar), matching: find.byIcon(Symbols.favorite_rounded)),
      findsOneWidget,
    );
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

  Widget searchRouteApp(List<Category> categories, {CatalogApi? catalogApi}) => ProviderScope(
    overrides: [
      discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi([_open])),
      catalogApiProvider.overrideWithValue(catalogApi ?? _FakeCatalogApi(categories)),
    ],
    child: MaterialApp.router(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/search',
            builder: (_, state) => Scaffold(body: Text('Search page ${state.uri.queryParameters['category']}')),
          ),
          // Stands in for AllCategoriesScreen: "picks" category-9 or backs out.
          GoRoute(
            path: '/categories',
            builder: (context, _) => Scaffold(
              body: Column(
                children: [
                  TextButton(onPressed: () => context.pop('category-9'), child: const Text('Pick nine')),
                  TextButton(onPressed: () => context.pop(), child: const Text('Back out')),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  List<Category> manyCategories(int count) => [
    for (var i = 1; i <= count; i++)
      Category(
        id: 'cat-$i',
        code: 'category-$i',
        nameKk: 'Санат $i',
        nameRu: 'Категория $i',
        nameEn: 'Category $i',
        icon: '🔧',
        sortOrder: i,
        status: 'ACTIVE',
      ),
  ];

  testWidgets('categories are a 4x2 grid that scrolls sideways, with an "All" link in the heading and no shortcut icons', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(searchRouteApp(manyCategories(20)));
    await tester.pumpAndSettle();

    final cats = [for (var i = 1; i <= 8; i++) tester.getTopLeft(find.text('Category $i'))];
    // Row one: 1-4 share a line; row two: 5-8 share the next.
    expect({cats[0].dy, cats[1].dy, cats[2].dy, cats[3].dy}, hasLength(1));
    expect({cats[4].dy, cats[5].dy, cats[6].dy, cats[7].dy}, hasLength(1));
    expect(cats[4].dy, greaterThan(cats[0].dy));
    expect(cats[0].dx, lessThan(cats[1].dx));
    expect(cats[7].dx, greaterThan(cats[6].dx));
    // The second page is off-screen to the right, reachable by swiping.
    expect(find.text('Category 20'), findsNothing);
    final grid = find.ancestor(of: find.text('Category 1'), matching: find.byType(Scrollable));
    await tester.dragUntilVisible(find.text('Category 20'), grid.first, const Offset(-300, 0));
    expect(find.text('Category 20'), findsOneWidget);
    await tester.dragUntilVisible(find.text('Category 1'), grid.first, const Offset(300, 0));
    expect(find.text('All categories'), findsNothing);

    // The heading with its link sits above the grid.
    final heading = tester.getTopLeft(find.text('Categories'));
    expect(heading.dy, lessThan(cats[0].dy));
    expect(find.text('All'), findsOneWidget);
    expect(tester.getTopLeft(find.text('All')).dy, closeTo(heading.dy, 12));
    // "All" sits at the right edge, like "See all" in the other sections.
    expect(tester.getTopRight(find.text('All')).dx, closeTo(tester.getTopRight(find.text('See all')).dx, 2));

    // The old shortcut icons are gone: those places are reachable from the nav
    // bar, the header and Profile, not from Home.
    for (final label in ['Search', 'Bookings', 'My favorites', 'Messages', 'My Rewards', 'Notifications', 'Payment cards', 'Support']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    // The promos are still there, after the categories.
    expect(find.text('Earn rewards for every visit'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Earn rewards for every visit')).dy, greaterThan(cats[7].dy));
  });

  testWidgets('exactly eight categories fit the 4x2 grid without scrolling', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(searchRouteApp(manyCategories(8)));
    await tester.pumpAndSettle();

    expect(find.byType(FactoryCategoryTile), findsNWidgets(8));
    expect(find.ancestor(of: find.text('Category 1'), matching: find.byType(SingleChildScrollView)), findsNothing);
  });

  testWidgets('a half-filled second page adds only the columns it needs', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(searchRouteApp(manyCategories(10)));
    await tester.pumpAndSettle();

    final grid = find.ancestor(of: find.text('Category 1'), matching: find.byType(Scrollable));
    await tester.dragUntilVisible(find.text('Category 10'), grid.first, const Offset(-300, 0));
    final position = tester.state<ScrollableState>(grid.first).position;
    // 4 columns + 2 more: the grid ends right after category 10, no empty page.
    expect(position.maxScrollExtent, lessThan(tester.getSize(find.byType(MaterialApp)).width));
    expect(find.text('Category 10'), findsOneWidget);
  });

  testWidgets('one tap on a category opens Search already narrowed to it', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(searchRouteApp(manyCategories(10)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Category 3'));
    await tester.pumpAndSettle();

    expect(find.text('Search page category-3'), findsOneWidget);
  });

  testWidgets('with fewer than eight categories only those are shown', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(searchRouteApp(manyCategories(2)));
    await tester.pumpAndSettle();

    expect(find.byType(FactoryCategoryTile), findsNWidgets(2));
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('while the catalog loads the grid keeps its place with eight skeletons, and the link works', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(searchRouteApp(const [], catalogApi: _NeverCatalogApi()));
    await tester.pump();

    expect(find.byType(FactorySkeleton), findsNWidgets(8));
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('if the catalog fails there is no grid, Home still loads and the "All" link stays', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(searchRouteApp(const [], catalogApi: _FailingCatalogApi()));
    await tester.pumpAndSettle();

    expect(find.byType(FactoryCategoryTile), findsNothing);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Top rated near you'), findsOneWidget);
  });

  testWidgets('"All" opens the full list and a category picked there carries on to Search', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(searchRouteApp(manyCategories(10)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick nine'));
    await tester.pumpAndSettle();

    expect(find.text('Search page category-9'), findsOneWidget);
  });

  testWidgets('backing out of the full list stays on Home', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(searchRouteApp(manyCategories(10)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back out'));
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
    expect(find.textContaining('Search page'), findsNothing);
  });

  testWidgets('a narrow phone fits four columns without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(searchRouteApp(manyCategories(10)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Category 7'), findsOneWidget);
  });

  testWidgets('the rewards promo card opens My Rewards', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi(const [])),
          catalogApiProvider.overrideWithValue(_FakeCatalogApi(const [])),
        ],
        child: MaterialApp.router(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
              GoRoute(path: '/rewards', builder: (_, _) => const Scaffold(body: Text('Rewards page'))),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing is open today, so the rewards card is the only promo.
    expect(find.textContaining('open slots today'), findsNothing);
    await tester.tap(find.widgetWithText(FactoryPromoCard, 'Earn rewards for every visit'));
    await tester.pumpAndSettle();
    expect(find.text('Rewards page'), findsOneWidget);
  });

  testWidgets('live banners take over the green hero, above the search field, in place of the greeting', (tester) async {
    _useTallWindow(tester);
    final banners = [
      const AdBanner(
        id: 'b1',
        title: 'AI & Digital Bridge',
        subtitle: 'Watch the highlights',
        imageUrl: 'https://cdn.example/1.jpg',
        videoUrl: 'https://video.example/1',
        sponsored: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi([_open])),
          catalogApiProvider.overrideWithValue(_FakeCatalogApi(const [])),
          adsApiProvider.overrideWithValue(_FakeAdsApi(banners)),
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

    expect(find.text('AI & Digital Bridge'), findsOneWidget);
    // Inside the hero app bar, above the search field.
    expect(find.descendant(of: find.byType(SliverAppBar), matching: find.byType(FactoryBannerCard)), findsOneWidget);
    final bannerBottom = tester.getBottomLeft(find.byType(FactoryBannerCard)).dy;
    final searchTop = tester.getTopLeft(find.text('What service are you looking for?')).dy;
    expect(bannerBottom, lessThanOrEqualTo(searchTop));
    // The city row stays on top of the banner; the greeting steps aside.
    expect(find.text('Almaty'), findsOneWidget);
    expect(find.textContaining('Hi,'), findsNothing);
  });

  testWidgets('the banner hero fades out as the bar collapses and the city bar stays', (tester) async {
    final banners = [
      const AdBanner(
        id: 'b1',
        title: 'AI & Digital Bridge',
        subtitle: null,
        imageUrl: 'https://cdn.example/1.jpg',
        videoUrl: null,
        sponsored: false,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi([_open])),
          catalogApiProvider.overrideWithValue(_FakeCatalogApi(const [])),
          adsApiProvider.overrideWithValue(_FakeAdsApi(banners)),
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
    final expanded = tester.getSize(find.byType(AppBar)).height;
    expect(tester.widget<Opacity>(find.ancestor(of: find.byType(PageView), matching: find.byType(Opacity)).first).opacity, 1.0);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(AppBar)).height, lessThan(expanded));
    expect(tester.widget<Opacity>(find.ancestor(of: find.byType(PageView), matching: find.byType(Opacity)).first).opacity, 0.0);
    expect(find.text('Almaty'), findsOneWidget);
  });

  testWidgets('tapping a banner with a video in the hero opens the player route', (tester) async {
    final banners = [
      const AdBanner(
        id: 'b1',
        title: 'AI & Digital Bridge',
        subtitle: null,
        imageUrl: 'https://cdn.example/1.jpg',
        videoUrl: 'https://video.example/1',
        sponsored: false,
      ),
    ];
    Object? extra;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi([_open])),
          catalogApiProvider.overrideWithValue(_FakeCatalogApi(const [])),
          adsApiProvider.overrideWithValue(_FakeAdsApi(banners)),
        ],
        child: MaterialApp.router(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
              GoRoute(
                path: '/ad-video',
                builder: (_, state) {
                  extra = state.extra;
                  return const Scaffold(body: Text('Player page'));
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI & Digital Bridge'));
    await tester.pumpAndSettle();

    expect(find.text('Player page'), findsOneWidget);
    expect((extra as AdVideoArgs).url, 'https://video.example/1');
  });

  testWidgets('Home shows no banner strip when there are no live banners', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi([_open])),
          catalogApiProvider.overrideWithValue(_FakeCatalogApi(const [])),
          adsApiProvider.overrideWithValue(_FakeAdsApi(const [])),
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

    expect(find.byType(FactoryBannerCard), findsNothing);
    // The plain greeting hero.
    expect(find.text('Almaty'), findsOneWidget);
    expect(find.byType(FactoryCategoryTile), findsNothing); // the catalog fake is empty
  });

  testWidgets('shows an empty state when there is nothing to discover yet', (tester) async {
    _useTallWindow(tester);
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
    _useTallWindow(tester);
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

    // find.text('Beauty') alone would also match the category badge that
    // now renders on every "Beauty"-vertical provider card in the Top rated
    // rail below (Customer App Redesign board, 2026-09-05) — scope to the
    // category tile itself, which is what this test is actually about.
    expect(find.widgetWithText(FactoryCategoryTile, 'Beauty'), findsOneWidget);
    expect(find.widgetWithText(FactoryCategoryTile, 'Auto'), findsOneWidget);

    // Home's own feed is never filtered by a category any more: a category tap
    // opens Search instead (see the grid tests above).
    expect(fakeDiscoveryApi.lastVertical, isNull);
  });

  testWidgets(
      'Home shows only the first 8 categories, not the whole catalog; the "All" link opens the full list',
      (tester) async {
    _useTallWindow(tester);
    final fakeDiscoveryApi = _FakeDiscoveryApi([_open, _closed]);
    final fakeCatalogApi = _FakeCatalogApi([
      for (var i = 1; i <= 10; i++)
        Category(
          id: 'cat-$i',
          code: 'category-$i',
          nameKk: 'Санат $i',
          nameRu: 'Категория $i',
          nameEn: 'Category $i',
          icon: '🔧',
          sortOrder: i,
          status: 'ACTIVE',
        ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryApiProvider.overrideWithValue(fakeDiscoveryApi),
          catalogApiProvider.overrideWithValue(fakeCatalogApi),
        ],
        child: MaterialApp.router(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
              GoRoute(
                path: '/categories',
                builder: (_, _) => const AllCategoriesScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 1; i <= 8; i++) {
      expect(find.text('Category $i'), findsOneWidget);
    }
    expect(find.text('Category 9'), findsNothing);
    expect(find.text('Category 10'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // AllCategoriesScreen: the whole catalog, including what Home cut off.
    // The rows are cards now, so the later ones sit below the test window.
    // The list's own Scrollable — the search field has one too.
    final categoriesList = find
        .descendant(
          of: find.descendant(
            of: find.byType(AllCategoriesScreen),
            matching: find.byType(ListView),
          ),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Category 9'),
      100,
      scrollable: categoriesList,
    );
    expect(find.text('Category 9'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Category 10'),
      100,
      scrollable: categoriesList,
    );
    expect(find.text('Category 10'), findsOneWidget);
  });

  testWidgets('shows a Book Again card for a logged-in user with a completed booking', (tester) async {
    _useTallWindow(tester);
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

  testWidgets('the header heart opens Favorites, even for a guest', (tester) async {
    final fakeDiscoveryApi = _FakeDiscoveryApi([_open]);
    final fakeCatalogApi = _FakeCatalogApi(const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryApiProvider.overrideWithValue(fakeDiscoveryApi),
          catalogApiProvider.overrideWithValue(fakeCatalogApi),
        ],
        child: MaterialApp.router(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
              GoRoute(
                path: '/favorites',
                builder: (_, _) => const Scaffold(body: Text('Favorites page')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('My favorites'));
    await tester.pumpAndSettle();

    expect(find.text('Favorites page'), findsOneWidget);
  });
}
