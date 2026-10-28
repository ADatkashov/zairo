import 'data/models/booking.dart';
import 'presentation/screens/my_bookings_screen.dart' show upcomingBookingStatuses;

/// The visit that is next: among the bookings that are still to come (the
/// same statuses "Upcoming" lists), the one that starts soonest. A booking
/// whose start is unknown or already past is not "next" — it cannot be said
/// when it is, and Home would only show a stale time.
Booking? nextBooking(List<Booking> bookings, DateTime now) {
  Booking? next;
  for (final booking in bookings) {
    final start = booking.startsAt;
    if (start == null || !start.isAfter(now)) continue;
    if (!upcomingBookingStatuses.contains(booking.status)) continue;
    if (next == null || start.isBefore(next.startsAt!)) next = booking;
  }
  return next;
}
