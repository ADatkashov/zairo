/// A "sphere" under a [Category] — mirrors the backend's
/// `catalog.CatalogDtos.BusinessTypeResponse`.
class BusinessType {
  final String id;
  final String categoryId;
  final String code;
  final String nameKk;
  final String nameRu;
  final String nameEn;
  final int sortOrder;
  final String status;

  const BusinessType({
    required this.id,
    required this.categoryId,
    required this.code,
    required this.nameKk,
    required this.nameRu,
    required this.nameEn,
    required this.sortOrder,
    required this.status,
  });

  factory BusinessType.fromJson(Map<String, dynamic> json) {
    return BusinessType(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      code: json['code'] as String,
      nameKk: json['nameKk'] as String,
      nameRu: json['nameRu'] as String,
      nameEn: json['nameEn'] as String,
      sortOrder: json['sortOrder'] as int,
      status: json['status'] as String,
    );
  }

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
