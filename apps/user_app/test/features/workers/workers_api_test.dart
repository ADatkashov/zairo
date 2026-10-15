import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/workers/data/workers_api.dart';

import '../../helpers/fake_http.dart';

void main() {
  group('WorkersApi', () {
    test('parses the top list and sends the limit', () async {
      final http = FakeHttp()
        ..reply('GET', '/workers/top', [
          {
            'id': 'w1',
            'kind': 'MASTER',
            'providerId': 'p1',
            'providerName': 'Aigerim Beauty Studio',
            'displayName': 'Aigerim',
            'photoUrl': 'https://cdn.example/a.jpg',
            'averageRating': 4.8,
            'reviewCount': 17,
          },
          {
            'id': 'w2',
            'kind': 'STAFF',
            'providerId': 'p2',
            'providerName': 'Clinic',
            'displayName': 'Dr. Aliya',
            'averageRating': 5,
            'reviewCount': 3,
          },
        ]);

      final top = await WorkersApi(http.client()).listTop(limit: 5);

      expect(top, hasLength(2));
      expect(top[0].displayName, 'Aigerim');
      expect(top[0].kind, 'MASTER');
      expect(top[0].providerName, 'Aigerim Beauty Studio');
      expect(top[0].photoUrl, 'https://cdn.example/a.jpg');
      expect(top[0].averageRating, 4.8);
      expect(top[0].reviewCount, 17);
      expect(top[1].photoUrl, isNull);
      expect(top[1].averageRating, 5.0);
      expect(http.calls('GET', '/workers/top').single.queryParameters, {'limit': 5});
    });

    test('sends the city only when there is one', () async {
      final http = FakeHttp()..reply('GET', '/workers/top', <Object>[]);
      final api = WorkersApi(http.client());

      await api.listTop(cityCode: 'almaty');
      await api.listTop();
      await api.listTop(cityCode: '');

      final sent = http.calls('GET', '/workers/top');
      expect(sent[0].queryParameters, {'limit': 10, 'city': 'almaty'});
      expect(sent[1].queryParameters, {'limit': 10});
      expect(sent[2].queryParameters, {'limit': 10});
    });

    test('parses a profile with a rating and its services', () async {
      final http = FakeHttp()
        ..reply('GET', '/workers/w1', {
          'id': 'w1',
          'kind': 'MASTER',
          'providerId': 'p1',
          'providerName': 'Studio',
          'displayName': 'Aigerim',
          'photoUrl': null,
          'bio': 'Ten years in colouring.',
          'averageRating': 4.5,
          'reviewCount': 2,
          'reviews': [
            {'rating': 5, 'comment': 'Lovely', 'createdAt': '2026-10-01T10:00:00Z', 'businessReply': 'Thanks'},
            {'rating': 4, 'comment': null, 'createdAt': '2026-09-20T10:00:00Z'},
          ],
          'services': [
            {'id': 's1', 'title': 'Haircut', 'durationMinutes': 60, 'price': 8000, 'currency': 'KZT'},
          ],
        });

      final profile = await WorkersApi(http.client()).getProfile('w1');

      expect(profile.displayName, 'Aigerim');
      expect(profile.hasPortfolio, isTrue);
      expect(profile.bio, 'Ten years in colouring.');
      expect(profile.reviews, hasLength(2));
      expect(profile.reviews[0].rating, 5);
      expect(profile.reviews[0].comment, 'Lovely');
      expect(profile.reviews[0].businessReply, 'Thanks');
      expect(profile.reviews[1].comment, isNull);
      expect(profile.reviews[1].businessReply, isNull);
      expect(profile.averageRating, 4.5);
      expect(profile.reviewCount, 2);
      expect(profile.services.single.title, 'Haircut');
      expect(profile.services.single.durationMinutes, 60);
      expect(profile.services.single.price, 8000.0);
      expect(profile.services.single.currency, 'KZT');
    });

    test('a worker with no reviews has no rating, and only a master has a portfolio', () async {
      final http = FakeHttp()
        ..reply('GET', '/workers/w2', {
          'id': 'w2',
          'kind': 'STAFF',
          'providerId': 'p2',
          'providerName': 'Clinic',
          'displayName': 'Dr. Aliya',
          'averageRating': null,
          'reviewCount': 0,
          'services': <Object>[],
        });

      final profile = await WorkersApi(http.client()).getProfile('w2');

      expect(profile.averageRating, isNull);
      expect(profile.bio, isNull);
      expect(profile.reviews, isEmpty);
      expect(profile.hasPortfolio, isFalse);
      expect(profile.services, isEmpty);
    });

    test('reads who a booking is with', () async {
      final http = FakeHttp()
        ..reply('GET', '/bookings/b1/worker', {
          'id': 'w1',
          'kind': 'MASTER',
          'displayName': 'Aigerim',
          'photoUrl': 'https://cdn.example/a.jpg',
        });

      final worker = await WorkersApi(http.client()).getBookingWorker('b1');

      expect(worker.id, 'w1');
      expect(worker.kind, 'MASTER');
      expect(worker.displayName, 'Aigerim');
      expect(worker.photoUrl, 'https://cdn.example/a.jpg');
    });
  });
}
