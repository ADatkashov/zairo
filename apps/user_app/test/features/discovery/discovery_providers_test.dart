import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/city/data/models/city.dart';
import 'package:zairo/features/city/presentation/providers/city_providers.dart';
import 'package:zairo/features/discovery/data/discovery_api.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/data/models/service_summary.dart';
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

  group('PriceBounds.fromResults', () {
    ProviderSearchResult provider(double? price, {String currency = 'KZT'}) => ProviderSearchResult(
      id: 'p$price',
      name: 'P',
      vertical: 'beauty',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      minPrice: price,
      services: price == null
          ? const []
          : [ServiceSummary(id: 's', title: 'S', durationMinutes: 30, price: price, currency: currency)],
    );

    test('rounds the cheapest and dearest outwards to a step that fits the spread', () {
      final bounds = PriceBounds.fromResults([provider(1200), provider(8000), provider(20700)])!;
      expect(bounds.min, 1000);
      expect(bounds.max, 21000);
      expect(bounds.step, 500);
      expect(bounds.divisions, 40);
      expect(bounds.currency, 'KZT');
    });

    test('a wide spread gets coarse steps, a narrow one fine steps', () {
      expect(PriceBounds.fromResults([provider(1000), provider(90000)])!.step, 1000);
      expect(PriceBounds.fromResults([provider(1000), provider(2000)])!.step, 50);
      expect(PriceBounds.fromResults([provider(1000), provider(1100)])!.step, 5);
      expect(PriceBounds.fromResults([provider(10), provider(20)])!.step, 1);
    });

    test('providers without a price are ignored for the scale', () {
      final bounds = PriceBounds.fromResults([provider(null), provider(300), provider(900)])!;
      expect(bounds.min, 300);
      expect(bounds.max, 900);
    });

    test('nothing to choose between gives no bounds', () {
      expect(PriceBounds.fromResults(const []), isNull);
      expect(PriceBounds.fromResults([provider(null)]), isNull);
      expect(PriceBounds.fromResults([provider(500), provider(500)]), isNull);
    });
  });
}
