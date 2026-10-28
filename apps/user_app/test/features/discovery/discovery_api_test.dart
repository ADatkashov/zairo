import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/discovery/data/discovery_api.dart';

import '../../helpers/fake_http.dart';

void main() {
  test('search sends the city only when there is one', () async {
    final http = FakeHttp()..reply('GET', '/search/providers', <Object>[]);
    final api = DiscoveryApi(http.client());

    await api.searchProviders(cityCode: 'almaty');
    await api.searchProviders();
    await api.searchProviders(cityCode: '');

    final sent = http.calls('GET', '/search/providers');
    expect(sent[0].queryParameters['city'], 'almaty');
    expect(sent[1].queryParameters.containsKey('city'), isFalse);
    expect(sent[2].queryParameters.containsKey('city'), isFalse);
  });

  test('popular services asks for the city and a limit, and reads what the backend returns', () async {
    final http = FakeHttp()
      ..reply('GET', '/search/popular-services', <Object>[
        {'title': 'Haircut', 'bookings': 17, 'providerCount': 2, 'minPrice': 4000.0, 'currency': 'KZT'},
      ]);
    final api = DiscoveryApi(http.client());

    final result = await api.popularServices(cityCode: 'almaty', limit: 5);
    await api.popularServices();

    expect(result.single.title, 'Haircut');
    expect(result.single.bookings, 17);
    expect(result.single.providerCount, 2);
    expect(result.single.minPrice, 4000);
    expect(result.single.currency, 'KZT');
    final sent = http.calls('GET', '/search/popular-services');
    expect(sent[0].queryParameters, {'city': 'almaty', 'limit': 5});
    expect(sent[1].queryParameters, {'limit': 8}, reason: 'no city, default limit');
  });

  test('recommendations are asked for the user, the city and a limit, and read in the order given', () async {
    final http = FakeHttp()
      ..reply('GET', '/users/u1/recommendations', <Object>[
        {'providerId': 'p2', 'vertical': 'beauty'},
        {'providerId': 'p1', 'vertical': 'beauty'},
      ]);
    final api = DiscoveryApi(http.client());

    final result = await api.recommendations('u1', cityCode: 'almaty', limit: 5);
    await api.recommendations('u1');

    expect(result.map((r) => r.providerId), ['p2', 'p1']);
    expect(result.first.vertical, 'beauty');
    final sent = http.calls('GET', '/users/u1/recommendations');
    expect(sent[0].queryParameters, {'city': 'almaty', 'limit': 5});
    expect(sent[1].queryParameters, {'limit': 10}, reason: 'no city, default limit');
  });
}
