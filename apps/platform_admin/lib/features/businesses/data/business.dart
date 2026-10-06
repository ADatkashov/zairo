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
