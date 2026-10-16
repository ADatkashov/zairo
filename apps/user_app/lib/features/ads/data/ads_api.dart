import 'package:core_network/core_network.dart';

import 'models/ad_banner.dart';

/// Not final on purpose: tests substitute a subclass overriding
/// [listBanners] — same pattern as CatalogApi/DiscoveryApi.
class AdsApi {
  final DioClient _dioClient;

  AdsApi(this._dioClient);

  /// Banners live right now for [cityCode] (plus those meant for every city).
  /// Public: a guest gets the same carousel.
  Future<List<AdBanner>> listBanners({String? cityCode}) async {
    final response = await _dioClient.get(
      '/ads/banners',
      queryParameters: {if (cityCode != null && cityCode.isNotEmpty) 'city': cityCode},
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => AdBanner.fromJson(e as Map<String, dynamic>)).toList();
  }
}
