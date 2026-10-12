import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zairo/features/catalog/data/catalog_api.dart';
import 'package:zairo/features/catalog/data/models/business_type.dart';
import 'package:zairo/features/catalog/data/models/catalog_service.dart';
import 'package:zairo/features/catalog/data/models/category.dart';
import 'package:zairo/features/catalog/data/models/subsphere.dart';
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

  @override
  Future<List<Subsphere>> listSubspheres(String businessTypeId) async => subspheres;

  @override
  Future<List<CatalogService>> listCatalogServices(String businessTypeId) async => services;

  List<Subsphere> subspheres = const [];

  List<CatalogService> services = const [
    CatalogService(
      id: 'svc-1',
      businessTypeId: 'bt-1',
      nameKk: 'Шаш алу',
      nameRu: 'Мужская стрижка',
      nameEn: "Men's haircut",
      sortOrder: 1,
    ),
  ];
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

  testWidgets('a sphere offers its catalog services, and picking one opens the price comparison', (
    tester,
  ) async {
    final fakeApi = _FakeCatalogApi(const [_beauty], const {
      'cat-beauty': [_haircuts],
    });
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const AllCategoriesScreen()),
        GoRoute(
          path: '/compare/:catalogServiceId',
          builder: (_, state) => Scaffold(
            body: Text('compare ${state.pathParameters['catalogServiceId']} ${state.uri.queryParameters['name']}'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp.router(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Beauty'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Compare prices for services in this sphere'));
    await tester.pumpAndSettle();

    expect(find.text("Men's haircut"), findsOneWidget);
    await tester.tap(find.text("Men's haircut"));
    await tester.pumpAndSettle();

    expect(find.text("compare svc-1 Men's haircut"), findsOneWidget);
  });

  testWidgets('a sphere with subspheres groups its catalog services under titled headers', (tester) async {
    CatalogService service(String id, String nameEn, int sortOrder, [String? subsphereId]) => CatalogService(
      id: id,
      businessTypeId: 'bt-1',
      nameKk: nameEn,
      nameRu: nameEn,
      nameEn: nameEn,
      sortOrder: sortOrder,
      subsphereId: subsphereId,
    );
    Subsphere subsphere(String id, String nameEn, int sortOrder) => Subsphere(
      id: id,
      businessTypeId: 'bt-1',
      code: id,
      nameKk: nameEn,
      nameRu: nameEn,
      nameEn: nameEn,
      sortOrder: sortOrder,
    );
    final fakeApi = _FakeCatalogApi(const [_beauty], const {
      'cat-beauty': [_haircuts],
    })
      ..subspheres = [subsphere('ss-nails', 'Nails', 2), subsphere('ss-hair', 'Hair', 1)]
      ..services = [
        service('svc-manicure', 'Manicure', 3, 'ss-nails'),
        service('svc-mens', "Men's haircut", 8, 'ss-hair'),
        service('svc-womens', "Women's haircut", 1, 'ss-hair'),
        service('svc-misc', 'Walk-in consultation', 20),
      ];
    await _pump(tester, fakeApi);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Beauty'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Compare prices for services in this sphere'));
    await tester.pumpAndSettle();

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text('Hair'), findsOneWidget);
    expect(find.text('Nails'), findsOneWidget);
    expect(top('Walk-in consultation'), lessThan(top('Hair')));
    expect(top('Hair'), lessThan(top("Women's haircut")));
    expect(top("Women's haircut"), lessThan(top("Men's haircut")));
    expect(top("Men's haircut"), lessThan(top('Nails')));
    expect(top('Nails'), lessThan(top('Manicure')));
  });
}
