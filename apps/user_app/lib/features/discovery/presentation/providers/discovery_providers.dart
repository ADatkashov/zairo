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
