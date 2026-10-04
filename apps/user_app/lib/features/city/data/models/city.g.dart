// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'city.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

City _$CityFromJson(Map<String, dynamic> json) => City(
  code: json['code'] as String,
  name: json['name'] as String,
  nameKk: json['name_kk'] as String?,
  countryCode: json['country_code'] as String,
  timezone: json['timezone'] as String,
  currency: json['currency'] as String,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  defaultSearchRadiusKm: (json['default_search_radius_km'] as num?)?.toInt(),
  active: json['active'] as bool,
);

Map<String, dynamic> _$CityToJson(City instance) => <String, dynamic>{
  'code': instance.code,
  'name': instance.name,
  'name_kk': instance.nameKk,
  'country_code': instance.countryCode,
  'timezone': instance.timezone,
  'currency': instance.currency,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'default_search_radius_km': instance.defaultSearchRadiusKm,
  'active': instance.active,
};
