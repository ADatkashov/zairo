import 'package:core_ui/core_ui.dart' as core_ui;
import 'package:flutter/material.dart';

import '../../data/models/provider_search_result.dart';

/// Adapts a backend search result to Factory's shared `core_ui.ProviderCard`
/// — kept as this app's own thin wrapper (rather than every call site
/// importing core_ui and mapping fields itself) so the
/// ProviderSearchResult -> card-field mapping lives in exactly one place.
/// Search doesn't return a rating yet (see SearchService's javadoc), so the
/// rating row is simply omitted — core_ui.ProviderCard already handles a
/// null rating by not rendering it, no placeholder value invented here.
class ProviderCard extends StatelessWidget {
  final ProviderSearchResult result;
  final VoidCallback? onTap;
  final core_ui.ProviderCardLayout layout;
  final double? width;

  const ProviderCard({
    super.key,
    required this.result,
    this.onTap,
    this.layout = core_ui.ProviderCardLayout.horizontal,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return core_ui.ProviderCard(
      title: result.name,
      metaText: result.distanceKm != null
          ? '${result.distanceKm!.toStringAsFixed(1)} km · ${result.vertical}'
          : result.vertical,
      priceFrom: result.minPrice,
      availabilityLabel: result.hasOpenAvailability ? 'Available today' : null,
      onTap: onTap,
      layout: layout,
      width: width,
    );
  }
}
