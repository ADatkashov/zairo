import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/app/app.dart';
import 'package:zairo/app/router/app_router.dart';
import 'package:zairo/app/router/app_routes.dart';
import 'package:zairo/core/constants/environment.dart';
import 'package:zairo/features/ads/presentation/screens/ad_video_screen.dart';
import 'package:zairo/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zairo/features/discovery/data/discovery_api.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:zairo/features/discovery/presentation/screens/search_screen.dart';

class _EmptyDiscoveryApi extends DiscoveryApi {
  _EmptyDiscoveryApi() : super(DioClient(Dio()));

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
  }) async => const [];
}

void main() {
  testWidgets(
    'detail routes open above the tab shell and back returns to the tab',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkConfigProvider.overrideWithValue(appNetworkConfig),
            discoveryApiProvider.overrideWithValue(_EmptyDiscoveryApi()),
            categoriesProvider.overrideWith((ref) async => const []),
          ],
          child: const ZairoApp(),
        ),
      );
      await tester.pumpAndSettle();
      final router = ProviderScope.containerOf(
        tester.element(find.byType(ZairoApp)),
      ).read(routerProvider);

      // Home's quick-action grid also says "Bookings"; the tab bar is the one
      // under test here.
      final tabBarBookings = find.descendant(
        of: find.byType(FactoryBottomNavigation),
        matching: find.text('Bookings'),
      );
      expect(find.text('Home'), findsWidgets);

      // A provider link with no `extra` (deep link / web refresh).
      router.push(AppRoutes.provider('missing'));
      await tester.pumpAndSettle();
      expect(find.text('Business not found'), findsOneWidget);
      // Full-screen: the tab bar is not drawn over it.
      expect(tabBarBookings, findsNothing);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Business not found'), findsNothing);
      expect(tabBarBookings, findsOneWidget);
    },
  );

  testWidgets('the ad video route falls back to Home without a video to play', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkConfigProvider.overrideWithValue(appNetworkConfig),
          discoveryApiProvider.overrideWithValue(_EmptyDiscoveryApi()),
          categoriesProvider.overrideWith((ref) async => const []),
        ],
        child: const ZairoApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = ProviderScope.containerOf(
      tester.element(find.byType(ZairoApp)),
    ).read(routerProvider);

    router.go(AppRoutes.adVideo);
    await tester.pumpAndSettle();

    expect(find.byType(AdVideoScreen), findsNothing);
    expect(find.text('Home'), findsWidgets);
  });

  Widget app() => ProviderScope(
    overrides: [
      networkConfigProvider.overrideWithValue(appNetworkConfig),
      discoveryApiProvider.overrideWithValue(_EmptyDiscoveryApi()),
      categoriesProvider.overrideWith((ref) async => const []),
    ],
    child: const ZairoApp(),
  );

  testWidgets('the bar is Home, Find a service in the middle, Bookings, Profile: no Search tab', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    Finder inBar(String text) => find.descendant(of: find.byType(FactoryBottomNavigation), matching: find.text(text));
    expect(inBar('Home'), findsOneWidget);
    expect(inBar('Bookings'), findsOneWidget);
    expect(inBar('Profile'), findsOneWidget);
    expect(inBar('Find a service'), findsOneWidget);
    expect(inBar('Search'), findsNothing);

    // Home, then the action, then Bookings and Profile, left to right; the action is centred.
    final home = tester.getCenter(inBar('Home')).dx;
    final find_ = tester.getCenter(inBar('Find a service')).dx;
    expect(home, lessThan(find_));
    expect(find_, lessThan(tester.getCenter(inBar('Bookings')).dx));
    expect(tester.getCenter(inBar('Bookings')).dx, lessThan(tester.getCenter(inBar('Profile')).dx));
    expect(find_, closeTo(195, 1));
  });

  testWidgets('"Find a service" opens Search with the keyboard up in one tap, full screen, and back returns Home', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final label = find.descendant(of: find.byType(FactoryBottomNavigation), matching: find.text('Find a service'));
    await tester.tap(label);
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
    // Full screen: the tab bar is not drawn over Search.
    expect(find.byType(FactoryBottomNavigation), findsNothing);
    // Ready to type: the field has focus.
    final field = tester.widget<EditableText>(find.descendant(of: find.byType(SearchScreen), matching: find.byType(EditableText)));
    expect(field.focusNode.hasFocus, isTrue);

    // Back is where the person started.
    ProviderScope.containerOf(tester.element(find.byType(ZairoApp))).read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);
    expect(label, findsOneWidget);
  });

  testWidgets('Search opened from a category link does not grab the keyboard', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(ZairoApp))).read(routerProvider).push(AppRoutes.search(category: 'beauty'));
    await tester.pumpAndSettle();

    final field = tester.widget<EditableText>(find.descendant(of: find.byType(SearchScreen), matching: find.byType(EditableText)));
    expect(field.focusNode.hasFocus, isFalse);
  });
}
