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
  final String? address;
  final String? phone;
  final String? description;

  /// Opening hours by weekday key (`mon`..`sun` -> `HH:mm-HH:mm`); a missing day is closed; empty = not stated.
  final Map<String, String> workingHours;

  /// The master-catalog business type this business resolved to — drives which
  /// catalog services it can pick from. Null for businesses that predate the
  /// catalog.
  final String? businessTypeId;

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
    this.businessTypeId,
    this.address,
    this.phone,
    this.description,
    this.workingHours = const {},
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
      businessTypeId: json['businessTypeId'] as String?,
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
