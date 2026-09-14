import '../../../l10n/app_localizations.dart';

/// Mirrors `campaigns`' CampaignActionConflictException /
/// `billing`'s BillingException pattern -- a typed exception
/// [LoyaltyAdminApi]'s write calls throw for a specific backend status code,
/// so callers show a localized, actionable message instead of a raw
/// DioException.toString().
///
/// The Loyalty admin surface (backend/loyalty/.../LoyaltyAdminController)
/// has richer failure modes than Campaign Center's single 409 case: 400 for
/// settings/reward validation (a blank name, a non-positive discount, a
/// repeatVisitThreshold < 2 -- the backend's own `message` is the most
/// accurate text to show, so it's carried through as [serverMessage] rather
/// than re-derived), 403 when the caller doesn't own [providerId], 404 for a
/// redemption code that doesn't belong to this business, and 409 for a
/// conflict (deleting a redeemed reward, adjusting a balance negative,
/// applying a redemption that's no longer ACTIVE) -- 409's [serverMessage]
/// is likewise shown as-is since the backend already explains exactly why.
class LoyaltyAdminException implements Exception {
  final int? statusCode;
  final String? serverMessage;

  const LoyaltyAdminException({this.statusCode, this.serverMessage});

  String localizedMessage(AppLocalizations l10n) {
    switch (statusCode) {
      case 400:
        return serverMessage ?? l10n.errorLoyaltyValidationFailed;
      case 403:
        return l10n.errorLoyaltyForbidden;
      case 404:
        return l10n.errorLoyaltyNotFound;
      case 409:
        return serverMessage ?? l10n.errorLoyaltyConflict;
      default:
        return l10n.errorLoyaltyActionFailed(serverMessage ?? statusCode?.toString() ?? '');
    }
  }

  @override
  String toString() => 'LoyaltyAdminException(statusCode: $statusCode, serverMessage: $serverMessage)';
}
