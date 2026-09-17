import '../../../l10n/app_localizations.dart';

/// Mirrors [LoyaltyAdminException]'s pattern -- a typed exception the
/// reviews API's calls throw for a specific backend status code, so callers
/// show a localized, actionable message instead of a raw DioException.
/// The backend's own failure modes here are narrow: 403 when the caller
/// doesn't own the reviewed provider/booking's provider, 404 for a review
/// or provider that doesn't exist.
class ReviewsException implements Exception {
  final int? statusCode;
  final String? serverMessage;

  const ReviewsException({this.statusCode, this.serverMessage});

  String localizedMessage(AppLocalizations l10n) {
    switch (statusCode) {
      case 403:
        return l10n.errorReviewsForbidden;
      case 404:
        return l10n.errorReviewsNotFound;
      default:
        return l10n.errorReviewsActionFailed(serverMessage ?? statusCode?.toString() ?? '');
    }
  }

  @override
  String toString() => 'ReviewsException(statusCode: $statusCode, serverMessage: $serverMessage)';
}
