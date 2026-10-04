import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/app/router/app_routes.dart';
import 'package:zairo/app/router/route_screens.dart';
import 'package:zairo/features/discovery/data/discovery_api.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:zairo/l10n/app_localizations.dart';

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
  }) async => const [];
}

void main() {
  test('AppRoutes builds the URLs the router declares', () {
    expect(AppRoutes.provider('p-1'), '/provider/p-1');
    expect(AppRoutes.chat('p-1'), '/messages/p-1');
    expect(
      AppRoutes.chat('p-1', providerName: 'Glow & Co'),
      '/messages/p-1?name=Glow+%26+Co',
    );
    expect(AppRoutes.loyalty('p-1', providerName: 'Glow'), '/loyalty/p-1?name=Glow');
    expect(AppRoutes.securitySettings, startsWith('${AppRoutes.settings}/'));
  });

  testWidgets(
    'a provider link without extra shows "not found" for an unknown id',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryApiProvider.overrideWithValue(_EmptyDiscoveryApi()),
          ],
          child: MaterialApp(
            theme: factoryLightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ProviderDetailRoute(providerId: 'missing'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Business not found'), findsOneWidget);
    },
  );
}
