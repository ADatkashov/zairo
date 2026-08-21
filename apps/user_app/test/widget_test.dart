import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zairo/app/app.dart';
import 'package:zairo/core/constants/environment.dart';
import 'package:zairo/features/discovery/data/discovery_api.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/presentation/providers/discovery_providers.dart';

class _EmptyDiscoveryApi extends DiscoveryApi {
  _EmptyDiscoveryApi() : super(DioClient(Dio()));

  @override
  Future<List<ProviderSearchResult>> searchProviders({
    String? vertical,
    String? query,
    double? lat,
    double? lng,
    double? minPrice,
    double? maxPrice,
    double? maxDistanceKm,
    bool availableOnly = false,
    String? sort,
  }) async {
    return [];
  }
}

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Home tab renders HomeScreen, which needs networkConfigProvider
    // (as main.dart overrides it) plus a fake API so the smoke test doesn't
    // depend on a live backend.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkConfigProvider.overrideWithValue(appNetworkConfig),
          discoveryApiProvider.overrideWithValue(_EmptyDiscoveryApi()),
        ],
        child: const ZairoApp(),
      ),
    );
    await tester.pumpAndSettle();
  });
}
