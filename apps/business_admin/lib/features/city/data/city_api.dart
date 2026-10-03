import 'package:core_network/core_network.dart';

import 'models/city.dart';

class CityApi {
  final DioClient _dioClient;

  CityApi(this._dioClient);

  /// Get all active cities for a specific country
  Future<List<City>> getActiveCitiesByCountry(String countryCode) async {
    final response = await _dioClient.get(
      '/cities/country/$countryCode/active',
    );

    final data = response.data as List<dynamic>;
    return data.map((e) => City.fromJson(e as Map<String, dynamic>)).toList();
  }
}
