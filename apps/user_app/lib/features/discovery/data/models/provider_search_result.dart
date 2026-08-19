import 'service_summary.dart';

/// Mirrors backend's SearchDtos.ProviderSearchResult
/// (backend/search/.../SearchDtos.java) — returned by
/// GET /api/v1/search/providers.
class ProviderSearchResult {
  final String id;
  final String name;
  final String vertical;
  final String status;
  final bool hasOpenAvailability;
  final double? minPrice;
  final List<ServiceSummary> services;

  const ProviderSearchResult({
    required this.id,
    required this.name,
    required this.vertical,
    required this.status,
    required this.hasOpenAvailability,
    this.minPrice,
    required this.services,
  });

  factory ProviderSearchResult.fromJson(Map<String, dynamic> json) {
    return ProviderSearchResult(
      id: json['id'] as String,
      name: json['name'] as String,
      vertical: json['vertical'] as String,
      status: json['status'] as String,
      hasOpenAvailability: json['hasOpenAvailability'] as bool,
      minPrice: json['minPrice'] == null
          ? null
          : (json['minPrice'] as num).toDouble(),
      services: (json['services'] as List<dynamic>)
          .map((e) => ServiceSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
