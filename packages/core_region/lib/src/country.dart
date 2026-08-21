/// Mirrors the backend's `country` module — one market. Field-for-field
/// match with `CountryDtos.CountryResponse` (backend/country/...), so a
/// future `GET /api/v1/countries/{code}` response parses straight into
/// this with no translation layer of its own.
class Country {
  final String code;
  final String name;
  final String defaultLanguage;
  final List<String> supportedLanguages;
  final String currency;
  final String timezone;
  final String numberFormat;
  final String dateFormat;
  final String status;

  const Country({
    required this.code,
    required this.name,
    required this.defaultLanguage,
    required this.supportedLanguages,
    required this.currency,
    required this.timezone,
    required this.numberFormat,
    required this.dateFormat,
    required this.status,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      code: json['code'] as String,
      name: json['name'] as String,
      defaultLanguage: json['defaultLanguage'] as String,
      supportedLanguages: (json['supportedLanguages'] as List<dynamic>).cast<String>(),
      currency: json['currency'] as String,
      timezone: json['timezone'] as String,
      numberFormat: json['numberFormat'] as String,
      dateFormat: json['dateFormat'] as String,
      status: json['status'] as String,
    );
  }
}
