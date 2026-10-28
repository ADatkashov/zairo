import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/data/models/service_summary.dart';
import 'package:zairo/features/discovery/popular_services.dart';

ServiceSummary _svc(String title, double price, {String currency = 'KZT'}) =>
    ServiceSummary(id: '$title-$price', title: title, durationMinutes: 30, price: price, currency: currency);

ProviderSearchResult _provider(String id, List<ServiceSummary> services, {double? rating}) => ProviderSearchResult(
  id: id,
  name: id,
  vertical: 'beauty',
  status: 'ACTIVE',
  hasOpenAvailability: true,
  services: services,
  averageRating: rating,
);

void main() {
  test('no businesses, no popular services', () {
    expect(popularServices(const []), isEmpty);
    expect(popularServices([_provider('a', const [])]), isEmpty);
  });

  test('the service offered by most businesses comes first, with its lowest price and count', () {
    final result = popularServices([
      _provider('a', [_svc('Haircut', 5000), _svc('Manicure', 7000)]),
      _provider('b', [_svc('Haircut', 4000)]),
      _provider('c', [_svc('haircut ', 6000)]),
    ]);

    expect(result.map((s) => s.title), ['Haircut', 'Manicure']);
    expect(result.first.providerCount, 3);
    expect(result.first.minPrice, 4000);
    expect(result.first.currency, 'KZT');
    expect(result.last.providerCount, 1);
  });

  test('a business that lists the same service twice counts once', () {
    final result = popularServices([
      _provider('a', [_svc('Massage', 9000), _svc('Massage', 12000)]),
    ]);

    expect(result.single.providerCount, 1);
    expect(result.single.minPrice, 9000);
  });

  test('ties go to the better-rated business, then to the title', () {
    final result = popularServices([
      _provider('a', [_svc('Zeta', 1000)], rating: 4.1),
      _provider('b', [_svc('Beta', 1000)], rating: 4.9),
      _provider('c', [_svc('Alpha', 1000)], rating: 4.1),
    ]);

    expect(result.map((s) => s.title), ['Beta', 'Alpha', 'Zeta']);
  });

  test('blank titles are ignored and the list is capped', () {
    final result = popularServices([
      _provider('a', [_svc('  ', 100), for (var i = 0; i < 12; i++) _svc('Service $i', 100.0 + i)]),
    ], limit: 5);

    expect(result, hasLength(5));
    expect(result.any((s) => s.title.trim().isEmpty), isFalse);
  });
}
