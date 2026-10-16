import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/waitlist/data/models/waitlist_entry.dart';
import 'package:zairo/features/waitlist/data/waitlist_api.dart';

import '../../helpers/fake_http.dart';

void main() {
  group('WaitlistApi', () {
    test('lists the active entries by business id, with and without a wanted day', () async {
      final day = DateTime(2026, 10, 20);
      final http = FakeHttp()
        ..reply('GET', '/users/u1/waitlist', [
          {'providerId': 'p1', 'providerName': 'Salon', 'joinedAt': '2026-10-16T10:00:00Z'},
          {
            'providerId': 'p2',
            'providerName': 'Studio',
            'from': day.toUtc().toIso8601String(),
            'to': DateTime(2026, 10, 21).toUtc().toIso8601String(),
            'joinedAt': '2026-10-16T11:00:00Z',
          },
        ]);

      final entries = await WaitlistApi(http.client()).listEntries('u1');

      expect(entries.keys, {'p1', 'p2'});
      expect(entries['p1']!.day, isNull);
      expect(entries['p2']!.day, day);
    });

    test('joins for any time with no body', () async {
      final http = FakeHttp()..reply('PUT', '/users/u1/waitlist/p1', null, status: 204);

      await WaitlistApi(http.client()).join('u1', 'p1');

      final sent = http.calls('PUT', '/users/u1/waitlist/p1');
      expect(sent, hasLength(1));
      expect(sent.single.data, isNull);
    });

    test('joins for one local day as an instant range covering exactly that day', () async {
      final http = FakeHttp()..reply('PUT', '/users/u1/waitlist/p1', null, status: 204);

      await WaitlistApi(http.client()).join('u1', 'p1', day: DateTime(2026, 10, 20));

      final body = http.bodyOf('PUT', '/users/u1/waitlist/p1');
      expect(DateTime.parse(body['from'] as String), DateTime(2026, 10, 20).toUtc());
      expect(DateTime.parse(body['to'] as String), DateTime(2026, 10, 21).toUtc());
    });

    test('leaves with a DELETE', () async {
      final http = FakeHttp()..reply('DELETE', '/users/u1/waitlist/p1', null, status: 204);

      await WaitlistApi(http.client()).leave('u1', 'p1');

      expect(http.calls('DELETE', '/users/u1/waitlist/p1'), hasLength(1));
    });
  });

  group('WaitlistEntry', () {
    test('reads a business-only entry as "any day"', () {
      final entry = WaitlistEntry.fromJson({'providerId': 'p1'});

      expect(entry.providerId, 'p1');
      expect(entry.from, isNull);
      expect(entry.day, isNull);
    });
  });
}
