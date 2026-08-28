import 'package:flutter/widgets.dart';

import '../../data/geo_point.dart';

/// Port for "draw a map" — mirrors [LocationService]'s port/adapter shape
/// (itself modeled on the backend's `PaymentProvider` pattern, see that
/// class's own doc comment). [MockMapRenderer] is the always-available
/// fallback (today's placeholder visual, also what every CI/test run uses);
/// [GoogleMapsRenderer] is the real implementation, selected only once a
/// Maps API key is actually configured at build time — see
/// `mapRendererProvider` in `maps_providers.dart`.
abstract class MapRenderer {
  Widget build(BuildContext context, {required GeoPoint target, required String targetLabel});
}
