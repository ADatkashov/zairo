import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/links/external_links.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/geo_point.dart';
import '../../data/map_provider.dart';
import '../providers/maps_providers.dart';

/// A provider's location — a real interactive map (2GIS, else Google) once
/// a map API key is configured (see `mapRendererProvider`), a static placeholder
/// otherwise. The renderer swap is the whole point of the `MapRenderer`
/// abstraction: this screen never has to know or care which one it got.
class ProviderMapScreen extends ConsumerWidget {
  final String providerName;
  final double latitude;
  final double longitude;
  final double? distanceKm;

  const ProviderMapScreen({
    super.key,
    required this.providerName,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final renderer = ref.watch(mapRendererProvider);
    final target = GeoPoint(latitude: latitude, longitude: longitude, label: providerName);

    return Scaffold(
      appBar: FactoryAppBar(title: providerName),
      body: Column(
        children: [
          Expanded(child: renderer.build(context, target: target, targetLabel: providerName)),
          if (distanceKm != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(l10n.mapDistanceFromYou(distanceKm!.toStringAsFixed(1))),
            ),
          // 2GIS is what most people in Kazakhstan use, so it is the primary
          // action; Google Maps stays available as the alternative.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _open(MapProvider.twoGis),
                      child: Text(l10n.mapOpenIn2gis),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _open(MapProvider.google),
                      child: Text(l10n.mapOpenInGoogle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _open(MapProvider provider) {
    launchUrl(
      ExternalLinks.showOnMap(latitude: latitude, longitude: longitude, provider: provider),
      mode: LaunchMode.externalApplication,
    );
  }
}
