import '../../../l10n/app_localizations.dart';

/// System messages carry a stable key, not text — see the "Factory Country
/// Architecture" document, section 6/10. `ReviewsApi` (no BuildContext,
/// can't call AppLocalizations itself) throws one of these; the widget
/// that catches it (which does have a context) resolves the actual string
/// via [localizedMessage] at display time.
enum ReviewErrorKey { duplicateOrNotCompleted, invalidRating }

class ReviewException implements Exception {
  final ReviewErrorKey key;

  const ReviewException(this.key);

  String localizedMessage(AppLocalizations l10n) => switch (key) {
    ReviewErrorKey.duplicateOrNotCompleted =>
      l10n.errorReviewDuplicateOrNotCompleted,
    ReviewErrorKey.invalidRating => l10n.errorReviewInvalidRating,
  };

  @override
  String toString() => 'ReviewException($key)';
}
