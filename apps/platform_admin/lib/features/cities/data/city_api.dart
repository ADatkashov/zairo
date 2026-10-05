import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/platform_http.dart';
import 'city.dart';

/// Reads are the public `/cities` (every city, inactive included);
/// create / update / delete are `/platform/cities`, PLATFORM_ADMIN-only.
class CityApi {
  final Dio _dio;

  CityApi(this._dio);

  Future<List<City>> list() async {
    final response = await _dio.get('/cities');
    return (response.data as List<dynamic>).map((e) => City.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CountryOption>> countries() async {
    final response = await _dio.get('/countries');
    return (response.data as List<dynamic>).map((e) => CountryOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<City> create({
    required String code,
    required String name,
    required String nameKk,
    required String countryCode,
    required String timezone,
    required String currency,
    double? latitude,
    double? longitude,
    required int radiusKm,
  }) async {
    final response = await _dio.post(
      '/platform/cities',
      data: {
        'code': code,
        'name': name,
        'name_kk': nameKk,
        'country_code': countryCode,
        'timezone': timezone,
        'currency': currency,
        'latitude': latitude,
        'longitude': longitude,
        'default_search_radius_km': radiusKm,
      },
    );
    return City.fromJson(response.data as Map<String, dynamic>);
  }

  /// The backend overwrites every field on update (a missing one becomes
  /// null), so always send the whole city.
  Future<City> update(
    City city, {
    String? name,
    String? nameKk,
    String? timezone,
    String? currency,
    double? latitude,
    double? longitude,
    int? radiusKm,
    bool? active,
  }) async {
    final response = await _dio.put(
      '/platform/cities/${city.code}',
      data: {
        'name': name ?? city.name,
        'name_kk': nameKk ?? city.nameKk,
        'timezone': timezone ?? city.timezone,
        'currency': currency ?? city.currency,
        'latitude': latitude ?? city.latitude,
        'longitude': longitude ?? city.longitude,
        'default_search_radius_km': radiusKm ?? city.radiusKm,
        'active': active ?? city.active,
      },
    );
    return City.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String code) async {
    await _dio.delete('/platform/cities/$code');
  }
}

final cityApiProvider = Provider<CityApi>((ref) => CityApi(ref.watch(platformDioProvider)));

final citiesProvider = FutureProvider.autoDispose<List<City>>((ref) => ref.watch(cityApiProvider).list());

final countriesProvider = FutureProvider.autoDispose<List<CountryOption>>(
  (ref) => ref.watch(cityApiProvider).countries(),
);
