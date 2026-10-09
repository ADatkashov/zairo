import 'package:core_ui/core_ui.dart' as core_ui;
import 'package:flutter/material.dart';

import '../../../../core/formatting/next_available.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/presentation/category_icon.dart';
import '../../data/models/provider_search_result.dart';

/// The three known verticals' display label, mirroring the filter chips in
/// search_screen.dart — `result.vertical` is the same raw backend code
/// ('beauty'/'auto'/'cleaning') those chips filter by. An unrecognized
/// vertical (a future one the app hasn't shipped copy for yet) falls back
/// to the raw code rather than crashing on a missing case.
String _verticalLabel(AppLocalizations l10n, String vertical) => switch (vertical) {
  'beauty' => l10n.discoveryVerticalBeauty,
  'auto' => l10n.discoveryVerticalAuto,
  'cleaning' => l10n.discoveryVerticalCleaning,
  _ => vertical,
};

/// Adapts a backend search result to Factory's shared
/// `core_ui.FactoryProviderCard` — kept as this app's own thin wrapper
/// (rather than every call site importing core_ui and mapping fields
/// itself) so the ProviderSearchResult -> card-field mapping lives in
/// exactly one place. Named `ProviderCard`, not `FactoryProviderCard`: this
/// class is this app's own type, distinct from (and no longer name-
/// colliding with) core_ui's widget of the same underlying shape. A
/// provider with no reviews yet has a null averageRating, which
/// core_ui.FactoryProviderCard already handles by not rendering the
/// rating row — no placeholder value invented here.
class ProviderCard extends StatelessWidget {
  final ProviderSearchResult result;
  final VoidCallback? onTap;
  final core_ui.FactoryProviderCardLayout layout;
  final double? width;

  const ProviderCard({
    super.key,
    required this.result,
    this.onTap,
    this.layout = core_ui.FactoryProviderCardLayout.horizontal,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final accent = colorForCategory(context, result.vertical);
    return core_ui.FactoryProviderCard(
      title: result.name,
      categoryLabel: _verticalLabel(l10n, result.vertical),
      categoryColor: accent?.color,
      categoryTint: accent?.tint,
      image: result.coverPhotoUrl == null
          ? null
          : Image.network(
              result.coverPhotoUrl!,
              fit: BoxFit.cover,
              // A broken/expired URL renders the same tinted fill
              // FactoryProviderCard itself uses when `image` is null,
              // instead of Flutter's default red-box error widget.
              errorBuilder: (context, error, stackTrace) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.primaryTint, colors.surfaceAlt],
                  ),
                ),
              ),
            ),
      // The category badge already names the vertical when the category has
      // an accent; only fall back to spelling it out (localized, never the raw
      // backend code) when there is no badge to carry it.
      metaText: result.distanceKm != null
          ? (accent != null
              ? l10n.distanceKmShort(result.distanceKm!.toStringAsFixed(1))
              : l10n.cardDistanceAndVertical(result.distanceKm!.toStringAsFixed(1), _verticalLabel(l10n, result.vertical)))
          : (accent != null ? null : _verticalLabel(l10n, result.vertical)),
      priceFrom: result.minPrice,
      rating: result.averageRating,
      reviewCount: result.reviewCount,
      ratingSemanticLabel: result.averageRating == null
          ? null
          : (result.reviewCount == null
              ? l10n.ratingSemanticLabel(result.averageRating!.toStringAsFixed(1))
              : l10n.ratingSemanticLabelWithReviews(result.averageRating!.toStringAsFixed(1), result.reviewCount!)),
      // The precise "Today 18:30" reading when we know the actual next
      // slot; falls back to the generic "Available today" badge for a
      // result that predates this field (or, in principle, has open
      // availability without a resolvable next slot — shouldn't happen,
      // but a badge is still more honest than nothing).
      availabilityLabel: result.nextAvailableSlot != null
          ? formatNextAvailable(l10n, result.nextAvailableSlot!.toLocal())
          : (result.hasOpenAvailability ? l10n.availableTodayLabel : null),
      onTap: onTap,
      layout: layout,
      width: width,
    );
  }
}
