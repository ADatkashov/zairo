import 'package:business_admin/features/catalog/data/models/catalog_service.dart';
import 'package:business_admin/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:business_admin/features/salon/data/models/admin_service.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/features/salon/presentation/widgets/add_service_dialog.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSalonAdminApi extends SalonAdminApi {
  _FakeSalonAdminApi() : super(DioClient(Dio()));

  Map<String, dynamic>? created;
  Map<String, dynamic>? updated;
  Map<String, dynamic>? linked;

  @override
  Future<AdminService> createService({
    required String providerId,
    required String title,
    required int durationMinutes,
    required double price,
    required String currency,
    String? catalogServiceId,
  }) async {
    created = {
      'providerId': providerId,
      'title': title,
      'durationMinutes': durationMinutes,
      'price': price,
      'catalogServiceId': catalogServiceId,
    };
    return AdminService(
      id: 's-new',
      providerId: providerId,
      title: title,
      durationMinutes: durationMinutes,
      price: price,
      currency: currency,
      active: true,
      catalogServiceId: catalogServiceId,
    );
  }

  @override
  Future<AdminService> updateService({
    required String serviceId,
    required String title,
    required int durationMinutes,
    required double price,
    required String currency,
    String? catalogServiceId,
  }) async {
    updated = {'serviceId': serviceId, 'title': title, 'price': price, 'catalogServiceId': catalogServiceId};
    return AdminService(
      id: serviceId,
      providerId: 'p1',
      title: title,
      durationMinutes: durationMinutes,
      price: price,
      currency: currency,
      active: true,
      catalogServiceId: catalogServiceId,
    );
  }

  @override
  Future<AdminService> linkCatalogService({required String serviceId, required String? catalogServiceId}) async {
    linked = {'serviceId': serviceId, 'catalogServiceId': catalogServiceId};
    return AdminService(
      id: serviceId,
      providerId: 'p1',
      title: 'Manicure',
      durationMinutes: 30,
      price: 25,
      currency: 'KZT',
      active: true,
      catalogServiceId: catalogServiceId,
    );
  }
}

const _manicure = CatalogServiceModel(
  id: 'cs-1',
  businessTypeId: 'bt-1',
  subsphereId: null,
  nameKk: 'Маникюр',
  nameRu: 'Маникюр',
  nameEn: 'Manicure',
  sortOrder: 1,
  status: 'ACTIVE',
);

Widget _app(_FakeSalonAdminApi api, {String? businessTypeId, AdminService? existing}) {
  return ProviderScope(
    overrides: [
      salonAdminApiProvider.overrideWithValue(api),
      catalogServicesProvider('bt-1').overrideWith((ref) async => [_manicure]),
      subspheresProvider('bt-1').overrideWith((ref) async => []),
    ],
    child: MaterialApp(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AddServiceDialog(providerId: 'p1', businessTypeId: businessTypeId, existing: existing)),
    ),
  );
}

void main() {
  testWidgets('with a business type the service is picked from the catalog, not typed', (tester) async {
    final api = _FakeSalonAdminApi();
    await tester.pumpWidget(_app(api, businessTypeId: 'bt-1'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Title'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manicure').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Price (₸)'), '25');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // The catalog service travels with the create call itself — the backend
    // refuses a service that isn't one — so there is no separate link step.
    expect(api.created, {
      'providerId': 'p1',
      'title': 'Manicure',
      'durationMinutes': 30,
      'price': 25.0,
      'catalogServiceId': 'cs-1',
    });
    expect(api.linked, isNull);
  });

  testWidgets('a new catalog-backed service cannot be saved without picking one', (tester) async {
    final api = _FakeSalonAdminApi();
    await tester.pumpWidget(_app(api, businessTypeId: 'bt-1'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Price (₸)'), '25');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(api.created, isNull);
    expect(find.textContaining('Pick a service from the list'), findsOneWidget);
  });

  testWidgets('an older free-text service can only be saved after picking a catalog entry', (tester) async {
    final api = _FakeSalonAdminApi();
    const legacy = AdminService(
      id: 's-old',
      providerId: 'p1',
      title: 'My own massage',
      durationMinutes: 30,
      price: 10,
      currency: 'KZT',
      active: true,
    );
    await tester.pumpWidget(_app(api, businessTypeId: 'bt-1', existing: legacy));
    await tester.pumpAndSettle();

    // Saving it as it is would send the old, self-written title: not allowed.
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(api.updated, isNull);
    expect(find.textContaining('Pick a service from the list'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manicure').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(api.updated, {'serviceId': 's-old', 'title': 'Manicure', 'price': 10.0, 'catalogServiceId': 'cs-1'});
  });

  testWidgets('a business without a business type keeps the free-text title', (tester) async {
    await tester.pumpWidget(_app(_FakeSalonAdminApi()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
  });
}
