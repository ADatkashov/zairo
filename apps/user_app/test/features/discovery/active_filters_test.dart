import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/catalog/data/catalog_api.dart';
import 'package:zairo/features/catalog/data/models/category.dart';
import 'package:zairo/features/catalog/presentation/providers/catalog_providers.dart'
    show catalogApiProvider;
import 'package:zairo/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:zairo/features/discovery/presentation/widgets/active_filters.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeCatalogApi extends CatalogApi {
  _FakeCatalogApi() : super(DioClient(Dio()));

  @override
  Future<List<Category>> listCategories() async => const [
    Category(
      id: 'c',
      code: 'beauty',
      nameKk: 'Сұлулық',
      nameRu: 'Красота',
      nameEn: 'Beauty',
      icon: null,
      sortOrder: 1,
      status: 'ACTIVE',
    ),
  ];
}

Future<void> _pump(
  WidgetTester tester,
  DiscoveryQuery query,
  ValueChanged<DiscoveryQuery> onChanged,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [catalogApiProvider.overrideWithValue(_FakeCatalogApi())],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ActiveFilters(
            query: query,
            currency: 'KZT',
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'every active filter is a chip that says what it is and removes only itself',
    (tester) async {
      // Wide enough that the sideways list builds all five chips.
    tester.view.physicalSize = const Size(2400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    DiscoveryQuery? changed;
      const all = DiscoveryQuery(
        vertical: 'beauty',
        minPrice: 2000,
        maxPrice: 9000,
        maxDistanceKm: 5,
        minRating: 4,
        availableOnly: true,
      );
      await _pump(tester, all, (q) => changed = q);

      expect(find.text('Beauty'), findsOneWidget);
      expect(find.textContaining('Within 5 km'), findsOneWidget);
      expect(find.textContaining('4.0 stars and up'), findsOneWidget);
      expect(find.text('Available today only'), findsOneWidget);
      expect(find.textContaining(' – '), findsOneWidget);

      await tester.tap(find.text('Beauty'));
      expect(changed!.vertical, isNull);
      expect(changed!.minPrice, 2000);

      await tester.tap(find.text('Available today only'));
      expect(changed!.availableOnly, isFalse);
      expect(changed!.vertical, 'beauty');

      await tester.tap(find.textContaining('Within 5 km'));
      expect(changed!.maxDistanceKm, isNull);

      await tester.tap(find.textContaining('4.0 stars'));
      expect(changed!.minRating, isNull);

      await tester.tap(find.textContaining(' – '));
      expect(changed!.minPrice, isNull);
      expect(changed!.maxPrice, isNull);
    },
  );

  testWidgets('one-sided prices read "From" and "Up to"', (tester) async {
    await _pump(tester, const DiscoveryQuery(minPrice: 3000), (_) {});
    expect(find.textContaining('From '), findsOneWidget);
    await _pump(tester, const DiscoveryQuery(maxPrice: 7000), (_) {});
    expect(find.textContaining('Up to '), findsOneWidget);
  });

  testWidgets(
    'an unknown category falls back to its code, and the chip is announced as removable',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const DiscoveryQuery(vertical: 'auto'), (_) {});
      expect(find.text('auto'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove filter: auto'), findsOneWidget);
      handle.dispose();
    },
  );
}
