import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/city/data/models/city.dart';
import 'package:zairo/features/city/presentation/providers/city_providers.dart';
import 'package:zairo/features/workers/data/models/top_worker.dart';
import 'package:zairo/features/workers/data/workers_api.dart';
import 'package:zairo/features/workers/presentation/providers/workers_providers.dart';

const _worker = TopWorker(
  id: 'w1',
  kind: 'MASTER',
  providerId: 'p1',
  providerName: 'Studio',
  displayName: 'Aigerim',
  photoUrl: null,
  averageRating: 4.8,
  reviewCount: 5,
);

class _FakeWorkersApi extends WorkersApi {
  _FakeWorkersApi({this.fail = false}) : super(DioClient(Dio()));

  final bool fail;
  String? lastCity;
  int calls = 0;

  @override
  Future<List<TopWorker>> listTop({int limit = 10, String? cityCode}) async {
    calls++;
    lastCity = cityCode;
    if (fail) throw Exception('offline');
    return [_worker];
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

ProviderContainer _container(_FakeWorkersApi api, {City? city, bool cityFails = false}) {
  final container = ProviderContainer(
    // No automatic retry of the deliberately failing city lookup.
    retry: (_, _) => null,
    overrides: [
      workersApiProvider.overrideWithValue(api),
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
  test('asks for the best masters of the user\'s city', () async {
    final api = _FakeWorkersApi();
    final container = _container(api, city: _almaty);

    expect(await container.read(topWorkersProvider.future), [_worker]);
    expect(api.lastCity, 'almaty');
  });

  test('without a city it still asks, for everywhere', () async {
    final api = _FakeWorkersApi();
    final container = _container(api);

    expect(await container.read(topWorkersProvider.future), [_worker]);
    expect(api.lastCity, isNull);
  });

  test('a failing city lookup still shows the masters', () async {
    final api = _FakeWorkersApi();
    final container = _container(api, cityFails: true);

    expect(await container.read(topWorkersProvider.future), [_worker]);
    expect(api.calls, 1);
    expect(api.lastCity, isNull);
  });

  test('a failing request is "no rail", never an error', () async {
    final container = _container(_FakeWorkersApi(fail: true), city: _almaty);

    expect(await container.read(topWorkersProvider.future), isEmpty);
  });
}
