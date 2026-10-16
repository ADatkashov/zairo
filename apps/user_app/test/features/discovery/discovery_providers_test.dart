import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/city/data/models/city.dart';
import 'package:zairo/features/city/presentation/providers/city_providers.dart';
import 'package:zairo/features/discovery/data/discovery_api.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:zairo/features/maps/presentation/providers/maps_providers.dart';

class _FakeDiscoveryApi extends DiscoveryApi {
  _FakeDiscoveryApi() : super(DioClient(Dio()));

  String? lastCity;
  int calls = 0;

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
    calls++;
    lastCity = cityCode;
    return const [];
  }
}

final _almaty = City(
  code: 'almaty',
  name: 'Almaty',
  countryCode: 'KZ',
  timezone: 'Asia/Almaty',
  currency: 'KZT',
  active: true,
);

ProviderContainer _container(_FakeDiscoveryApi api, {City? city, bool cityFails = false}) {
  final container = ProviderContainer(
    // No automatic retry of the deliberately failing city lookup.
    retry: (_, _) => null,
    overrides: [
      discoveryApiProvider.overrideWithValue(api),
      currentLocationProvider.overrideWith((ref) async => throw Exception('no location')),
      userCurrentCityProvider.overrideWith((ref) async {
        if (cityFails) throw Exception('no city');
        return city;
      }),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('searches within the user\'s city', () async {
    final api = _FakeDiscoveryApi();
    final container = _container(api, city: _almaty);

    await container.read(searchResultsProvider(const DiscoveryQuery()).future);

    expect(api.lastCity, 'almaty');
  });

  test('without a city it still searches, everywhere', () async {
    final api = _FakeDiscoveryApi();
    final container = _container(api);

    await container.read(searchResultsProvider(const DiscoveryQuery()).future);

    expect(api.lastCity, isNull);
  });

  test('a failing city lookup still searches, everywhere', () async {
    final api = _FakeDiscoveryApi();
    final container = _container(api, cityFails: true);

    await container.read(searchResultsProvider(const DiscoveryQuery()).future);

    expect(api.calls, 1);
    expect(api.lastCity, isNull);
  });
}
