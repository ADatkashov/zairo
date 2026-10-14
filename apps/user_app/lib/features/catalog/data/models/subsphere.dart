/// A "subsphere" under a [BusinessType] (e.g. Hair / Nails under a beauty
/// salon) — the catalog's optional 4th level. Mirrors the backend's
/// `catalog.CatalogDtos.SubsphereResponse`.
class Subsphere {
  final String id;
  final String businessTypeId;
  final String code;
  final String nameKk;
  final String nameRu;
  final String nameEn;
  final int sortOrder;

  const Subsphere({
    required this.id,
    required this.businessTypeId,
    required this.code,
    required this.nameKk,
    required this.nameRu,
    required this.nameEn,
    required this.sortOrder,
  });

  factory Subsphere.fromJson(Map<String, dynamic> json) {
    return Subsphere(
      id: json['id'] as String,
      businessTypeId: json['businessTypeId'] as String,
      code: json['code'] as String,
      nameKk: json['nameKk'] as String,
      nameRu: json['nameRu'] as String,
      nameEn: json['nameEn'] as String,
      sortOrder: json['sortOrder'] as int,
    );
  }

  /// Same locale fallback as `Category.nameFor`.
  String nameFor(String languageCode) {
    switch (languageCode) {
      case 'kk':
        return nameKk;
      case 'ru':
        return nameRu;
      default:
        return nameEn;
    }
  }
}
