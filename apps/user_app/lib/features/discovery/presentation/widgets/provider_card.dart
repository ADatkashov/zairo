import 'package:core_ui/core_ui.dart' as core_ui;
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/provider_search_result.dart';

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
    return core_ui.FactoryProviderCard(
      title: result.name,
      metaText: result.distanceKm != null
          ? l10n.cardDistanceAndVertical(result.distanceKm!.toStringAsFixed(1), result.vertical)
          : result.vertical,
      priceFrom: result.minPrice,
      rating: result.averageRating,
      reviewCount: result.reviewCount,
      ratingSemanticLabel: result.averageRating == null
          ? null
          : (result.reviewCount == null
              ? l10n.ratingSemanticLabel(result.averageRating!.toStringAsFixed(1))
              : l10n.ratingSemanticLabelWithReviews(result.averageRating!.toStringAsFixed(1), result.reviewCount!)),
      availabilityLabel: result.hasOpenAvailability ? l10n.availableTodayLabel : null,
      onTap: onTap,
      layout: layout,
      width: width,
    );
  }
}
