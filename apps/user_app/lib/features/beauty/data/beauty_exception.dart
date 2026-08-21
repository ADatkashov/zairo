import '../../../l10n/app_localizations.dart';

enum BeautyErrorKey {
  bookingFailed,
}

class BeautyException implements Exception {
  final BeautyErrorKey key;

  const BeautyException(this.key);

  String localizedMessage(AppLocalizations l10n) => switch (key) {
        BeautyErrorKey.bookingFailed => l10n.errorBeautyBookingFailed,
      };

  @override
  String toString() => 'BeautyException($key)';
}
