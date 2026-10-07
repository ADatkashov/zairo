import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/maps/data/geo_point.dart';
import 'package:zairo/features/maps/presentation/widgets/two_gis_maps_renderer.dart';

void main() {
  test('map page centers on [lon, lat] and carries the key', () {
    final html = buildTwoGisMapHtml(
      apiKey: 'abc',
      target: const GeoPoint(latitude: 43.2389, longitude: 76.8897),
      targetLabel: 'Glow',
    );

    expect(html, contains('center: [76.8897,43.2389]'));
    expect(html, contains('key: "abc"'));
    expect(html, contains('text: "Glow"'));
  });

  test('a provider name cannot break out of the script', () {
    final html = buildTwoGisMapHtml(
      apiKey: 'abc',
      target: const GeoPoint(latitude: 1, longitude: 2),
      targetLabel: '</script><script>alert(1)</script>',
    );

    expect(html, isNot(contains('</script><script>alert')));
  });
}
