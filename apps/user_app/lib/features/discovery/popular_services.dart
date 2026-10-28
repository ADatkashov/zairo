import 'data/models/provider_search_result.dart';

/// One row of Home's "Popular services": a service people can book, not a business.
class PopularService {
  const PopularService({
    required this.title,
    required this.minPrice,
    required this.currency,
    required this.providerCount,
  });

  /// As the first business spelled it ("Haircut", "Манікюр").
  final String title;

  /// The lowest price among everyone offering it.
  final double minPrice;
  final String currency;

  /// How many businesses offer it.
  final int providerCount;
}

/// The services most offered across [results], most businesses first.
///
/// There is no booking-count signal on the client yet (a "most booked in your
/// city" endpoint is a later, backend step), so "popular" here means what the
/// most businesses nearby offer; ties go to the service of the better-rated
/// business. Services are matched by title, ignoring case and spacing.
List<PopularService> popularServices(List<ProviderSearchResult> results, {int limit = 8}) {
  final byTitle = <String, _Tally>{};
  for (final result in results) {
    // One business offering "Haircut" twice still counts once.
    final seen = <String>{};
    for (final service in result.services) {
      final title = service.title.trim();
      if (title.isEmpty) continue;
      final key = title.toLowerCase();
      final tally = byTitle.putIfAbsent(key, () => _Tally(title, service.currency));
      if (service.price < tally.minPrice) tally.minPrice = service.price;
      if (seen.add(key)) {
        tally.providerCount++;
        final rating = result.averageRating ?? 0;
        if (rating > tally.bestRating) tally.bestRating = rating;
      }
    }
  }
  final tallies = byTitle.values.toList()
    ..sort((a, b) {
      final byCount = b.providerCount.compareTo(a.providerCount);
      if (byCount != 0) return byCount;
      final byRating = b.bestRating.compareTo(a.bestRating);
      return byRating != 0 ? byRating : a.title.compareTo(b.title);
    });
  return [
    for (final t in tallies.take(limit))
      PopularService(title: t.title, minPrice: t.minPrice, currency: t.currency, providerCount: t.providerCount),
  ];
}

class _Tally {
  _Tally(this.title, this.currency);

  final String title;
  final String currency;
  double minPrice = double.infinity;
  int providerCount = 0;
  double bestRating = 0;
}
