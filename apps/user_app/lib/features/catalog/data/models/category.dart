/// One row of the platform master catalog's top level — mirrors the
/// backend's `catalog.CatalogDtos.CategoryResponse`. `code` is the stable,
/// non-localized slug (`"beauty"`) still passed to the existing
/// vertical-based search filter; `nameKk`/`nameRu`/`nameEn` are picked from
/// client-side based on the current locale, same as everywhere else in this
/// app that resolves display text (search integration with the catalog's
/// own multilingual names is a later phase — see the ADR).
class Category {
  final String id;
  final String code;
  final String nameKk;
  final String nameRu;
  final String nameEn;
  final int sortOrder;

  const Category({
    required this.id,
    required this.code,
    required this.nameKk,
    required this.nameRu,
    required this.nameEn,
    required this.sortOrder,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      code: json['code'] as String,
      nameKk: json['nameKk'] as String,
      nameRu: json['nameRu'] as String,
      nameEn: json['nameEn'] as String,
      sortOrder: json['sortOrder'] as int,
    );
  }

  /// Picks the display name for [languageCode] (`"kk"`/`"ru"`/anything
  /// else falls back to English) — the same three locales this app already
  /// ships (see `l10n/app_{en,ru,kk}.arb`).
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
