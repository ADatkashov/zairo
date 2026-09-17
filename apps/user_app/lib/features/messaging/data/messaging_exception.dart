import '../../../l10n/app_localizations.dart';

enum MessagingErrorKey { notYourBooking, bookingNotFound }

/// Only thrown by [MessagingApi.sendAboutBooking] — the plain
/// `sendToProvider` path only ever 404s on a provider that doesn't exist,
/// which is already an unreachable case from the UI (the customer app
/// never lets you type a providerId by hand).
class MessagingException implements Exception {
  final MessagingErrorKey key;

  const MessagingException(this.key);

  String localizedMessage(AppLocalizations l10n) => switch (key) {
    MessagingErrorKey.notYourBooking => l10n.errorMessagingNotYourBooking,
    MessagingErrorKey.bookingNotFound => l10n.errorMessagingBookingNotFound,
  };

  @override
  String toString() => 'MessagingException($key)';
}
