num _percent(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? 0;
  return 0;
}

/// Mirrors backend's CommissionDtos.CategoryCommission: one category, its own
/// override (null = follows the default) and the rate actually in effect.
class CategoryCommission {
  final String categoryId;
  final String code;
  final String nameKk;
  final String nameRu;
  final String nameEn;
  final num? overridePercent;
  final num effectivePercent;

  const CategoryCommission({
    required this.categoryId,
    required this.code,
    required this.nameKk,
    required this.nameRu,
    required this.nameEn,
    required this.overridePercent,
    required this.effectivePercent,
  });

  bool get hasOverride => overridePercent != null;

  String displayName(String languageCode) => switch (languageCode) {
    'ru' => nameRu,
    'kk' => nameKk,
    _ => nameEn,
  };

  factory CategoryCommission.fromJson(Map<String, dynamic> json) {
    return CategoryCommission(
      categoryId: json['categoryId'] as String,
      code: json['code'] as String,
      nameKk: json['nameKk'] as String,
      nameRu: json['nameRu'] as String,
      nameEn: json['nameEn'] as String,
      overridePercent: json['overridePercent'] == null ? null : _percent(json['overridePercent']),
      effectivePercent: _percent(json['effectivePercent']),
    );
  }
}

/// Mirrors backend's CommissionDtos.CommissionSettingsResponse (percent values).
class CommissionSettings {
  final num defaultPercent;
  final List<CategoryCommission> categories;

  const CommissionSettings({required this.defaultPercent, required this.categories});

  factory CommissionSettings.fromJson(Map<String, dynamic> json) {
    return CommissionSettings(
      defaultPercent: _percent(json['defaultPercent']),
      categories: (json['categories'] as List<dynamic>)
          .map((e) => CategoryCommission.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// "10", "7.5" — trailing zeros dropped, always followed by a percent sign.
String formatPercent(num value) {
  final text = value == value.roundToDouble() ? value.round().toString() : value.toString();
  return '$text%';
}

/// Parses what an admin typed ("7,5" or "7.5"); null unless it is a number in
/// 0..100 with at most 2 decimals (what the backend accepts).
num? parsePercentInput(String input) {
  final text = input.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(text)) return null;
  final value = num.parse(text);
  return value >= 0 && value <= 100 ? value : null;
}
