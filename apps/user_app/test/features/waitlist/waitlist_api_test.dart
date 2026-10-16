import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/waitlist/data/waitlist_api.dart';

import '../../helpers/fake_http.dart';

void main() {
  group('WaitlistApi', () {
    test('lists the ids of the businesses the user is waiting for', () async {
      final http = FakeHttp()
        ..reply('GET', '/users/u1/waitlist', [
          {'providerId': 'p1', 'providerName': 'Salon', 'joinedAt': '2026-10-16T10:00:00Z'},
          {'providerId': 'p2', 'providerName': 'Studio', 'joinedAt': '2026-10-16T11:00:00Z'},
        ]);

      final ids = await WaitlistApi(http.client()).waitingProviderIds('u1');

      expect(ids, {'p1', 'p2'});
    });

    test('joins with a PUT and leaves with a DELETE', () async {
      final http = FakeHttp()
        ..reply('PUT', '/users/u1/waitlist/p1', null, status: 204)
        ..reply('DELETE', '/users/u1/waitlist/p1', null, status: 204);
      final api = WaitlistApi(http.client());

      await api.join('u1', 'p1');
      await api.leave('u1', 'p1');

      expect(http.calls('PUT', '/users/u1/waitlist/p1'), hasLength(1));
      expect(http.calls('DELETE', '/users/u1/waitlist/p1'), hasLength(1));
    });
  });
}
