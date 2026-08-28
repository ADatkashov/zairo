import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/geo_point.dart';
import '../providers/maps_providers.dart';

/// A provider's location — a real interactive Google Map once a Maps API
/// key is configured (see `mapRendererProvider`), a static placeholder
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
              padding: const EdgeInsets.all(16),
              child: Text(l10n.mapDistanceFromYou(distanceKm!.toStringAsFixed(1))),
            ),
        ],
      ),
    );
  }
}
