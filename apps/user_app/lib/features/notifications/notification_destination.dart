import '../../app/router/app_routes.dart';

/// Where tapping a notification of [type] should go, or null when it has no
/// natural destination.
///
/// The backend's NotificationResponse carries no booking / business id (only
/// the type, title and body), so this routes to the *list* the event belongs
/// to rather than to one record: a booking event opens Bookings, a business's
/// offer opens Search, a loyalty greeting opens My rewards.
String? notificationDestination(String type) => switch (type) {
  'BOOKING_CONFIRMED' ||
  'BOOKING_CANCELLED' ||
  'BOOKING_REMINDER' ||
  'PAYMENT_REFUNDED' => AppRoutes.bookings,
  'SMART_FILL_OFFER' ||
  'REBOOK_OFFER' ||
  'REACTIVATION_OFFER' ||
  'WAITLIST_SLOT_OPENED' => AppRoutes.search(),
  'BIRTHDAY_BONUS' || 'GREETING' => AppRoutes.rewards,
  _ => null,
};
