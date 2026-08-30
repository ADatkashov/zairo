import '../../../l10n/app_localizations.dart';

enum CleaningErrorKey {
  bookingFailed,
}

class CleaningException implements Exception {
  final CleaningErrorKey key;

  const CleaningException(this.key);

  String localizedMessage(AppLocalizations l10n) => switch (key) {
        CleaningErrorKey.bookingFailed => l10n.errorCleaningBookingFailed,
      };

  @override
  String toString() => 'CleaningException($key)';
}
