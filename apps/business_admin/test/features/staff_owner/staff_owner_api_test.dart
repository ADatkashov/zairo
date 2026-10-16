import 'package:business_admin/features/staff_owner/data/models/worker_schedule.dart';
import 'package:business_admin/features/staff_owner/data/staff_owner_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';

const _base = '/providers/p1';

const _scheduleJson = {
  'configured': true,
  'zoneId': '+05:00',
  'slotMinutes': 45,
  'breakMinutes': 15,
  'hours': [
    {'dayOfWeek': 1, 'startTime': '09:00:00', 'endTime': '13:30:00'},
    {'dayOfWeek': 3, 'startTime': '14:05:00', 'endTime': '18:00:00'},
  ],
};

void main() {
  late FakeHttp http;
  late StaffOwnerApi api;

  setUp(() {
    http = FakeHttp();
    api = StaffOwnerApi(http.client());
  });

  group('a worker\'s rating', () {
    test('workerRating parses the average, the distribution and the reviews with names', () async {
      http.reply('GET', '$_base/workers/w1/rating', {
        'averageRating': 4.5,
        'reviewCount': 2,
        'distribution': [0, 0, 0, 1, 1],
        'reviews': [
          {
            'reviewId': 'r1',
            'bookingId': 'b1',
            'customerName': 'Aisha K.',
            'rating': 5,
            'comment': 'Lovely',
            'createdAt': '2026-10-12T10:00:00Z',
            'businessReply': 'Thanks',
          },
          {'reviewId': 'r2', 'customerName': null, 'rating': 4, 'comment': null, 'createdAt': '2026-10-01T10:00:00Z'},
        ],
      });

      final rating = await api.workerRating('p1', 'w1');

      expect(rating.averageRating, 4.5);
      expect(rating.reviewCount, 2);
      expect(rating.distribution, [0, 0, 0, 1, 1]);
      expect(rating.reviews[0].reviewId, 'r1');
      expect(rating.reviews[0].customerName, 'Aisha K.');
      expect(rating.reviews[0].comment, 'Lovely');
      expect(rating.reviews[0].businessReply, 'Thanks');
      expect(rating.reviews[1].customerName, isNull);
      expect(rating.reviews[1].businessReply, isNull);
    });

    test('a worker with no reviews has no average', () async {
      http.reply('GET', '$_base/workers/w2/rating', {
        'averageRating': null,
        'reviewCount': 0,
        'distribution': [0, 0, 0, 0, 0],
        'reviews': <Object>[],
      });

      final rating = await api.workerRating('p1', 'w2');

      expect(rating.averageRating, isNull);
      expect(rating.reviews, isEmpty);
    });
  });

  group('appointments needing attention', () {
    test('needsAttention parses a full item, its replacements and the defaults', () async {
      http.reply('GET', '$_base/appointments/needs-attention', [
        {
          'bookingId': 'b1',
          'status': 'CONFIRMED',
          'startsAt': '2026-10-13T10:00:00Z',
          'endsAt': '2026-10-13T11:00:00Z',
          'serviceTitle': 'Haircut',
          'customerName': 'Aigerim',
          'customerPhone': '+77001234567',
          'totalPrice': 5000,
          'currency': 'KZT',
          'workerId': 'w1',
          'workerKind': 'MASTER',
          'workerName': 'Dana',
          'reason': 'WORKER_DECLINED',
          'workerNote': 'Sick',
          'requestedAt': '2026-10-12T08:00:00Z',
          'preference': 'ANY',
          'customerAskedAt': '2026-10-12T09:00:00Z',
          'replacements': [
            {'workerId': 'w2', 'name': 'Saule', 'atWorkingTime': false},
            {'workerId': 'w3'},
          ],
        },
        {
          'bookingId': 'b2',
          'status': 'CONFIRMED',
          'startsAt': '2026-10-13T12:00:00Z',
          'endsAt': '2026-10-13T13:00:00Z',
          'totalPrice': 3000,
          'currency': 'KZT',
          'workerId': 'w1',
          'reason': 'UNACCEPTED',
        },
      ]);

      final items = await api.needsAttention('p1');

      final full = items[0];
      expect([full.bookingId, full.serviceTitle, full.customerName, full.customerPhone],
          ['b1', 'Haircut', 'Aigerim', '+77001234567']);
      expect([full.workerId, full.workerKind, full.workerName, full.reason, full.workerNote],
          ['w1', 'MASTER', 'Dana', 'WORKER_DECLINED', 'Sick']);
      expect(full.totalPrice, 5000);
      expect(full.preference, 'ANY');
      expect(full.requestedAt, isNotNull);
      expect(full.customerAskedAt, isNotNull);
      expect(full.replacements.map((r) => r.workerId), ['w2', 'w3']);
      expect(full.replacements[0].atWorkingTime, isFalse);
      expect(full.replacements[1].name, '');
      expect(full.replacements[1].atWorkingTime, isTrue);

      final bare = items[1];
      expect(bare.preference, 'SPECIFIC');
      expect(bare.requestedAt, isNull);
      expect(bare.customerAskedAt, isNull);
      expect(bare.replacements, isEmpty);
      expect(bare.serviceTitle, isNull);
    });

    test('cancelAppointment sends the reason only when there is one', () async {
      http.reply('POST', '$_base/appointments/b1/cancel', <String, Object?>{});

      await api.cancelAppointment('p1', 'b1', reason: 'Closed that day');
      expect(http.bodyOf('POST', '$_base/appointments/b1/cancel'), {'reason': 'Closed that day'});

      http.requests.clear();
      await api.cancelAppointment('p1', 'b1');
      expect(http.bodyOf('POST', '$_base/appointments/b1/cancel'), <String, dynamic>{});

      http.requests.clear();
      await api.cancelAppointment('p1', 'b1', reason: '');
      expect(http.bodyOf('POST', '$_base/appointments/b1/cancel'), <String, dynamic>{});
    });

    test('reassign, ask the customer and mark attended post to their own endpoints', () async {
      http
        ..reply('POST', '$_base/appointments/b1/reassign', <String, Object?>{})
        ..reply('POST', '$_base/appointments/b1/ask-customer', <String, Object?>{})
        ..reply('POST', '$_base/appointments/b1/mark-attended', <String, Object?>{});

      await api.reassignAppointment('p1', 'b1', 'w2');
      await api.askCustomer('p1', 'b1');
      await api.markAttended('p1', 'b1');

      expect(http.bodyOf('POST', '$_base/appointments/b1/reassign'), {'workerId': 'w2'});
      expect(http.calls('POST', '$_base/appointments/b1/ask-customer'), hasLength(1));
      expect(http.calls('POST', '$_base/appointments/b1/mark-attended'), hasLength(1));
    });
  });

  group('appointment actions', () {
    test('no-show, completion and the move go to the booking endpoints', () async {
      http.reply('GET', '/bookings/b1/owner-reschedule-options', [
        {'slotId': 's2', 'startsAt': '2026-10-20T09:00:00Z', 'endsAt': '2026-10-20T10:00:00Z'},
      ]);
      http.reply('POST', '/bookings/b1/no-show', {});
      http.reply('POST', '/bookings/b1/complete', {});
      http.reply('POST', '/bookings/b1/owner-reschedule', {});

      final options = await api.rescheduleOptions('b1');
      await api.markNoShow('b1');
      await api.markCompleted('b1');
      await api.reschedule('b1', 's2');

      expect(options.single.slotId, 's2');
      expect(options.single.startsAt, DateTime.utc(2026, 10, 20, 9));
      expect(http.calls('POST', '/bookings/b1/no-show'), hasLength(1));
      expect(http.calls('POST', '/bookings/b1/complete'), hasLength(1));
      expect(http.bodyOf('POST', '/bookings/b1/owner-reschedule'), {'slotId': 's2'});
    });
  });

  group('worker prices', () {
    test('workerPrices maps service id to its price', () async {
      http.reply('GET', '$_base/workers/w1/prices', [
        {'serviceId': 's1', 'price': 4500},
        {'serviceId': 's2', 'price': 1000.5},
      ]);

      expect(await api.workerPrices('p1', 'w1'), {'s1': 4500.0, 's2': 1000.5});
    });

    test('setWorkerPrice puts the price, and null falls back to the default', () async {
      http.reply('PUT', '$_base/workers/w1/prices', <String, Object?>{});

      await api.setWorkerPrice('p1', 'w1', 's1', 4000);
      expect(http.bodyOf('PUT', '$_base/workers/w1/prices'), {'serviceId': 's1', 'price': 4000.0});

      http.requests.clear();
      await api.setWorkerPrice('p1', 'w1', 's1', null);
      expect(http.bodyOf('PUT', '$_base/workers/w1/prices'), {'serviceId': 's1', 'price': null});
    });
  });

  group('workers and schedules', () {
    test('workers lists people with their schedule status and days off', () async {
      http.reply('GET', '$_base/workers', [
        {
          'id': 'w1',
          'kind': 'MASTER',
          'displayName': 'Dana',
          'photoUrl': 'https://img/d.png',
          'active': true,
          'scheduleConfigured': true,
          'offUntil': '2026-10-20T00:00:00Z',
        },
        {'id': 'w2', 'kind': 'CLEANER', 'displayName': 'Saule', 'active': false, 'scheduleConfigured': false},
      ]);

      final workers = await api.workers('p1');

      expect(workers[0].offUntil, isNotNull);
      expect(workers[0].photoUrl, 'https://img/d.png');
      expect(workers[0].scheduleConfigured, isTrue);
      expect(workers[1].offUntil, isNull);
      expect(workers[1].active, isFalse);
      expect(workers[1].kind, 'CLEANER');
    });

    test('schedule parses slot length, break and weekly hours', () async {
      http.reply('GET', '$_base/workers/w1/schedule', _scheduleJson);

      final s = await api.schedule('p1', 'w1');

      expect([s.configured, s.zoneId, s.slotMinutes, s.breakMinutes], [true, '+05:00', 45, 15]);
      expect(s.hours[0].dayOfWeek, 1);
      expect(s.hours[0].start, const TimeOfDay(hour: 9, minute: 0));
      expect(s.hours[0].end, const TimeOfDay(hour: 13, minute: 30));
      expect(s.hours[1].start, const TimeOfDay(hour: 14, minute: 5));
    });

    test('an unconfigured schedule falls back to one-hour slots with no break', () async {
      http.reply('GET', '$_base/workers/w1/schedule', {'configured': false, 'hours': <Object?>[]});

      final s = await api.schedule('p1', 'w1');

      expect(s.configured, isFalse);
      expect(s.zoneId, isNull);
      expect(s.slotMinutes, 60);
      expect(s.breakMinutes, 0);
      expect(s.hours, isEmpty);
    });

    test('saveSchedule sends the local offset, the lengths and zero-padded hours, and parses the result', () async {
      http.reply('PUT', '$_base/workers/w1/schedule', {
        'schedule': _scheduleJson,
        'slotsCreated': 12,
        'slotsRemoved': 3,
      });

      final result = await api.saveSchedule(
        'p1',
        'w1',
        slotMinutes: 45,
        breakMinutes: 15,
        hours: const [
          HoursInterval(dayOfWeek: 1, start: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 13, minute: 30)),
        ],
      );

      final body = http.bodyOf('PUT', '$_base/workers/w1/schedule');
      expect(body['zoneId'], matches(RegExp(r'^[+-]\d{2}:\d{2}$')));
      expect(body['slotMinutes'], 45);
      expect(body['breakMinutes'], 15);
      expect(body['hours'], [
        {'dayOfWeek': 1, 'startTime': '09:00:00', 'endTime': '13:30:00'},
      ]);
      expect(result.slotsCreated, 12);
      expect(result.slotsRemoved, 3);
      expect(result.schedule.slotMinutes, 45);
    });

    test('deleteSchedule deletes the worker schedule', () async {
      http.reply('DELETE', '$_base/workers/w1/schedule', <String, Object?>{});

      await api.deleteSchedule('p1', 'w1');

      expect(http.calls('DELETE', '$_base/workers/w1/schedule'), hasLength(1));
    });

    test('localZoneOffset formats positive, negative and half-hour offsets', () {
      expect(StaffOwnerApi.localZoneOffset(const Duration(hours: 5)), '+05:00');
      expect(StaffOwnerApi.localZoneOffset(const Duration(hours: -8)), '-08:00');
      expect(StaffOwnerApi.localZoneOffset(const Duration(hours: 5, minutes: 30)), '+05:30');
      expect(StaffOwnerApi.localZoneOffset(Duration.zero), '+00:00');
      expect(StaffOwnerApi.localZoneOffset(), matches(RegExp(r'^[+-]\d{2}:\d{2}$')));
    });
  });

  group('time off', () {
    test('timeOff lists entries, flagging the ones the worker set themselves', () async {
      http.reply('GET', '$_base/workers/w1/time-off', [
        {'id': 't1', 'startsAt': '2026-10-14T00:00:00Z', 'endsAt': '2026-10-16T00:00:00Z', 'reason': 'Trip',
          'byWorker': true},
        {'id': 't2', 'startsAt': '2026-10-20T00:00:00Z', 'endsAt': '2026-10-21T00:00:00Z', 'byWorker': false},
      ]);

      final items = await api.timeOff('p1', 'w1');

      expect(items.map((t) => t.byWorker), [true, false]);
      expect(items.map((t) => t.reason), ['Trip', null]);
    });

    test('createTimeOff sends UTC times, the reason only when given, and reports affected bookings', () async {
      http.reply('POST', '$_base/workers/w1/time-off', {
        'timeOff': {'id': 't9', 'startsAt': '2026-10-14T00:00:00Z', 'endsAt': '2026-10-16T00:00:00Z', 'byWorker': false},
        'affectedAppointments': 2,
      });

      final created = await api.createTimeOff('p1', 'w1',
          startsAt: DateTime.utc(2026, 10, 14), endsAt: DateTime.utc(2026, 10, 16), reason: 'Vacation');
      expect(http.bodyOf('POST', '$_base/workers/w1/time-off'), {
        'startsAt': '2026-10-14T00:00:00.000Z',
        'endsAt': '2026-10-16T00:00:00.000Z',
        'reason': 'Vacation',
      });
      expect(created.timeOff.id, 't9');
      expect(created.affectedAppointments, 2);

      http.requests.clear();
      await api.createTimeOff('p1', 'w1', startsAt: DateTime.utc(2026, 10, 14), endsAt: DateTime.utc(2026, 10, 16));
      expect(http.bodyOf('POST', '$_base/workers/w1/time-off').containsKey('reason'), isFalse);

      http.requests.clear();
      await api.createTimeOff('p1', 'w1',
          startsAt: DateTime.utc(2026, 10, 14), endsAt: DateTime.utc(2026, 10, 16), reason: '');
      expect(http.bodyOf('POST', '$_base/workers/w1/time-off').containsKey('reason'), isFalse);
    });

    test('deleteTimeOff deletes the entry by id', () async {
      http.reply('DELETE', '$_base/time-off/t1', <String, Object?>{});

      await api.deleteTimeOff('p1', 't1');

      expect(http.calls('DELETE', '$_base/time-off/t1'), hasLength(1));
    });
  });

  group('workforce settings', () {
    test('settings and updateSettings round-trip the two switches', () async {
      http.reply('GET', '$_base/workforce-settings', {'allowWorkerChoice': true, 'workerPricingEnabled': false});
      http.reply('PUT', '$_base/workforce-settings', {'allowWorkerChoice': false, 'workerPricingEnabled': true});

      final current = await api.settings('p1');
      expect([current.allowWorkerChoice, current.workerPricingEnabled], [true, false]);

      final saved = await api.updateSettings('p1', allowWorkerChoice: false, workerPricingEnabled: true);
      expect(http.bodyOf('PUT', '$_base/workforce-settings'),
          {'allowWorkerChoice': false, 'workerPricingEnabled': true});
      expect([saved.allowWorkerChoice, saved.workerPricingEnabled], [false, true]);
    });
  });
}
