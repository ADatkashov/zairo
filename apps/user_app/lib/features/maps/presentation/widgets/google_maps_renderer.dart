import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/geo_point.dart';
import 'map_renderer.dart';

/// Real Google Maps rendering — only ever constructed once a Maps API key
/// is actually configured (see `mapRendererProvider`), so a CI/test run or
/// a local dev environment without a key never touches this widget (it
/// needs a live platform channel to the native Google Maps SDK, which a
/// plain `flutter test` run doesn't have).
///
/// `myLocationEnabled`/`myLocationButtonEnabled` show the device's own
/// position via the native SDK directly — this only requires location
/// permission to already be granted (it doesn't request it itself); by the
/// time a user reaches this screen, `DeviceLocationService` has usually
/// already requested it once, from the Home screen's own location lookup.
class GoogleMapsRenderer implements MapRenderer {
  @override
  Widget build(BuildContext context, {required GeoPoint target, required String targetLabel}) {
    final position = LatLng(target.latitude, target.longitude);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: position, zoom: 14),
      markers: {
        Marker(markerId: const MarkerId('target'), position: position, infoWindow: InfoWindow(title: targetLabel)),
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
}
