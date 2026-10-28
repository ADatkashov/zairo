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
import 'package:zairo/features/booking/data/models/booking.dart';
import 'package:zairo/features/booking/presentation/providers/booking_providers.dart';
import 'package:zairo/features/catalog/data/catalog_api.dart';
import 'package:zairo/features/catalog/data/models/business_type.dart';
import 'package:zairo/features/catalog/data/models/category.dart';
import 'package:zairo/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zairo/features/discovery/data/discovery_api.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/data/models/service_summary.dart';
import 'package:zairo/features/discovery/popular_services.dart';
import 'package:zairo/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:zairo/features/catalog/presentation/screens/all_categories_screen.dart';
import 'package:zairo/features/discovery/presentation/screens/home_screen.dart';
import 'package:zairo/features/workers/data/models/favorite_worker.dart';
import 'package:zairo/features/workers/data/models/top_worker.dart';
import 'package:zairo/features/workers/data/workers_api.dart';
import 'package:zairo/features/workers/presentation/providers/workers_providers.dart';
import 'package:zairo/l10n/app_localizations.dart';

/// Home now stacks the search, quick chips and a 4×2 launcher above the banners and
/// the rails, so the default 800×600 window builds none of them. Tall window
/// for the tests that look at those sections (not the scroll/collapse ones).
void _useTallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Whether [finder]'s widget lies fully inside the (test) screen. A horizontally scrolling grid builds its
/// off-screen pages too (and lets the next column peek in at the edge), so "not there" is a position, not an absence.
bool _isOnScreen(WidgetTester tester, Finder finder) {
  final box = tester.getRect(finder);
  return box.left >= 0 && box.right <= tester.view.physicalSize.width / tester.view.devicePixelRatio;
}

class _FakeDiscoveryApi extends DiscoveryApi {
  _FakeDiscoveryApi(this._results, {this.popular = const []}) : super(DioClient(Dio()));

  final List<ProviderSearchResult> _results;

  /// What the backend's most-booked list returns; empty is a young platform, throwing is offline.
  final List<PopularService> popular;
  bool popularFails = false;
  String? lastVertical;

  @override
  Future<List<PopularService>> popularServices({String? cityCode, int limit = 8}) async {
    if (popularFails) throw Exception('offline');
    return popular;
  }

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

class _FakeWorkersApi extends WorkersApi {
  _FakeWorkersApi(this._top, {this.favorites = const []}) : super(DioClient(Dio()));

  final List<TopWorker> _top;
  final List<FavoriteWorker> favorites;

  @override
  Future<List<FavoriteWorker>> listFavoriteWorkers(String userId) async => favorites;

