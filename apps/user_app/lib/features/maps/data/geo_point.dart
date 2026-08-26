class GeoPoint {
  final double latitude;
  final double longitude;

  /// A human-readable place name for this point ("Almaty"), when the
  /// [LocationService] that produced it has one to give (a real reverse-geocoding
  /// implementation would always have one; [MockLocationService] hardcodes its
  /// single fixed point's name). Null means "no label available" — callers
  /// showing this fall back to a generic string, not a blank label.
  final String? label;

  const GeoPoint({required this.latitude, required this.longitude, this.label});
}
