import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/ads/data/ads_api.dart';
import 'package:zairo/features/ads/data/models/ad_banner.dart';
import 'package:zairo/features/ads/presentation/providers/ads_providers.dart';
import 'package:zairo/features/city/data/models/city.dart';
import 'package:zairo/features/city/presentation/providers/city_providers.dart';

const _banner = AdBanner(
  id: 'b1',
  title: 'Bridge',
  subtitle: null,
  imageUrl: 'https://cdn.example/1.jpg',
  videoUrl: null,
  sponsored: false,
);

class _FakeAdsApi extends AdsApi {
  _FakeAdsApi({this.fail = false}) : super(DioClient(Dio()));

  final bool fail;
  String? lastCity;
  int calls = 0;

  @override
  Future<List<AdBanner>> listBanners({String? cityCode}) async {
    calls++;
    lastCity = cityCode;
    if (fail) throw Exception('offline');
    return [_banner];
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

ProviderContainer _container(_FakeAdsApi api, {City? city, bool cityFails = false}) {
  final container = ProviderContainer(
    // No automatic retry of the deliberately failing city lookup.
    retry: (_, _) => null,
    overrides: [
      adsApiProvider.overrideWithValue(api),
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
  test('asks for the banners of the user\'s city', () async {
    final api = _FakeAdsApi();
    final container = _container(api, city: _almaty);

    final banners = await container.read(homeBannersProvider.future);

    expect(banners, [_banner]);
    expect(api.lastCity, 'almaty');
  });

  test('without a city it still asks, for every-city banners', () async {
    final api = _FakeAdsApi();
    final container = _container(api);

    expect(await container.read(homeBannersProvider.future), [_banner]);
    expect(api.lastCity, isNull);
  });

  test('a failing request is "no banners", never an error', () async {
    final container = _container(_FakeAdsApi(fail: true), city: _almaty);

    expect(await container.read(homeBannersProvider.future), isEmpty);
  });

  test('a failing city lookup still shows the every-city banners', () async {
    final api = _FakeAdsApi();
    final container = _container(api, cityFails: true);

    expect(await container.read(homeBannersProvider.future), [_banner]);
    expect(api.calls, 1);
    expect(api.lastCity, isNull);
  });
}
