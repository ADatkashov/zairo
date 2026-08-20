/// Mirrors backend's MasterDtos.MasterResponse
/// (backend/vertical-beauty/.../MasterDtos.java).
class AdminMaster {
  final String id;
  final String providerId;
  final String displayName;
  final String? bio;
  final String? photoUrl;
  final bool active;

  const AdminMaster({
    required this.id,
    required this.providerId,
    required this.displayName,
    this.bio,
    this.photoUrl,
    required this.active,
  });

  factory AdminMaster.fromJson(Map<String, dynamic> json) {
    return AdminMaster(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      displayName: json['displayName'] as String,
      bio: json['bio'] as String?,
      photoUrl: json['photoUrl'] as String?,
      active: json['active'] as bool,
    );
  }
}
