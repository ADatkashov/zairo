import '../../core/formatting/month_day_time.dart';
import '../../l10n/app_localizations.dart';
import '../booking/data/models/booking.dart';
import 'data/models/app_notification.dart';

/// What a notification says on screen: a headline and the lines under it.
class NotificationText {
  const NotificationText({required this.title, required this.body});

  final String title;
  final String body;
}

final _uuid = RegExp(
  r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
);

/// The booking a notification is about, if its text names one — the backend
/// writes the booking id into the sentence but sends no separate field.
String? notificationBookingId(AppNotification notification) =>
    _uuid.firstMatch(notification.body)?.group(0);

/// The notification in the person's own language, without technical ids.
///
/// The backend stores one English sentence with the booking's UUID in it. For
/// the booking events this replaces that with a localized headline, the
/// service / business / time of [booking] when it is known (the person reads
/// "Haircut · Salon X · Oct 24, 15:00", not a code) and a short localized
/// line. Offers and greetings already carry the business's own wording, so
/// they pass through with any id stripped.
NotificationText presentNotification(
  AppLocalizations l10n,
  AppNotification notification, {
  Booking? booking,
}) {
  (String, String)? known = switch (notification.type) {
    'BOOKING_CONFIRMED' => (
      l10n.notifBookingConfirmedTitle,
      l10n.notifBookingConfirmedBody,
    ),
    'BOOKING_CANCELLED' => (
      l10n.notifBookingCancelledTitle,
      l10n.notifBookingCancelledBody,
    ),
    // Two reminders share one type; the day-before one has its own headline.
    'BOOKING_REMINDER' =>
      notification.title == 'Your visit is coming up'
          ? (l10n.notifReminderDayTitle, l10n.notifReminderDayBody)
          : (l10n.notifReminderSoonTitle, l10n.notifReminderSoonBody),
    'BOOKING_MOVED' => (
      l10n.notifBookingMovedTitle,
      l10n.notifBookingMovedBody,
    ),
    'PAYMENT_REFUNDED' => (l10n.notifRefundTitle, l10n.notifRefundBody),
    'CHANGE_REQUESTED' => (
      l10n.notifChangeRequestedTitle,
      l10n.notifChangeRequestedBody,
    ),
    'WORKER_CHANGED' => (
      l10n.notifWorkerChangedTitle,
      l10n.notifWorkerChangedBody,
    ),
    _ => null,
  };

  if (known == null) {
    return NotificationText(
      title: notification.title,
      body: _withoutIds(notification.body),
    );
  }
  final details = booking == null ? null : _bookingDetails(l10n, booking);
  return NotificationText(
    title: known.$1,
    body: details == null ? known.$2 : '$details\n${known.$2}',
  );
}

String? _bookingDetails(AppLocalizations l10n, Booking booking) {
  final parts = <String>[
    ?booking.serviceTitle,
    ?booking.providerName,
    if (booking.startsAt != null)
      formatMonthDayTime(l10n, booking.startsAt!.toLocal()),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Drops a "(uuid)" / bare uuid from text that is shown as-is.
String _withoutIds(String text) => text
    .replaceAll(RegExp('\\s*\\(${_uuid.pattern}\\)'), '')
    .replaceAll(_uuid, '')
    .replaceAll(RegExp(r' {2,}'), ' ')
    .trim();
