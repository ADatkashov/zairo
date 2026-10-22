import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../city/data/models/city.dart';
import '../../../city/presentation/providers/city_providers.dart';
import '../../../maps/data/geo_point.dart';
import '../../../maps/presentation/providers/maps_providers.dart';
import '../../data/discovery_api.dart';
import '../../data/models/provider_search_result.dart';

final discoveryApiProvider = Provider<DiscoveryApi>((ref) {
  return DiscoveryApi(ref.watch(dioClientProvider));
});

/// Mirrors the backend's SearchSort enum — [wireValue] is the exact
/// constant name the API expects (Spring's default enum query-param
/// binding is case-sensitive), not Dart's own camelCase [name].
enum DiscoverySort {
  recommended('RECOMMENDED'),
  priceAsc('PRICE_ASC'),
  priceDesc('PRICE_DESC'),
  distance('DISTANCE'),
  rating('RATING');

  const DiscoverySort(this.wireValue);

  final String wireValue;
}

class DiscoveryQuery {
  final String? vertical;
  final String? query;
  final double? minPrice;
  final double? maxPrice;
  final double? maxDistanceKm;
  final double? minRating;
  final bool availableOnly;
  final DiscoverySort sort;

  const DiscoveryQuery({
    this.vertical,
    this.query,
    this.minPrice,
    this.maxPrice,
    this.maxDistanceKm,
    this.minRating,
    this.availableOnly = false,
    this.sort = DiscoverySort.recommended,
  });

  bool get hasActiveFilters =>
      vertical != null ||
      minPrice != null ||
      maxPrice != null ||
      maxDistanceKm != null ||
      minRating != null ||
      availableOnly;

  DiscoveryQuery copyWith({
    String? query,
    String? vertical,
    double? minPrice,
    double? maxPrice,
    double? maxDistanceKm,
    double? minRating,
    bool? availableOnly,
    DiscoverySort? sort,
    bool clearQuery = false,
    bool clearVertical = false,
    bool clearPriceRange = false,
    bool clearMaxDistance = false,
    bool clearMinRating = false,
  }) {
    return DiscoveryQuery(
      vertical: clearVertical ? null : (vertical ?? this.vertical),
      query: clearQuery ? null : (query ?? this.query),
      minPrice: clearPriceRange ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPriceRange ? null : (maxPrice ?? this.maxPrice),
      maxDistanceKm: clearMaxDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      availableOnly: availableOnly ?? this.availableOnly,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiscoveryQuery &&
          other.vertical == vertical &&
          other.query == query &&
          other.minPrice == minPrice &&
          other.maxPrice == maxPrice &&
          other.maxDistanceKm == maxDistanceKm &&
          other.minRating == minRating &&
          other.availableOnly == availableOnly &&
          other.sort == sort);

  @override
  int get hashCode => Object.hash(
    vertical,
    query,
    minPrice,
    maxPrice,
    maxDistanceKm,
    minRating,
    availableOnly,
    sort,
  );
}

/// The price scale the filter's range slider runs over: the cheapest and the
/// dearest provider in a search, rounded outwards to a [step] that suits the
/// spread. Prices here are the providers' `minPrice` — the very number the
/// backend's `minPrice`/`maxPrice` filter compares against — so the ends of
/// the slider are always reachable and never exclude a provider on their own.
class PriceBounds {
  final double min;
  final double max;
  final double step;
  final String? currency;

  const PriceBounds({required this.min, required this.max, required this.step, this.currency});

  /// null when there is nothing to choose between (no priced provider, or all
  /// of them cost the same).
  static PriceBounds? fromResults(List<ProviderSearchResult> results) {
    final prices = [for (final r in results) if (r.minPrice != null) r.minPrice!];
    if (prices.isEmpty) return null;
    final lowest = prices.reduce((a, b) => a < b ? a : b);
    final highest = prices.reduce((a, b) => a > b ? a : b);
    final span = highest - lowest;
    final step = span >= 50000 ? 1000.0 : span >= 5000 ? 500.0 : span >= 500 ? 50.0 : span >= 50 ? 5.0 : 1.0;
    final min = (lowest / step).floor() * step;
    final max = (highest / step).ceil() * step;
    if (max <= min) return null;
    String? currency;
    for (final r in results) {
      if (r.services.isNotEmpty) {
        currency = r.services.first.currency;
        break;
      }
    }
    return PriceBounds(min: min, max: max, step: step, currency: currency);
  }

  int get divisions => ((max - min) / step).round();
}

/// One catalog service's providers, for the Service Compare screen — a
/// separate small provider rather than folding catalogServiceId into
/// [DiscoveryQuery] (whose every other field is customer-typed filters, not
/// a fixed browse target chosen by tapping a catalog entry).
final serviceCompareResultsProvider = FutureProvider.autoDispose
    .family<List<ProviderSearchResult>, String>((ref, catalogServiceId) {
  return ref.watch(discoveryApiProvider).searchProviders(
    catalogServiceId: catalogServiceId,
    sort: DiscoverySort.recommended.wireValue,
  );
});

final searchResultsProvider = FutureProvider.autoDispose
    .family<List<ProviderSearchResult>, DiscoveryQuery>((ref, params) async {
  final api = ref.watch(discoveryApiProvider);
  // Best-effort: if the (mocked) location lookup fails for any reason,
  // search still works, just without distance ranking/display.
  GeoPoint? location;
  try {
    location = await ref.watch(currentLocationProvider.future);
  } catch (_) {
    location = null;
  }
  // Likewise best-effort: a city that can't be worked out is not a reason to hide the businesses meant for everyone.
  final city = await ref.watch(userCurrentCityProvider.future).then<City?>((c) => c, onError: (_) => null);
  return api.searchProviders(
    cityCode: city?.code,
    vertical: params.vertical,
    query: params.query,
    lat: location?.latitude,
    lng: location?.longitude,
    minPrice: params.minPrice,
    maxPrice: params.maxPrice,
    maxDistanceKm: params.maxDistanceKm,
    minRating: params.minRating,
    availableOnly: params.availableOnly,
    sort: params.sort.wireValue,
  );
});
