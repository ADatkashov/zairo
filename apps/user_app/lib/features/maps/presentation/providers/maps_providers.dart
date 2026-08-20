import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/geo_point.dart';
import '../../data/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return MockLocationService();
});

final currentLocationProvider = FutureProvider.autoDispose<GeoPoint>((ref) {
  return ref.watch(locationServiceProvider).getCurrentLocation();
});
