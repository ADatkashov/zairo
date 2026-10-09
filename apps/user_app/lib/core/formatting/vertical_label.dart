import '../../l10n/app_localizations.dart';

/// The display label of a provider's vertical. `vertical` is the raw backend
/// code ('beauty'/'auto'/'cleaning') the search filter chips use too. An
/// unrecognized vertical (a future one the app has no copy for yet) falls back
/// to the raw code rather than crashing on a missing case.
String verticalLabel(AppLocalizations l10n, String vertical) => switch (vertical) {
  'beauty' => l10n.discoveryVerticalBeauty,
  'auto' => l10n.discoveryVerticalAuto,
  'cleaning' => l10n.discoveryVerticalCleaning,
  _ => vertical,
};
