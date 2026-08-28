import 'package:geolocator/geolocator.dart';

import 'geo_point.dart';

/// Port for "where is the user right now" — mirrors the backend's
/// `PaymentProvider` pattern. [MockLocationService] exists for tests (and
/// as a controllable fixed point); [DeviceLocationService] is the real
/// implementation, wrapping the `geolocator` package (device GPS/browser
/// geolocation) — see `mapRendererProvider`'s doc comment for the matching
/// map-rendering side of this same "mock unless real is wired in" split.
abstract class LocationService {
  Future<GeoPoint> getCurrentLocation();
}

/// Always returns a fixed point (Almaty city center) — matches the
/// coordinates used in the backend's own manual/test verification of
/// distance-based search ranking.
class MockLocationService implements LocationService {
  @override
  Future<GeoPoint> getCurrentLocation() async {
    return const GeoPoint(latitude: 43.2389, longitude: 76.8897, label: 'Almaty');
  }
}

/// Real device location via `geolocator` — no reverse-geocoding (coords ->
/// place name) here, so [GeoPoint.label] is always null for this
/// implementation; callers already treat a null label as "show a generic
/// fallback", not an error (see home_screen.dart). Reverse geocoding is a
/// separate, deliberately deferred feature, same reasoning as the
/// forward-geocoding gap already called out in the roadmap (Phase 2).
///
/// Throws if location services are disabled or permission is denied —
/// callers already treat a failed lookup as "no location, degrade
/// gracefully" (see discovery_providers.dart's searchResultsProvider,
/// home_screen.dart's use of `.valueOrNull`).
class DeviceLocationService implements LocationService {
  @override
  Future<GeoPoint> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Location services are disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw StateError('Location permission denied');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
    return GeoPoint(latitude: position.latitude, longitude: position.longitude);
  }
}
