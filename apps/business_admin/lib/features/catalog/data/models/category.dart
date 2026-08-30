/// One row of the platform master catalog's top level — mirrors the
/// backend's `catalog.CatalogDtos.CategoryResponse`.
class Category {
  final String id;
  final String code;
  final String nameKk;
  final String nameRu;
  final String nameEn;
  final String? icon;
  final int sortOrder;
  final String status;

  const Category({
    required this.id,
    required this.code,
    required this.nameKk,
    required this.nameRu,
    required this.nameEn,
    required this.icon,
    required this.sortOrder,
    required this.status,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      code: json['code'] as String,
      nameKk: json['nameKk'] as String,
      nameRu: json['nameRu'] as String,
      nameEn: json['nameEn'] as String,
      icon: json['icon'] as String?,
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
