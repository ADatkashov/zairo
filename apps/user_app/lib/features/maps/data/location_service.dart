import 'geo_point.dart';

/// Port for "where is the user right now" — mirrors the
/// PaymentProvider pattern on the backend (features/payments): a real
/// implementation would wrap the `geolocator` package (device GPS/browser
/// geolocation), which needs platform permission setup this project
/// hasn't done yet. [MockLocationService] is the only implementation for
/// now; swapping in a real one later means adding one class behind this
/// same interface.
abstract class LocationService {
  Future<GeoPoint> getCurrentLocation();
}

/// Always returns a fixed point (Almaty city center) — matches the
/// coordinates used in the backend's own manual/test verification of
/// distance-based search ranking.
class MockLocationService implements LocationService {
  @override
  Future<GeoPoint> getCurrentLocation() async {
    return const GeoPoint(latitude: 43.2389, longitude: 76.8897);
  }
}
