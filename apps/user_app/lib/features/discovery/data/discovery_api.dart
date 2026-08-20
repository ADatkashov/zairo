import 'package:core_network/core_network.dart';

import 'models/provider_search_result.dart';

/// Not marked final/sealed on purpose: tests substitute a subclass that
/// overrides [searchProviders] instead of hitting the network — see
/// discovery_providers.dart's discoveryApiProvider override in
/// discovery_screen_test.dart.
class DiscoveryApi {
  final DioClient _dioClient;

  DiscoveryApi(this._dioClient);

  Future<List<ProviderSearchResult>> searchProviders({
    String? vertical,
    String? query,
    double? lat,
    double? lng,
  }) async {
    final response = await _dioClient.get(
      '/search/providers',
      queryParameters: {
        if (vertical != null && vertical.isNotEmpty) 'vertical': vertical,
        if (query != null && query.isNotEmpty) 'q': query,
        if (lat != null && lng != null) 'lat': lat,
        if (lat != null && lng != null) 'lng': lng,
      },
    );

    final data = response.data as List<dynamic>;
    return data
        .map((e) => ProviderSearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
