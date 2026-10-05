/// Mirrors backend's CityDtos.CityDto (snake_case keys on the wire).
class City {
  final String code;
  final String name;
  final String? nameKk;
  final String countryCode;
  final String timezone;
  final String currency;
  final double? latitude;
  final double? longitude;
  final int radiusKm;
  final bool active;

  const City({
    required this.code,
    required this.name,
    this.nameKk,
    required this.countryCode,
    required this.timezone,
    required this.currency,
    this.latitude,
    this.longitude,
    required this.radiusKm,
    required this.active,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      code: json['code'] as String,
      name: json['name'] as String,
      nameKk: json['name_kk'] as String?,
      countryCode: json['country_code'] as String,
      timezone: json['timezone'] as String? ?? '',
      currency: json['currency'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      radiusKm: (json['default_search_radius_km'] as num? ?? 50).toInt(),
      active: json['active'] as bool? ?? true,
    );
  }

  /// The city's name in the app's language (Kazakh when there is one).
  String nameFor(String languageCode) =>
      (languageCode == 'kk' && nameKk != null && nameKk!.isNotEmpty) ? nameKk! : name;
}

/// A market a city can belong to (GET /api/v1/countries) — its timezone and
/// currency prefill a new city.
class CountryOption {
  final String code;
  final String name;
  final String timezone;
  final String currency;

  const CountryOption({required this.code, required this.name, required this.timezone, required this.currency});

  factory CountryOption.fromJson(Map<String, dynamic> json) {
    return CountryOption(
      code: json['code'] as String,
      name: json['name'] as String,
      timezone: json['timezone'] as String? ?? '',
      currency: json['currency'] as String? ?? '',
    );
  }
}
