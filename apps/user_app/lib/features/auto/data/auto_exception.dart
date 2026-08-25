import '../../../l10n/app_localizations.dart';

enum AutoErrorKey {
  bookingFailed,
}

class AutoException implements Exception {
  final AutoErrorKey key;

  const AutoException(this.key);

  String localizedMessage(AppLocalizations l10n) => switch (key) {
        AutoErrorKey.bookingFailed => l10n.errorAutoBookingFailed,
      };

  @override
  String toString() => 'AutoException($key)';
}
