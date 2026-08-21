import '../../../l10n/app_localizations.dart';

enum BookingErrorKey {
  slotTaken,
  notCancellable,
  notYourBooking,
}

class BookingException implements Exception {
  final BookingErrorKey key;

  const BookingException(this.key);

  String localizedMessage(AppLocalizations l10n) => switch (key) {
        BookingErrorKey.slotTaken => l10n.errorBookingSlotTaken,
        BookingErrorKey.notCancellable => l10n.errorBookingNotCancellable,
        BookingErrorKey.notYourBooking => l10n.errorBookingNotYours,
      };

  @override
  String toString() => 'BookingException($key)';
}
