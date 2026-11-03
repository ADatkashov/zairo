import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/booking/data/models/booking.dart';
import 'package:zairo/features/booking/next_booking.dart';

final _now = DateTime.utc(2026, 10, 28, 12);

Booking _booking(String id, {String status = 'CONFIRMED', DateTime? startsAt}) => Booking(
  id: id,
  userId: 'u',
  serviceId: 's',
  availabilitySlotId: 'slot',
  status: status,
  totalPrice: 100,
  createdAt: _now,
  startsAt: startsAt,
);

void main() {
  test('no bookings, no next booking', () {
    expect(nextBooking(const [], _now), isNull);
  });

  test('the soonest future visit wins, whatever the list order', () {
    final result = nextBooking([
      _booking('later', startsAt: _now.add(const Duration(days: 3))),
      _booking('soonest', startsAt: _now.add(const Duration(hours: 5))),
      _booking('middle', startsAt: _now.add(const Duration(days: 1))),
    ], _now);

    expect(result?.id, 'soonest');
  });

  test('a booking awaiting payment still counts: the person has something to do', () {
    expect(nextBooking([_booking('a', status: 'PENDING_PAYMENT', startsAt: _now.add(const Duration(hours: 1)))], _now)?.id, 'a');
  });

  test('past, cancelled, completed and undated bookings are not next', () {
    final result = nextBooking([
      _booking('past', startsAt: _now.subtract(const Duration(hours: 1))),
      _booking('now', startsAt: _now),
      _booking('cancelled', status: 'CANCELLED', startsAt: _now.add(const Duration(hours: 2))),
      _booking('completed', status: 'COMPLETED', startsAt: _now.add(const Duration(hours: 2))),
      _booking('undated'),
    ], _now);

    expect(result, isNull);
  });
}
