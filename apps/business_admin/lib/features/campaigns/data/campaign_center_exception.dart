import '../../../l10n/app_localizations.dart';

/// Mirrors `billing`'s BillingException pattern -- a typed exception the
/// API client throws for a specific backend status code, so the UI can show
/// a localized, actionable message instead of a raw DioException.toString().
///
/// A 409 from a pause/resume/cancel/retry call means the action no longer
/// applies (someone else already acted on it, or the UI's own view of the
/// campaign is stale) -- never a crash, just a friendly notice plus a
/// refresh of the campaign from the server.
class CampaignActionConflictException implements Exception {
  const CampaignActionConflictException();

  String localizedMessage(AppLocalizations l10n) => l10n.errorCampaignActionConflict;

  @override
  String toString() => 'CampaignActionConflictException()';
}
