import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/discovery/data/discovery_api.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:zairo/features/discovery/presentation/screens/service_compare_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeDiscoveryApi extends DiscoveryApi {
  _FakeDiscoveryApi(this._results) : super(DioClient(Dio()));

  final List<ProviderSearchResult> _results;
  String? lastCatalogServiceId;

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
    lastCatalogServiceId = catalogServiceId;
    return _results;
  }
}

const _studioA = ProviderSearchResult(
  id: 'p1',
  name: 'Studio A',
  vertical: 'beauty',
  status: 'ACTIVE',
  hasOpenAvailability: true,
  minPrice: 7000,
  services: [],
);

void main() {
  testWidgets('lists providers filtered by catalogServiceId', (tester) async {
    final fakeApi = _FakeDiscoveryApi([_studioA]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ServiceCompareScreen(catalogServiceId: 'cat-service-1', serviceName: 'Manicure'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manicure'), findsOneWidget);
    expect(find.text('Studio A'), findsOneWidget);
    expect(fakeApi.lastCatalogServiceId, 'cat-service-1');
  });

  testWidgets('shows an empty state when nobody offers the service', (tester) async {
    final fakeApi = _FakeDiscoveryApi(const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ServiceCompareScreen(catalogServiceId: 'cat-service-2', serviceName: 'Massage'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No businesses yet'), findsOneWidget);
  });
}
