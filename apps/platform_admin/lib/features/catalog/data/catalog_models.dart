/// The four rows of the master catalog, top to bottom: a category holds
/// spheres (business types), a sphere holds subspheres and services.
enum CatalogLevel { category, sphere, subsphere, service }

/// One row of the catalog at any level — mirrors backend's
/// `catalog.CatalogDtos` responses (Category / BusinessType / Subsphere /
/// CatalogService), which share this shape apart from a few optional fields.
class CatalogNode {
  final String id;
  final CatalogLevel level;

  /// null for a service — services have no code of their own.
  final String? code;
  final String nameKk;
  final String nameRu;
  final String nameEn;
  final String? icon;
  final int sortOrder;
  final String status;

  /// A service's subsphere, when it hangs under one instead of the sphere.
  final String? subsphereId;

  const CatalogNode({
    required this.id,
    required this.level,
    this.code,
    required this.nameKk,
    required this.nameRu,
    required this.nameEn,
    this.icon,
    required this.sortOrder,
    required this.status,
    this.subsphereId,
  });

  factory CatalogNode.fromJson(CatalogLevel level, Map<String, dynamic> json) {
    return CatalogNode(
      id: json['id'] as String,
      level: level,
      code: json['code'] as String?,
      nameKk: json['nameKk'] as String,
      nameRu: json['nameRu'] as String,
      nameEn: json['nameEn'] as String,
      icon: json['icon'] as String?,
      sortOrder: (json['sortOrder'] as num? ?? 0).toInt(),
      status: json['status'] as String,
      subsphereId: json['subsphereId'] as String?,
    );
  }

  String nameFor(String languageCode) => switch (languageCode) {
    'kk' => nameKk,
    'ru' => nameRu,
    _ => nameEn,
  };

  /// "💅 Beauty" for a category, plain name for everything else.
  String titleFor(String languageCode) {
    final name = nameFor(languageCode);
    final icon = this.icon;
    return (level == CatalogLevel.category && icon != null && icon.isNotEmpty) ? '$icon $name' : name;
  }

  bool get isActive => status == 'ACTIVE';
}
