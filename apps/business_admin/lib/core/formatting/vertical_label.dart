import '../../l10n/app_localizations.dart';

/// The localized name of a business vertical (`beauty`, `auto`, `cleaning`).
/// The backend sends the raw lowercase code; showing it capitalized put an
/// English "Beauty" in Russian and Kazakh screens. An unknown vertical falls
/// back to its capitalized code rather than crashing on a missing case.
String verticalLabel(AppLocalizations l10n, String vertical) => switch (vertical) {
      'beauty' => l10n.verticalBeautyLabel,
      'auto' => l10n.verticalAutoLabel,
      'cleaning' => l10n.verticalCleaningLabel,
      _ => vertical.isEmpty ? vertical : '${vertical[0].toUpperCase()}${vertical.substring(1).toLowerCase()}',
    };
