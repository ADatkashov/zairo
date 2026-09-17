import '../../../l10n/app_localizations.dart';

/// Mirrors [LoyaltyAdminException]'s pattern. Automation Center's backend
/// surface has a narrower failure set than Loyalty's: 400 for a validation
/// error (the backend's own `message` is the most accurate text to show)
/// and 403 when the caller doesn't own `providerId` -- no 404/409 cases
/// exist on this surface (`GET`/`PUT` both auto-create the settings draft).
class AutomationException implements Exception {
  final int? statusCode;
  final String? serverMessage;

  const AutomationException({this.statusCode, this.serverMessage});

  String localizedMessage(AppLocalizations l10n) {
    switch (statusCode) {
      case 400:
        return serverMessage ?? l10n.errorAutomationValidationFailed;
      case 403:
        return l10n.errorAutomationForbidden;
      default:
        return l10n.errorAutomationActionFailed(serverMessage ?? statusCode?.toString() ?? '');
    }
  }

  @override
  String toString() => 'AutomationException(statusCode: $statusCode, serverMessage: $serverMessage)';
}
