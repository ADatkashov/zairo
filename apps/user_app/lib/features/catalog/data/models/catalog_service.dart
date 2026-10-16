/// A service from the platform master catalog (what a business can offer, e.g.
/// "Manicure") — mirrors the backend's `catalog.CatalogDtos.CatalogServiceResponse`.
/// Its [id] is what the search endpoint's `catalogServiceId` filter takes.
class CatalogService {
  final String id;
  final String businessTypeId;
  final String nameKk;
  final String nameRu;
  final String nameEn;
  final int sortOrder;

  /// The subsphere this service is grouped under, if its sphere has any.
  final String? subsphereId;

  const CatalogService({
    required this.id,
    required this.businessTypeId,
    required this.nameKk,
    required this.nameRu,
    required this.nameEn,
    required this.sortOrder,
    this.subsphereId,
  });

  factory CatalogService.fromJson(Map<String, dynamic> json) {
    return CatalogService(
      id: json['id'] as String,
      businessTypeId: json['businessTypeId'] as String,
      nameKk: json['nameKk'] as String,
      nameRu: json['nameRu'] as String,
      nameEn: json['nameEn'] as String,
      sortOrder: json['sortOrder'] as int,
      subsphereId: json['subsphereId'] as String?,
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
