import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../maps/data/geo_point.dart';
import '../../../maps/presentation/providers/maps_providers.dart';
import '../../data/discovery_api.dart';
import '../../data/models/provider_search_result.dart';

final discoveryApiProvider = Provider<DiscoveryApi>((ref) {
  return DiscoveryApi(ref.watch(dioClientProvider));
});

class DiscoveryQuery {
  final String? vertical;
  final String? query;

  const DiscoveryQuery({this.vertical, this.query});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiscoveryQuery &&
          other.vertical == vertical &&
          other.query == query);

  @override
  int get hashCode => Object.hash(vertical, query);
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
  );
});
