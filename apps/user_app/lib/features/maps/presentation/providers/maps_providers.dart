import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/geo_point.dart';
import '../../data/location_service.dart';
import '../widgets/google_maps_renderer.dart';
import '../widgets/map_renderer.dart';
import '../widgets/mock_map_renderer.dart';
import '../widgets/two_gis_maps_renderer.dart';

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

/// Set via `--dart-define=TWOGIS_API_KEY=...` at build time — never
/// hardcoded, never committed. 2GIS is the preferred in-app map for
/// Kazakhstan; it needs only this one key (MapGL JS, no native setup).
const _twoGisApiKey = String.fromEnvironment('TWOGIS_API_KEY');

/// Set via `--dart-define=MAPS_API_KEY=...` at build time — same rule as
/// above (and as the backend's own secrets). This only decides which
/// [MapRenderer] Dart selects; the *native* Google Maps SDK needs the same
/// key delivered separately at the platform layer (Android reads a
/// `MAPS_API_KEY` environment variable in android/app/build.gradle.kts; iOS
/// reads it from Info.plist in AppDelegate.swift) — both have to be set
/// together for [GoogleMapsRenderer] to actually render tiles.
const _mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

/// 2GIS first (needs a WebView, which Flutter web doesn't provide), Google
/// Maps as the alternative, and the mock when neither key is configured —
/// which is also what every CI/test run sees (a real map needs platform
/// channels `flutter test` doesn't have).
final mapRendererProvider = Provider<MapRenderer>((ref) {
  if (_twoGisApiKey.isNotEmpty && !kIsWeb) return const TwoGisMapsRenderer(_twoGisApiKey);
  if (_mapsApiKey.isNotEmpty) return GoogleMapsRenderer();
  return MockMapRenderer();
});
