import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/geo_point.dart';
import '../../data/location_service.dart';
import '../widgets/google_maps_renderer.dart';
import '../widgets/map_renderer.dart';
import '../widgets/mock_map_renderer.dart';

/// Defaults to the mock so every widget test that doesn't explicitly care
/// about location keeps working unmodified (same reasoning as
/// networkConfigProvider's own default) — main.dart overrides this to
/// [DeviceLocationService] for the real running app.
final locationServiceProvider = Provider<LocationService>((ref) {
  return MockLocationService();
});

final currentLocationProvider = FutureProvider.autoDispose<GeoPoint>((ref) {
  return ref.watch(locationServiceProvider).getCurrentLocation();
});

/// Set via `--dart-define=MAPS_API_KEY=...` at build time — never
/// hardcoded, never committed, same rule the backend follows for its own
/// secrets (Freedom Pay, JWT). This only decides which [MapRenderer] Dart
/// selects; the *native* Google Maps SDK needs the same key delivered
/// separately at the platform layer (Android reads a `MAPS_API_KEY`
/// environment variable in android/app/build.gradle.kts; iOS reads it from
/// Info.plist in AppDelegate.swift) — both have to be set together for
/// [GoogleMapsRenderer] to actually render tiles, not just get selected.
///
/// Empty by default, which is also what every CI/test run sees — falls
/// back to [MockMapRenderer], never constructs a real `GoogleMap` widget
/// without a key (that needs a live platform channel `flutter test`
/// doesn't have).
const _mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

final mapRendererProvider = Provider<MapRenderer>((ref) {
  return _mapsApiKey.isEmpty ? MockMapRenderer() : GoogleMapsRenderer();
});
