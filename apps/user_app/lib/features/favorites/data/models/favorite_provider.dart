import '../../../discovery/data/models/service_summary.dart';

/// Mirrors backend's FavoriteDtos.FavoriteProviderResponse
/// (backend/favorites/.../FavoriteDtos.java) — same shape as discovery's
/// ProviderSearchResult plus favoritedAt, reusing ServiceSummary rather
/// than duplicating an identical model.
class FavoriteProvider {
  final String id;
  final String name;
  final String vertical;
  final String status;
  final bool hasOpenAvailability;
  final double? minPrice;
  final List<ServiceSummary> services;
  final DateTime favoritedAt;

  const FavoriteProvider({
    required this.id,
    required this.name,
    required this.vertical,
    required this.status,
    required this.hasOpenAvailability,
    this.minPrice,
    required this.services,
    required this.favoritedAt,
  });

  factory FavoriteProvider.fromJson(Map<String, dynamic> json) {
    return FavoriteProvider(
      id: json['id'] as String,
      name: json['name'] as String,
      vertical: json['vertical'] as String,
      status: json['status'] as String,
      hasOpenAvailability: json['hasOpenAvailability'] as bool,
      minPrice: json['minPrice'] == null ? null : (json['minPrice'] as num).toDouble(),
      services: (json['services'] as List<dynamic>)
          .map((e) => ServiceSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      favoritedAt: DateTime.parse(json['favoritedAt'] as String),
    );
  }
}
