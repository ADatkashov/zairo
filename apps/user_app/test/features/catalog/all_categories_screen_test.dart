import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/catalog/data/catalog_api.dart';
import 'package:zairo/features/catalog/data/models/business_type.dart';
import 'package:zairo/features/catalog/data/models/category.dart';
import 'package:zairo/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zairo/features/catalog/presentation/screens/all_categories_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeCatalogApi extends CatalogApi {
  _FakeCatalogApi(this._categories, this._businessTypes) : super(DioClient(Dio()));

  final List<Category> _categories;
  final Map<String, List<BusinessType>> _businessTypes;
  final List<String> requestedBusinessTypesFor = [];

  @override
  Future<List<Category>> listCategories() async => _categories;

  @override
  Future<List<BusinessType>> listBusinessTypes(String categoryId) async {
    requestedBusinessTypesFor.add(categoryId);
    return _businessTypes[categoryId] ?? const [];
  }
}

const _beauty = Category(
  id: 'cat-beauty',
  code: 'beauty',
  nameKk: 'Сұлулық',
  nameRu: 'Красота',
  nameEn: 'Beauty',
  icon: '💇',
  sortOrder: 1,
  status: 'ACTIVE',
);
const _auto = Category(
  id: 'cat-auto',
  code: 'auto',
  nameKk: 'Авто',
  nameRu: 'Авто',
  nameEn: 'Auto',
  icon: '🚗',
  sortOrder: 2,
  status: 'ACTIVE',
);
const _haircuts = BusinessType(
  id: 'bt-1',
  categoryId: 'cat-beauty',
  code: 'haircuts',
  nameKk: 'Шаш тарау',
  nameRu: 'Стрижки',
  nameEn: 'Haircuts',
  sortOrder: 1,
  status: 'ACTIVE',
);

Future<void> _pump(WidgetTester tester, CatalogApi catalogApi) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [catalogApiProvider.overrideWithValue(catalogApi)],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AllCategoriesScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('lists every category from the catalog API', (tester) async {
    final fakeApi = _FakeCatalogApi(const [_beauty, _auto], const {});

    await _pump(tester, fakeApi);
    await tester.pumpAndSettle();

    expect(find.text('Beauty'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
  });

  testWidgets("a category's spheres aren't fetched until it's expanded", (tester) async {
    final fakeApi = _FakeCatalogApi(const [_beauty], {
      'cat-beauty': [_haircuts],
    });

    await _pump(tester, fakeApi);
    await tester.pumpAndSettle();

    expect(fakeApi.requestedBusinessTypesFor, isEmpty);
    expect(find.text('Haircuts'), findsNothing);

    await tester.tap(find.text('Beauty'));
    await tester.pumpAndSettle();

    expect(fakeApi.requestedBusinessTypesFor, ['cat-beauty']);
    expect(find.text('Haircuts'), findsOneWidget);
  });

  testWidgets('typing in the search field filters the category list', (tester) async {
    final fakeApi = _FakeCatalogApi(const [_beauty, _auto], const {});

    await _pump(tester, fakeApi);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bea');
    await tester.pumpAndSettle();

    expect(find.text('Beauty'), findsOneWidget);
    expect(find.text('Auto'), findsNothing);
  });

  testWidgets('shows an empty state when the search filter matches nothing', (tester) async {
    final fakeApi = _FakeCatalogApi(const [_beauty, _auto], const {});

    await _pump(tester, fakeApi);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('Beauty'), findsNothing);
    expect(find.text('Auto'), findsNothing);
    expect(find.text('No matching categories'), findsOneWidget);
  });

  testWidgets('picking a sphere pops the screen with its parent category\'s code', (tester) async {
    final fakeApi = _FakeCatalogApi(const [_beauty], {
      'cat-beauty': [_haircuts],
    });
    String? popped;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const AllCategoriesScreen()),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beauty'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haircuts'));
    await tester.pumpAndSettle();

    expect(popped, 'beauty');
  });

  testWidgets('picking "All services" under a category pops with that category\'s code too', (tester) async {
    final fakeApi = _FakeCatalogApi(const [_beauty], {
      'cat-beauty': [_haircuts],
    });
    String? popped;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const AllCategoriesScreen()),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beauty'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All services'));
    await tester.pumpAndSettle();

    expect(popped, 'beauty');
  });
}
