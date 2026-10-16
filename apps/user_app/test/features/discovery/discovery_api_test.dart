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
}
