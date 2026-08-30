import '../../../l10n/app_localizations.dart';

enum StaffErrorKey {
  bookingFailed,
}

class StaffException implements Exception {
  final StaffErrorKey key;

  const StaffException(this.key);

  String localizedMessage(AppLocalizations l10n) => switch (key) {
        StaffErrorKey.bookingFailed => l10n.errorStaffBookingFailed,
      };

  @override
  String toString() => 'StaffException($key)';
}
