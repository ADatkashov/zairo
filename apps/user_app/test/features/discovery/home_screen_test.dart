import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/discovery/data/discovery_api.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:zairo/features/discovery/presentation/screens/home_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

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

const _open = ProviderSearchResult(
  id: 'p1',
  name: 'Aigerim Beauty Studio',
  vertical: 'beauty',
  status: 'ACTIVE',
  hasOpenAvailability: true,
  minPrice: 8000,
  services: [],
  distanceKm: 1.2,
);
const _closed = ProviderSearchResult(
  id: 'p2',
  name: 'Nail Bar 21',
  vertical: 'beauty',
  status: 'ACTIVE',
  hasOpenAvailability: false,
  minPrice: 6000,
  services: [],
  distanceKm: 0.6,
);

void main() {
  testWidgets('shows the curated "top rated" row and the location label', (tester) async {
    final fakeApi = _FakeDiscoveryApi([_open, _closed]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Almaty'), findsOneWidget);
    expect(find.text('What service are you looking for?'), findsOneWidget);
    expect(find.text('Top rated near you'), findsOneWidget);
    expect(find.text('Aigerim Beauty Studio'), findsOneWidget);
    expect(find.text('Nail Bar 21'), findsOneWidget);
  });

  testWidgets('shows the availability hero only when something is open today', (tester) async {
    final fakeApi = _FakeDiscoveryApi([_open, _closed]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('salon'), findsWidgets);
    expect(find.textContaining('open slots today'), findsOneWidget);
  });

  testWidgets('shows an empty state when there is nothing to discover yet', (tester) async {
    final fakeApi = _FakeDiscoveryApi(const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No providers yet'), findsOneWidget);
  });
}
