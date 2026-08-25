/// Mirrors backend's MechanicDtos.MechanicResponse
/// (backend/vertical-auto/.../MechanicDtos.java).
class AdminMechanic {
  final String id;
  final String providerId;
  final String displayName;
  final String? bio;
  final String? photoUrl;
  final bool active;

  const AdminMechanic({
    required this.id,
    required this.providerId,
    required this.displayName,
    this.bio,
    this.photoUrl,
    required this.active,
  });

  factory AdminMechanic.fromJson(Map<String, dynamic> json) {
    return AdminMechanic(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      displayName: json['displayName'] as String,
      bio: json['bio'] as String?,
      photoUrl: json['photoUrl'] as String?,
      active: json['active'] as bool,
    );
  }
}
