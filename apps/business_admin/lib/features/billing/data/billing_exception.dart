import '../../../l10n/app_localizations.dart';

/// Mirrors `auth`'s AuthException/AuthErrorKey pattern — a typed exception
/// an API client throws for a specific backend status code (here, 402 —
/// see backend's SubscriptionLimitExceededException), so callers can show a
/// localized, actionable message instead of a raw DioException.toString().
enum SubscriptionErrorKey {
  providerLimitReached,
  staffLimitReached,
  bookingLimitReached,
  featureRequiresUpgrade,
}

class BillingException implements Exception {
  final SubscriptionErrorKey key;

  const BillingException(this.key);

  String localizedMessage(AppLocalizations l10n) => switch (key) {
        SubscriptionErrorKey.providerLimitReached => l10n.errorProviderLimitReached,
        SubscriptionErrorKey.staffLimitReached => l10n.errorStaffLimitReached,
        SubscriptionErrorKey.bookingLimitReached => l10n.errorBookingLimitReached,
        SubscriptionErrorKey.featureRequiresUpgrade => l10n.errorFeatureRequiresUpgrade,
      };

  @override
  String toString() => 'BillingException($key)';
}
