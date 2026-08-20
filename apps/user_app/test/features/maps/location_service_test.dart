import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/maps/data/location_service.dart';

void main() {
  test('MockLocationService returns a fixed point', () async {
    final location = await MockLocationService().getCurrentLocation();

    expect(location.latitude, 43.2389);
    expect(location.longitude, 76.8897);
  });
}
