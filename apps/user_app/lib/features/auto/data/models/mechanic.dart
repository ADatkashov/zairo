/// Mirrors backend's MechanicDtos.MechanicResponse
/// (backend/vertical-auto/.../MechanicDtos.java).
class Mechanic {
  final String id;
  final String providerId;
  final String displayName;
  final String? bio;
  final String? photoUrl;
  final bool active;

  const Mechanic({
    required this.id,
    required this.providerId,
    required this.displayName,
    this.bio,
    this.photoUrl,
    required this.active,
  });

  factory Mechanic.fromJson(Map<String, dynamic> json) {
    return Mechanic(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      displayName: json['displayName'] as String,
      bio: json['bio'] as String?,
      photoUrl: json['photoUrl'] as String?,
      active: json['active'] as bool,
    );
  }
}
