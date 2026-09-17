import '../../../l10n/app_localizations.dart';

/// Thrown for a 409 from redeem/cancel -- the program got disabled, the
/// reward stopped being redeemable, the balance was insufficient (a race
/// past the disabled-button check), or the redemption was no longer ACTIVE.
/// Unlike most of this app's typed exceptions (a fixed enum of known
/// causes), the backend's 409 reasons here are free-text
/// (`ResponseStatusException` messages -- see LoyaltyRedemptionService),
/// not a small fixed set, so this carries the server's own `message` (see
/// platform-api's `ApiError.message`) straight through rather than mapping
/// it to a stable key. [serverMessage] is null only if the response body
/// didn't parse as the expected `{message: ...}` shape.
class LoyaltyException implements Exception {
  final String? serverMessage;

  const LoyaltyException(this.serverMessage);

  String localizedMessage(AppLocalizations l10n) => serverMessage ?? l10n.errorLoyaltyActionConflict;

  @override
  String toString() => 'LoyaltyException($serverMessage)';
}
