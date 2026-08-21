import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  distance('DISTANCE');

  const DiscoverySort(this.wireValue);

  final String wireValue;
}

class DiscoveryQuery {
  final String? vertical;
  final String? query;
  final double? minPrice;
  final double? maxPrice;
  final double? maxDistanceKm;
  final bool availableOnly;
  final DiscoverySort sort;

  const DiscoveryQuery({
    this.vertical,
    this.query,
    this.minPrice,
    this.maxPrice,
    this.maxDistanceKm,
    this.availableOnly = false,
    this.sort = DiscoverySort.recommended,
  });

  bool get hasActiveFilters =>
      minPrice != null || maxPrice != null || maxDistanceKm != null || availableOnly;

  DiscoveryQuery copyWith({
    String? query,
    double? minPrice,
    double? maxPrice,
    double? maxDistanceKm,
    bool? availableOnly,
    DiscoverySort? sort,
    bool clearPriceRange = false,
    bool clearMaxDistance = false,
  }) {
    return DiscoveryQuery(
      vertical: vertical,
      query: query ?? this.query,
      minPrice: clearPriceRange ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPriceRange ? null : (maxPrice ?? this.maxPrice),
      maxDistanceKm: clearMaxDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
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
          other.availableOnly == availableOnly &&
          other.sort == sort);

  @override
  int get hashCode => Object.hash(
    vertical,
    query,
    minPrice,
    maxPrice,
    maxDistanceKm,
    availableOnly,
    sort,
  );
}

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
  return api.searchProviders(
    vertical: params.vertical,
    query: params.query,
    lat: location?.latitude,
    lng: location?.longitude,
    minPrice: params.minPrice,
    maxPrice: params.maxPrice,
    maxDistanceKm: params.maxDistanceKm,
    availableOnly: params.availableOnly,
    sort: params.sort.wireValue,
  );
});
