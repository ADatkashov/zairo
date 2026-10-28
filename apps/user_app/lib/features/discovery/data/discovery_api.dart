import 'package:core_network/core_network.dart';

import '../popular_services.dart';
import 'models/provider_search_result.dart';
import 'models/recommended_provider.dart';

/// Not marked final/sealed on purpose: tests substitute a subclass that
/// overrides [searchProviders] instead of hitting the network — see
/// discovery_providers.dart's discoveryApiProvider override in
/// discovery_screen_test.dart.
class DiscoveryApi {
  final DioClient _dioClient;

  DiscoveryApi(this._dioClient);

  Future<List<ProviderSearchResult>> searchProviders({
    String? vertical,
    String? businessTypeId,
    String? catalogServiceId,
    String? query,
    double? lat,
    double? lng,
    double? minPrice,
    double? maxPrice,
    double? maxDistanceKm,
    double? minRating,
    bool availableOnly = false,
    String? sort,
    String? cityCode,
  }) async {
    final response = await _dioClient.get(
      '/search/providers',
      queryParameters: {
        if (vertical != null && vertical.isNotEmpty) 'vertical': vertical,
        'businessTypeId': ?businessTypeId,
        'catalogServiceId': ?catalogServiceId,
        if (query != null && query.isNotEmpty) 'q': query,
        if (lat != null && lng != null) 'lat': lat,
        if (lat != null && lng != null) 'lng': lng,
        'minPrice': ?minPrice,
        'maxPrice': ?maxPrice,
        'maxDistanceKm': ?maxDistanceKm,
        'minRating': ?minRating,
        if (availableOnly) 'availableOnly': true,
        'sort': ?sort,
        if (cityCode != null && cityCode.isNotEmpty) 'city': cityCode,
      },
    );

    final data = response.data as List<dynamic>;
    return data
        .map((e) => ProviderSearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The services customers booked most lately (GET /search/popular-services), most booked first; empty while the
  /// platform has no bookings yet.
  Future<List<PopularService>> popularServices({String? cityCode, int limit = 8}) async {
    final response = await _dioClient.get(
      '/search/popular-services',
      queryParameters: {
        if (cityCode != null && cityCode.isNotEmpty) 'city': cityCode,
        'limit': limit,
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => PopularService.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Businesses recommended for [userId], learned from their own bookings (GET /users/{id}/recommendations), in
  /// display order. Empty without booking history.
  Future<List<RecommendedProvider>> recommendations(String userId, {String? cityCode, int limit = 10}) async {
    final response = await _dioClient.get(
      '/users/$userId/recommendations',
      queryParameters: {
        if (cityCode != null && cityCode.isNotEmpty) 'city': cityCode,
        'limit': limit,
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => RecommendedProvider.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
