import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/discovery/data/discovery_api.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/data/models/service_summary.dart';
import 'package:zairo/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:zairo/features/discovery/presentation/screens/search_screen.dart';
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
    double? minPrice,
    double? maxPrice,
    double? maxDistanceKm,
    bool availableOnly = false,
    String? sort,
  }) async {
    return _results;
  }
}

class _RecordingDiscoveryApi extends DiscoveryApi {
  _RecordingDiscoveryApi() : super(DioClient(Dio()));

  String? lastSort;
  bool? lastAvailableOnly;

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
    lastSort = sort;
    lastAvailableOnly = availableOnly;
    return const [];
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
          ServiceSummary(id: 's1', title: 'Haircut', durationMinutes: 30, price: 30, currency: 'USD'),
        ],
        distanceKm: 3.7,
        latitude: 43.24,
        longitude: 76.9,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchScreen(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Hair Studio'), findsOneWidget);
    expect(find.text('Available today'), findsOneWidget);
    expect(find.text('3.7 km · beauty'), findsOneWidget);
    expect(find.text('30 ₸'), findsOneWidget);
  });

  testWidgets('shows a prompt before the first search', (tester) async {
    final fakeApi = _FakeDiscoveryApi(const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Search for a service'), findsOneWidget);
  });

  testWidgets('shows a "no results" state that names the query', (tester) async {
    final fakeApi = _FakeDiscoveryApi(const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'massage');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('No results for "massage"'), findsOneWidget);
  });

  testWidgets('opening filters, picking a sort and available-only re-runs the search with them', (tester) async {
    final fakeApi = _RecordingDiscoveryApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fakeApi.lastSort, 'RECOMMENDED');
    expect(fakeApi.lastAvailableOnly, false);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Price: low to high'));
    await tester.tap(find.text('Available today only'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastSort, 'PRICE_ASC');
    expect(fakeApi.lastAvailableOnly, true);
  });
}
