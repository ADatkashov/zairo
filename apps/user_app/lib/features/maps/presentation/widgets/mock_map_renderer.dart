import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/geo_point.dart';
import 'map_renderer.dart';

/// Stands in for a real interactive map — selected whenever no Maps API
/// key is configured (see `mapRendererProvider`), which is every CI/test
/// run and any local dev environment before a real key is wired in. Shows
/// the target's coordinates as plain text/a static pin illustration rather
/// than real map tiles.
class MockMapRenderer implements MapRenderer {
  @override
  Widget build(
    BuildContext context, {
    required GeoPoint target,
    required String targetLabel,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Scrolls on a short screen (large text, landscape) instead of overflowing.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Icon(
                Symbols.location_on_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.mapPlaceholderTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.mapPlaceholderMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              '${target.latitude.toStringAsFixed(4)}, ${target.longitude.toStringAsFixed(4)}',
            ),
          ],
        ),
      ),
    );
  }
}
