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
}
