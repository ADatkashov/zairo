import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/core/links/external_links.dart';

void main() {
  test('addToCalendar pre-fills a UTC event for the visit', () {
    final uri = ExternalLinks.addToCalendar(
      title: 'Haircut · Glow',
      startsAt: DateTime.utc(2026, 10, 7, 9, 30),
      duration: const Duration(minutes: 45),
      location: 'Glow Salon',
    );

    expect(uri.host, 'calendar.google.com');
    expect(uri.queryParameters['action'], 'TEMPLATE');
    expect(uri.queryParameters['text'], 'Haircut · Glow');
    expect(uri.queryParameters['dates'], '20261007T093000Z/20261007T101500Z');
    expect(uri.queryParameters['location'], 'Glow Salon');
    expect(uri.queryParameters.containsKey('details'), isFalse);
  });

  test('directionsTo targets the coordinates', () {
    final uri = ExternalLinks.directionsTo(latitude: 43.238, longitude: 76.945);

    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['destination'], '43.238,76.945');
  });
}
