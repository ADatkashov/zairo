import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/booking/data/models/booking.dart';

Map<String, dynamic> _json({Map<String, dynamic> extra = const {}}) => {
  'id': 'b1',
  'userId': 'u1',
  'serviceId': 's1',
  'availabilitySlotId': 'slot1',
  'status': 'CONFIRMED',
  'totalPrice': 12400.0,
  'createdAt': '2026-10-09T19:32:43.145540Z',
  ...extra,
};

void main() {
  test('reads the resolved service, business and appointment time', () {
    final booking = Booking.fromJson(_json(extra: {
      'serviceTitle': 'Gel manicure',
      'providerId': 'p1',
      'providerName': 'Nur Beauty Salon',
      'providerVertical': 'beauty',
      'startsAt': '2026-10-10T05:00:00Z',
      'endsAt': '2026-10-10T06:00:00Z',
    }));

    expect(booking.serviceTitle, 'Gel manicure');
    expect(booking.providerName, 'Nur Beauty Salon');
    expect(booking.providerVertical, 'beauty');
    expect(booking.startsAt, DateTime.utc(2026, 10, 10, 5));
    expect(booking.endsAt, DateTime.utc(2026, 10, 10, 6));
  });

  test('an older backend that omits them (or sends null) still parses', () {
    for (final extra in [<String, dynamic>{}, {'serviceTitle': null, 'startsAt': null}]) {
      final booking = Booking.fromJson(_json(extra: extra));
      expect(booking.serviceTitle, isNull);
      expect(booking.providerName, isNull);
      expect(booking.startsAt, isNull);
      expect(booking.endsAt, isNull);
    }
  });

  test('an unparseable time is ignored rather than crashing the list', () {
    expect(Booking.fromJson(_json(extra: {'startsAt': 'not a date'})).startsAt, isNull);
  });
}
