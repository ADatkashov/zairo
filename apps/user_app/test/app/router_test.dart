import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
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
import 'package:zairo/features/discovery/presentation/widgets/active_filters.dart';

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

  testWidgets('the bar is Home, Search, a round "+" in the middle, Bookings, Profile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    Finder inBar(String text) => find.descendant(of: find.byType(FactoryBottomNavigation), matching: find.text(text));
    for (final label in ['Home', 'Search', 'Bookings', 'Profile']) {
      expect(inBar(label), findsOneWidget, reason: label);
    }
    // The "+" is only an icon in the bar; screen readers get its name.
    expect(find.descendant(of: find.byType(FactoryBottomNavigation), matching: find.byIcon(Symbols.add_rounded)), findsOneWidget);
    expect(find.bySemanticsLabel('Quick actions'), findsOneWidget);

    final x = [for (final l in ['Home', 'Search', 'Bookings', 'Profile']) tester.getCenter(inBar(l)).dx];
    expect(x, orderedEquals([...x]..sort()), reason: 'left to right');
    final plus = tester.getCenter(find.byIcon(Symbols.add_rounded)).dx;
    expect(plus, closeTo(195, 1));
    expect(x[1], lessThan(plus));
    expect(x[2], greaterThan(plus));
    semantics.dispose();
  });

  testWidgets('the "+" fans out three quick actions and turns into a "×"; "Find a service" lands on the Search tab with the keyboard up', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Symbols.add_rounded));
    await tester.pumpAndSettle();
    // The three, each labelled under its round button. No history and no login: Near me, not "Book again".
    for (final row in ['Find a service', 'Free today', 'Near me']) {
      expect(find.text(row), findsOneWidget, reason: row);
    }
    expect(find.text('Book again'), findsNothing);

    await tester.tap(find.text('Find a service'));
    await tester.pumpAndSettle();

    expect(find.text('Free today'), findsNothing, reason: 'the fan closed');
    expect(find.byType(SearchScreen), findsOneWidget);
    // Search is a tab: the bar stays.
    expect(find.byType(FactoryBottomNavigation), findsOneWidget);
    final field = tester.widget<EditableText>(find.descendant(of: find.byType(SearchScreen), matching: find.byType(EditableText)));
    expect(field.focusNode.hasFocus, isTrue);
  });

  testWidgets('"Find a service" raises the keyboard again when Search is already showing', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    EditableText field() =>
        tester.widget<EditableText>(find.descendant(of: find.byType(SearchScreen), matching: find.byType(EditableText)));

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byIcon(Symbols.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find a service'));
      await tester.pumpAndSettle();
      expect(field().focusNode.hasFocus, isTrue, reason: 'round ${i + 1}');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('"Free today" opens Search already narrowed to it, and plain Search clears it again', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Symbols.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free today'));
    await tester.pumpAndSettle();
    expect(find.byType(ActiveFilters), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find a service'));
    await tester.pumpAndSettle();
    expect(find.byType(ActiveFilters), findsNothing, reason: 'each way in sets the filters afresh');
  });

  testWidgets('a category link opens the Search tab without grabbing the keyboard', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(ZairoApp))).read(routerProvider).go(AppRoutes.search(category: 'beauty'));
    await tester.pumpAndSettle();

    final field = tester.widget<EditableText>(find.descendant(of: find.byType(SearchScreen), matching: find.byType(EditableText)));
    expect(field.focusNode.hasFocus, isFalse);
  });
}
