import '../../../l10n/app_localizations.dart';

enum BookingErrorKey {
  slotTaken,
}

class BookingException implements Exception {
  final BookingErrorKey key;

  const BookingException(this.key);

  String localizedMessage(AppLocalizations l10n) => switch (key) {
        BookingErrorKey.slotTaken => l10n.errorBookingSlotTaken,
      };

  @override
  String toString() => 'BookingException($key)';
}
