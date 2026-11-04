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
  final double? distanceKm;
  final double? latitude;
  final double? longitude;
  final double? averageRating;
  final int? reviewCount;
  final DateTime? nextAvailableSlot;
  final String? coverPhotoUrl;
  final String? address;
  final String? phone;
  final String? description;

  /// Opening hours by weekday key (`mon`..`sun` -> `HH:mm-HH:mm`); a missing day is closed; empty = not stated.
  final Map<String, String> workingHours;

  const ProviderSearchResult({
    required this.id,
    required this.name,
    required this.vertical,
    required this.status,
    required this.hasOpenAvailability,
    this.minPrice,
    required this.services,
    this.distanceKm,
    this.latitude,
    this.longitude,
    this.averageRating,
    this.reviewCount,
    this.nextAvailableSlot,
    this.coverPhotoUrl,
    this.address,
    this.phone,
    this.description,
    this.workingHours = const {},
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
      distanceKm: json['distanceKm'] == null
          ? null
          : (json['distanceKm'] as num).toDouble(),
      latitude: json['latitude'] == null ? null : (json['latitude'] as num).toDouble(),
      longitude: json['longitude'] == null ? null : (json['longitude'] as num).toDouble(),
      averageRating: json['averageRating'] == null
          ? null
          : (json['averageRating'] as num).toDouble(),
      reviewCount: json['reviewCount'] == null
          ? null
          : (json['reviewCount'] as num).toInt(),
      nextAvailableSlot: json['nextAvailableSlot'] == null
          ? null
          : DateTime.parse(json['nextAvailableSlot'] as String),
      coverPhotoUrl: json['coverPhotoUrl'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      description: json['description'] as String?,
      workingHours: {
        for (final e in ((json['workingHours'] as Map<String, dynamic>?) ?? const <String, dynamic>{}).entries)
          e.key: e.value as String,
      },
    );
  }
}
