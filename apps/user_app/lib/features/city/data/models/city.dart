import 'package:json_annotation/json_annotation.dart';

part 'city.g.dart';

@JsonSerializable()
class City {
  final String code;
  final String name;
  @JsonKey(name: 'name_kk')
  final String? nameKk;
  @JsonKey(name: 'country_code')
  final String countryCode;
  final String timezone;
  final String currency;
  final double? latitude;
  final double? longitude;
  @JsonKey(name: 'default_search_radius_km')
  final int? defaultSearchRadiusKm;
  final bool active;

  City({
    required this.code,
    required this.name,
    this.nameKk,
    required this.countryCode,
    required this.timezone,
    required this.currency,
    this.latitude,
    this.longitude,
    this.defaultSearchRadiusKm,
    required this.active,
  });

  factory City.fromJson(Map<String, dynamic> json) => _$CityFromJson(json);

  /// The name to show for [languageCode]. The backend only stores an English
  /// and a Kazakh name, so Kazakh gets [nameKk] (when set) and every other
  /// language falls back to [name].
  String nameFor(String languageCode) {
    final kk = nameKk;
    return languageCode == 'kk' && kk != null && kk.isNotEmpty ? kk : name;
  }

  Map<String, dynamic> toJson() => _$CityToJson(this);
}
