/// Mirrors backend's ProviderDtos.ProviderResponse — a business as the
/// platform sees it.
class Business {
  final String id;
  final String ownerUserId;
  final String name;
  final String vertical;
  final String status;
  final DateTime? createdAt;
  final double? latitude;
  final double? longitude;
  final String? businessTypeId;
  final String? coverPhotoUrl;

  const Business({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.vertical,
    required this.status,
    this.createdAt,
    this.latitude,
    this.longitude,
    this.businessTypeId,
    this.coverPhotoUrl,
  });

  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: json['id'] as String,
      ownerUserId: json['ownerUserId'] as String,
      name: json['name'] as String,
      vertical: json['vertical'] as String,
      status: json['status'] as String,
      createdAt: json['createdAt'] == null ? null : DateTime.parse(json['createdAt'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      businessTypeId: json['businessTypeId'] as String?,
      coverPhotoUrl: json['coverPhotoUrl'] as String?,
    );
  }
}

/// Mirrors `GET /platform/businesses/{id}/overview`: who runs a business and
/// how big it is, for the moderator's card.
class BusinessOverview {
  final String? ownerName;
  final String? ownerEmail;
  final String? ownerPhone;
  final int servicesCount;
  final int totalBookings;
  final int completedBookings;

  const BusinessOverview({
    this.ownerName,
    this.ownerEmail,
    this.ownerPhone,
    required this.servicesCount,
    required this.totalBookings,
    required this.completedBookings,
  });

  factory BusinessOverview.fromJson(Map<String, dynamic> json) {
    return BusinessOverview(
      ownerName: json['ownerName'] as String?,
      ownerEmail: json['ownerEmail'] as String?,
      ownerPhone: json['ownerPhone'] as String?,
      servicesCount: (json['servicesCount'] as num).toInt(),
      totalBookings: (json['totalBookings'] as num).toInt(),
      completedBookings: (json['completedBookings'] as num).toInt(),
    );
  }
}
