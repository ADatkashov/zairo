import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Stands in for a real interactive map (Google Maps/Mapbox/OSM) until the
/// project has a real map provider account/API key — see
/// docs and SESSION_NOTES.md. Shows the provider's coordinates as plain
/// text/a static pin illustration rather than real map tiles.
class MockMapScreen extends StatelessWidget {
  final String providerName;
  final double latitude;
  final double longitude;
  final double? distanceKm;

  const MockMapScreen({
    super.key,
    required this.providerName,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: FactoryAppBar(title: providerName),
      body: Center(
        child: Padding(
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
                  Icons.location_on,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.mapPlaceholderTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.mapPlaceholderMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text('${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'),
              if (distanceKm != null) ...[
                const SizedBox(height: 4),
                Text(l10n.mapDistanceFromYou(distanceKm!.toStringAsFixed(1))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
