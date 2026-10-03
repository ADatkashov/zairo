/// Mirrors backend's ProviderDtos.ProviderResponse
/// (backend/providers/.../ProviderDtos.java). Named AdminProvider, not
/// Provider, to avoid colliding with Riverpod's own `Provider<T>` type.
class AdminProvider {
  final String id;
  final String ownerUserId;
  final String name;
  final String vertical;
  final String status;
  final double? latitude;
  final double? longitude;
  final String? coverPhotoUrl;
  final String? cityCode;

  const AdminProvider({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.vertical,
    required this.status,
    this.latitude,
    this.longitude,
    this.coverPhotoUrl,
    this.cityCode,
  });

  factory AdminProvider.fromJson(Map<String, dynamic> json) {
    return AdminProvider(
      id: json['id'] as String,
      ownerUserId: json['ownerUserId'] as String,
      name: json['name'] as String,
      vertical: json['vertical'] as String,
      status: json['status'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      coverPhotoUrl: json['coverPhotoUrl'] as String?,
      cityCode: json['cityCode'] as String?,
    );
  }
}
