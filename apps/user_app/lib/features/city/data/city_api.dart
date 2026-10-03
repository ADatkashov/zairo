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

  /// Get user's current city
  Future<City> getUserCurrentCity() async {
    final response = await _dioClient.get('/cities/user/current');
    return City.fromJson(response.data as Map<String, dynamic>);
  }

  /// Set user's current city
  Future<City> setUserCurrentCity(String cityCode) async {
    final response = await _dioClient.put(
      '/cities/user/current',
      data: {'city_code': cityCode},
    );
    return City.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get nearest city by coordinates
  Future<City> getNearestCity(double latitude, double longitude) async {
    final response = await _dioClient.get(
      '/cities/nearest',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    return City.fromJson(response.data as Map<String, dynamic>);
  }
}
