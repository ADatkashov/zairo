/// A named service ("Manicure") under a [BusinessType] (and optionally a
/// Subsphere) — the catalog's leaf level. Mirrors the backend's
/// `catalog.CatalogDtos.CatalogServiceResponse`. Distinct from a business's
/// own `ServiceOffering` (what they actually charge for) — this is the
/// menu of names an admin curates, not a price list.
class CatalogServiceModel {
  final String id;
  final String businessTypeId;
  final String? subsphereId;
  final String nameKk;
  final String nameRu;
  final String nameEn;
  final int sortOrder;
  final String status;

  const CatalogServiceModel({
    required this.id,
    required this.businessTypeId,
    required this.subsphereId,
    required this.nameKk,
    required this.nameRu,
    required this.nameEn,
    required this.sortOrder,
    required this.status,
  });

  factory CatalogServiceModel.fromJson(Map<String, dynamic> json) {
    return CatalogServiceModel(
      id: json['id'] as String,
      businessTypeId: json['businessTypeId'] as String,
      subsphereId: json['subsphereId'] as String?,
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