  @override
  Future<List<TopWorker>> listTop({int limit = 10, String? cityCode}) async => _top;
}

const _aigerim = TopWorker(
  id: 'w1',
  kind: 'MASTER',
  providerId: 'p1',
  providerName: 'Aigerim Beauty Studio',
  displayName: 'Aigerim K.',
  photoUrl: null,
  averageRating: 4.8,
  reviewCount: 17,
);

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
    // Nobody has a rating yet, so the row does not claim to be top rated.
    expect(find.text('Near you'), findsOneWidget);
    expect(find.text('Top rated near you'), findsNothing);
    expect(find.text('Aigerim Beauty Studio'), findsOneWidget);
    expect(find.text('Nail Bar 21'), findsOneWidget);
  });

  testWidgets('with three or more rated businesses the row is "Top rated", best first, and leaves out the unrated', (tester) async {
    _useTallWindow(tester);
    ProviderSearchResult rated(String id, String name, double rating, int reviews) => ProviderSearchResult(
      id: id,
      name: name,
      vertical: 'beauty',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      services: const [],
      averageRating: rating,
      reviewCount: reviews,
    );
    final fakeApi = _FakeDiscoveryApi([
      _closed, // no rating at all
      rated('r1', 'Good Studio', 4.2, 10),
      rated('r2', 'Best Studio', 4.9, 3),
      rated('r3', 'Fine Studio', 4.5, 40),
    ]);

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

    expect(find.text('Top rated near you'), findsOneWidget);
    final best = tester.getTopLeft(find.text('Best Studio').first).dx;
    final fine = tester.getTopLeft(find.text('Fine Studio').first).dx;
    final good = tester.getTopLeft(find.text('Good Studio').first).dx;
    expect(best, lessThan(fine));
    expect(fine, lessThan(good));
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

  testWidgets('the greeting hero is short: the search field starts in the top quarter of a phone screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi([_open, _closed]))],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The main action (search, then categories) must not sit below a third of
    // the screen of empty green.
    final search = tester.getRect(find.text('What service are you looking for?'));
    expect(search.top, lessThan(844 / 4));
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
    // The later pages are off-screen to the right, reachable by swiping.
    expect(_isOnScreen(tester, find.text('Category 20')), isFalse);
    final grid = find.ancestor(of: find.text('Category 1'), matching: find.byType(Scrollable));
    await tester.dragUntilVisible(find.text('Category 20'), grid.first, const Offset(-300, 0));
    expect(_isOnScreen(tester, find.text('Category 20')), isTrue);
    await tester.dragUntilVisible(find.text('Category 1'), grid.first, const Offset(300, 0));
    expect(_isOnScreen(tester, find.text('Category 1')), isTrue);
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
    // The shortcuts ("Today", "Nearby", "Top rated") sit above the categories, where the old promo card used to
    // push them down; the rewards card is not there (bonuses are a banner now).
    expect(tester.getTopLeft(find.text('Today')).dy, lessThan(heading.dy));
    expect(find.textContaining('open slots today'), findsNothing);
    expect(find.text('Earn rewards for every visit'), findsNothing);
  });

  testWidgets('a category label may use the gap beside its cell, so a long word does not break in the middle', (tester) async {
    _useTallWindow(tester);

    // 20 categories scroll: 4.4 columns on screen. 800 px wide minus the 16 px page padding on both sides.
    await tester.pumpWidget(searchRouteApp(manyCategories(20)));
    await tester.pumpAndSettle();
    const gap = 8.0;
    final scrollingCell = (768 - gap * 4) / 4.4;
    expect(tester.widget<FactoryCategoryTile>(find.byType(FactoryCategoryTile).first).labelMaxWidth, closeTo(scrollingCell + gap, 0.01));

    // 8 or fewer fit four exact columns.
    await tester.pumpWidget(searchRouteApp(manyCategories(8)));
    await tester.pumpAndSettle();
    final fixedCell = (768 - gap * 3) / 4;
    expect(tester.widget<FactoryCategoryTile>(find.byType(FactoryCategoryTile).first).labelMaxWidth, closeTo(fixedCell + gap, 0.01));
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
    // Nobody has a rating yet, so the row does not claim to be top rated.
    expect(find.text('Near you'), findsOneWidget);
    expect(find.text('Top rated near you'), findsNothing);
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

  testWidgets('a banner with a rewards link opens My Rewards when tapped', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi(const [])),
          catalogApiProvider.overrideWithValue(_FakeCatalogApi(const [])),
          adsApiProvider.overrideWithValue(
            _FakeAdsApi(const [
              AdBanner(
                id: 'b1',
                title: 'Earn bonuses for every visit',
                subtitle: null,
                imageUrl: 'https://cdn.example/1.jpg',
                videoUrl: null,
                linkTarget: 'REWARDS',
                sponsored: false,
              ),
            ]),
          ),
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

    await tester.tap(find.text('Earn bonuses for every visit'));
    await tester.pumpAndSettle();

    expect(find.text('Rewards page'), findsOneWidget);
  });

  Widget routedHome({
    List<ProviderSearchResult> results = const [_open],
    List<Category> categories = const [],
    List<AdBanner> banners = const [],
    double textScale = 1,
  }) => ProviderScope(
    overrides: [
      discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi(results)),
      catalogApiProvider.overrideWithValue(_FakeCatalogApi(categories)),
      adsApiProvider.overrideWithValue(_FakeAdsApi(banners)),
    ],
    child: MaterialApp.router(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          // Shows where Home sent the person, query string and all.
          GoRoute(path: '/search', builder: (_, state) => Scaffold(body: Text('Search ${state.uri}'))),
        ],
      ),
    ),
  );

  const promo = AdBanner(
    id: 'b1',
    title: 'AI & Digital Bridge',
    subtitle: 'Watch the highlights',
    imageUrl: 'https://cdn.example/1.jpg',
    videoUrl: 'https://video.example/1',
    sponsored: false,
  );

  testWidgets('live banners sit under search and the categories, in a card; the greeting hero stays', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(routedHome(categories: manyCategories(8), banners: const [promo]));
    await tester.pumpAndSettle();

    expect(find.text('AI & Digital Bridge'), findsOneWidget);
    // Not in the app bar any more: the green hero is the plain greeting.
    expect(find.descendant(of: find.byType(SliverAppBar), matching: find.byType(FactoryBannerCard)), findsNothing);
    expect(find.textContaining('Hi,'), findsNothing); // a guest sees "Welcome"
    expect(find.text('Welcome'), findsOneWidget);
    // Order: search, shortcuts, categories, then the promo.
    final search = tester.getTopLeft(find.text('What service are you looking for?')).dy;
    final chips = tester.getTopLeft(find.text('Today')).dy;
    final categories = tester.getTopLeft(find.text('Categories')).dy;
    final banner = tester.getTopLeft(find.byType(FactoryBannerCard)).dy;
    expect(search, lessThan(chips));
    expect(chips, lessThan(categories));
    expect(categories, lessThan(banner));
  });

  testWidgets('the quick chips open Search already narrowed: free today, nearest, best rated', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(routedHome());
    await tester.pumpAndSettle();

    for (final (chip, target) in [
      ('Today', '/search?available=1'),
      ('Nearby', '/search?sort=DISTANCE'),
      ('Top rated', '/search?sort=RATING'),
    ]) {
      await tester.tap(find.text(chip));
      await tester.pumpAndSettle();
      expect(find.text('Search $target'), findsOneWidget, reason: chip);

      // Back lands on Home again, ready for the next one.
      GoRouter.of(tester.element(find.textContaining('Search /search'))).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the quick chips fit a 320 px phone with a large font by scrolling sideways, not by growing a row', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(routedHome(textScale: 2));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('"Popular services" lists what the most businesses offer, with the lowest price, and a tap searches for it', (tester) async {
    _useTallWindow(tester);
    ProviderSearchResult studio(String id, List<ServiceSummary> services) => ProviderSearchResult(
      id: id,
      name: 'Studio $id',
      vertical: 'beauty',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      minPrice: 4000,
      services: services,
    );
    ServiceSummary svc(String title, double price) =>
        ServiceSummary(id: '$title$price', title: title, durationMinutes: 30, price: price, currency: 'KZT');
    await tester.pumpWidget(
      routedHome(
        results: [
          studio('a', [svc('Haircut', 5000), svc('Manicure', 7000)]),
          studio('b', [svc('Haircut', 4000)]),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Popular services'), findsOneWidget);
    expect(find.text('2 businesses'), findsOneWidget);
    expect(find.text('1 business'), findsOneWidget);
    expect(find.text('from '), findsWidgets);
    // Most offered first.
    expect(
      tester.getTopLeft(find.text('Haircut')).dx,
      lessThan(tester.getTopLeft(find.text('Manicure')).dx),
    );

    await tester.tap(find.text('Haircut'));
    await tester.pumpAndSettle();
    expect(find.text('Search /search?q=Haircut'), findsOneWidget);
  });

  group('next booking card', () {
    Booking booking(String id, {String status = 'CONFIRMED', Duration? in_, String? provider = 'Studio One'}) => Booking(
      id: id,
      userId: 'user-1',
      serviceId: 's',
      availabilitySlotId: 'slot',
      status: status,
      totalPrice: 100,
      createdAt: DateTime.now(),
      serviceTitle: 'Haircut',
      providerName: provider,
      startsAt: in_ == null ? null : DateTime.now().add(in_),
    );

    Widget homeWith(List<Booking> bookings, {bool loggedIn = true}) => ProviderScope(
      overrides: [
        discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi(const [_open])),
        catalogApiProvider.overrideWithValue(_FakeCatalogApi(const [])),
        if (loggedIn) authControllerProvider.overrideWith(_LoggedInAuthController.new),
        myBookingsProvider('user-1').overrideWith((ref) async => bookings),
      ],
      child: MaterialApp.router(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
            GoRoute(path: '/bookings', builder: (_, _) => const Scaffold(body: Text('Bookings page'))),
          ],
        ),
      ),
    );

    testWidgets('shows the soonest upcoming visit under the search, and a tap opens Bookings', (tester) async {
      _useTallWindow(tester);
      await tester.pumpWidget(
        homeWith([booking('later', in_: const Duration(days: 4)), booking('soon', in_: const Duration(minutes: 90))]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your next booking'), findsOneWidget);
      expect(find.textContaining('Haircut ·'), findsOneWidget);
      expect(find.text('Studio One'), findsOneWidget);
      final search = tester.getTopLeft(find.text('What service are you looking for?')).dy;
      expect(tester.getTopLeft(find.text('Your next booking')).dy, greaterThan(search));

      await tester.tap(find.text('Your next booking'));
      await tester.pumpAndSettle();
      expect(find.text('Bookings page'), findsOneWidget);
    });

    testWidgets('a booking still awaiting payment says so', (tester) async {
      _useTallWindow(tester);
      await tester.pumpWidget(homeWith([booking('a', status: 'PENDING_PAYMENT', in_: const Duration(days: 1))]));
      await tester.pumpAndSettle();

      expect(find.text('Studio One · Awaiting payment'), findsOneWidget);
    });

    testWidgets('absent for a guest', (tester) async {
      _useTallWindow(tester);
      await tester.pumpWidget(homeWith([booking('a', in_: const Duration(days: 1))], loggedIn: false));
      await tester.pumpAndSettle();

      expect(find.text('Your next booking'), findsNothing);
    });

    testWidgets('absent when nothing is coming up: only a past and an undated booking', (tester) async {
      _useTallWindow(tester);
      await tester.pumpWidget(homeWith([booking('past', in_: const Duration(days: -1)), booking('undated')]));
      await tester.pumpAndSettle();

      expect(find.text('Your next booking'), findsNothing);
    });

    testWidgets('fits a 320 px phone with a large font in the dark theme, a long service and business name', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi(const [_open])),
            catalogApiProvider.overrideWithValue(_FakeCatalogApi(const [])),
            authControllerProvider.overrideWith(_LoggedInAuthController.new),
            myBookingsProvider('user-1').overrideWith(
              (ref) async => [booking('a', in_: const Duration(days: 2), provider: 'A Very Long Beauty Studio And Spa Name')],
            ),
          ],
          child: MaterialApp(
            theme: factoryDarkTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Your next booking'), findsOneWidget);
    });
  });

  testWidgets('"Popular services" prefers what the server says was booked most, over what the feed offers', (tester) async {
    _useTallWindow(tester);
    final feed = ProviderSearchResult(
      id: 'p1', name: 'Studio', vertical: 'beauty', status: 'ACTIVE', hasOpenAvailability: true, minPrice: 4000,
      services: [ServiceSummary(id: 's', title: 'Feed Only Service', durationMinutes: 30, price: 4000, currency: 'KZT')],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi([feed], popular: const [
          PopularService(title: 'Most Booked Service', minPrice: 2500, currency: 'KZT', providerCount: 4, bookings: 120),
        ])),
        catalogApiProvider.overrideWithValue(_FakeCatalogApi(const [])),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Most Booked Service'), findsOneWidget);
    expect(find.text('4 businesses'), findsOneWidget);
    expect(find.text('Feed Only Service'), findsNothing);
  });

  testWidgets('"Popular services" falls back to the feed when the server list fails', (tester) async {
    _useTallWindow(tester);
    final feed = ProviderSearchResult(
      id: 'p1', name: 'Studio', vertical: 'beauty', status: 'ACTIVE', hasOpenAvailability: true, minPrice: 4000,
      services: [ServiceSummary(id: 's', title: 'Feed Only Service', durationMinutes: 30, price: 4000, currency: 'KZT')],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi([feed])..popularFails = true),
        catalogApiProvider.overrideWithValue(_FakeCatalogApi(const [])),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Popular services'), findsOneWidget);
    expect(find.text('Feed Only Service'), findsOneWidget);
  });

  testWidgets('there is no "Popular services" block while no business lists a service', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(routedHome());
    await tester.pumpAndSettle();

    expect(find.text('Popular services'), findsNothing);
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
    // The rest is the second page: built, but beyond the right edge of the screen.
    expect(_isOnScreen(tester, find.text('Category 9')), isFalse);
    expect(_isOnScreen(tester, find.text('Category 10')), isFalse);

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
        nextFreeAt: DateTime.now().add(const Duration(days: 1)),
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
    expect(find.textContaining('Last visit:'), findsOneWidget);
    expect(find.textContaining('Next free:'), findsOneWidget);
  });

  testWidgets('tapping a Book Again card opens the provider at the booking steps with the same service', (tester) async {
    _useTallWindow(tester);
    final api = _FakeBookingApiWithSuggestions([
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
          discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi(const [])),
          bookingApiProvider.overrideWithValue(api),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp.router(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
              GoRoute(
                path: '/provider/:id',
                builder: (_, state) => Scaffold(body: Text('Provider ${state.uri}')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aigerim Beauty Studio'));
    await tester.pumpAndSettle();

    expect(find.text('Provider /provider/p1?book=1&service=s1'), findsOneWidget);
  });

  testWidgets('the Book Again card fits a 320 px phone with a large font in the dark theme', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fakeBookingApi = _FakeBookingApiWithSuggestions([
      BookAgainSuggestion(
        providerId: 'p1',
        providerName: 'Aigerim Beauty Studio With A Very Long Name',
        vertical: 'beauty',
        serviceId: 's1',
        serviceTitle: 'Haircut and styling with a long title',
        durationMinutes: 30,
        price: 25.0,
        currency: 'USD',
        lastVisitAt: DateTime.now().subtract(const Duration(days: 14)),
        nextFreeAt: DateTime.now().add(const Duration(days: 1)),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi(const [])),
          bookingApiProvider.overrideWithValue(fakeBookingApi),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryDarkTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Book again'), 200, scrollable: find.byType(Scrollable).first);

    expect(find.textContaining('Last visit:'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  Widget mastersApp(List<TopWorker> workers) => ProviderScope(
    overrides: [
      discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi([_open])),
      catalogApiProvider.overrideWithValue(_FakeCatalogApi(const [])),
      workersApiProvider.overrideWithValue(_FakeWorkersApi(workers)),
    ],
    child: MaterialApp.router(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/worker/:id',
            builder: (_, state) => Scaffold(body: Text('Worker page ${state.pathParameters['id']}')),
          ),
        ],
      ),
    ),
  );

  testWidgets('the best masters rail shows avatars with names and ratings, and a tap opens the master page', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(mastersApp(const [_aigerim]));
    await tester.pumpAndSettle();

    expect(find.text('Best masters'), findsOneWidget);
    expect(find.byType(FactoryAvatar), findsWidgets);
    expect(find.text('Aigerim K.'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('(17)'), findsOneWidget);

    await tester.tap(find.text('Aigerim K.'));
    await tester.pumpAndSettle();

    expect(find.text('Worker page w1'), findsOneWidget);
  });

  Widget myMastersApp(List<FavoriteWorker> favorites, {bool loggedIn = true}) => ProviderScope(
    overrides: [
      discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi([_open])),
      catalogApiProvider.overrideWithValue(_FakeCatalogApi(const [])),
      workersApiProvider.overrideWithValue(_FakeWorkersApi(const [], favorites: favorites)),
      bookingApiProvider.overrideWithValue(_FakeBookingApiWithSuggestions(const [])),
      if (loggedIn) authControllerProvider.overrideWith(_LoggedInAuthController.new),
    ],
    child: MaterialApp.router(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/worker/:id',
            builder: (_, state) => Scaffold(body: Text('Worker page ${state.pathParameters['id']}')),
          ),
        ],
      ),
    ),
  );

  FavoriteWorker favorite({DateTime? nextFreeAt}) => FavoriteWorker(
    id: 'w9',
    kind: 'MASTER',
    providerId: 'p1',
    providerName: 'Studio',
    displayName: 'Dana M.',
    photoUrl: null,
    averageRating: 4.9,
    reviewCount: 5,
    nextFreeAt: nextFreeAt,
  );

  testWidgets('a logged-in customer sees My masters with when each is free, and a tap opens the master', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(myMastersApp([favorite(nextFreeAt: DateTime.now().add(const Duration(days: 1)))]));
    await tester.pumpAndSettle();

    expect(find.text('My masters'), findsOneWidget);
    expect(find.text('Dana M.'), findsOneWidget);
    await tester.tap(find.text('Dana M.'));
    await tester.pumpAndSettle();
    expect(find.text('Worker page w9'), findsOneWidget);
  });

  testWidgets('My masters is absent without favourites', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(myMastersApp(const []));
    await tester.pumpAndSettle();
    expect(find.text('My masters'), findsNothing);
  });

  testWidgets('My masters is absent for a guest', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(myMastersApp([favorite()], loggedIn: false));
    await tester.pumpAndSettle();
    expect(find.text('My masters'), findsNothing);
  });

  testWidgets('Home fits a 320 px phone with a large font in the dark theme: categories, masters, providers', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryApiProvider.overrideWithValue(_FakeDiscoveryApi([_open, _closed])),
          catalogApiProvider.overrideWithValue(_FakeCatalogApi(manyCategories(10))),
          workersApiProvider.overrideWithValue(_FakeWorkersApi(const [_aigerim])),
        ],
        child: MaterialApp(
          theme: factoryDarkTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Walk down the page so every section is built at this size.
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('no best masters rail while nobody has enough reviews yet', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(mastersApp(const []));
    await tester.pumpAndSettle();

    expect(find.text('Best masters'), findsNothing);
  });
}
