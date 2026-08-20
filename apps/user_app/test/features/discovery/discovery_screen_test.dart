import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/discovery/data/discovery_api.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/data/models/service_summary.dart';
import 'package:zairo/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:zairo/features/discovery/presentation/screens/discovery_screen.dart';

class _FakeDiscoveryApi extends DiscoveryApi {
  _FakeDiscoveryApi(this._results) : super(DioClient(Dio()));

  final List<ProviderSearchResult> _results;

  @override
  Future<List<ProviderSearchResult>> searchProviders({
    String? vertical,
    String? query,
    double? lat,
    double? lng,
  }) async {
    return _results;
  }
}

void main() {
  testWidgets('shows provider results once loaded', (tester) async {
    final fakeApi = _FakeDiscoveryApi([
      const ProviderSearchResult(
        id: 'p1',
        name: 'Hair Studio',
        vertical: 'beauty',
        status: 'ACTIVE',
        hasOpenAvailability: true,
        minPrice: 30,
        services: [
          ServiceSummary(
            id: 's1',
            title: 'Haircut',
            durationMinutes: 30,
            price: 30,
            currency: 'USD',
          ),
        ],
        distanceKm: 3.7,
        latitude: 43.24,
        longitude: 76.9,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: const MaterialApp(home: DiscoveryScreen()),
      ),
    );

    // First frame shows the loading state; let the FutureProvider resolve.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Hair Studio'), findsOneWidget);
    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('From 30.00'), findsOneWidget);
    expect(find.text('3.7 km away'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no results', (tester) async {
    final fakeApi = _FakeDiscoveryApi(const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: const MaterialApp(home: DiscoveryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No providers found'), findsOneWidget);
  });
}
