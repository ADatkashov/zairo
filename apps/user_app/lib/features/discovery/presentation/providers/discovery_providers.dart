import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    .family<List<ProviderSearchResult>, DiscoveryQuery>((ref, params) {
  final api = ref.watch(discoveryApiProvider);
  return api.searchProviders(vertical: params.vertical, query: params.query);
});
