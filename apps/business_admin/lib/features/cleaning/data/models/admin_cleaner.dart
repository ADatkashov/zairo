/// Mirrors backend's CleanerDtos.CleanerResponse
/// (backend/vertical-cleaning/.../CleanerDtos.java).
class AdminCleaner {
  final String id;
  final String providerId;
  final String displayName;
  final String? bio;
  final String? photoUrl;
  final bool active;

  const AdminCleaner({
    required this.id,
    required this.providerId,
    required this.displayName,
    this.bio,
    this.photoUrl,
    required this.active,
  });

  factory AdminCleaner.fromJson(Map<String, dynamic> json) {
    return AdminCleaner(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      displayName: json['displayName'] as String,
      bio: json['bio'] as String?,
      photoUrl: json['photoUrl'] as String?,
      active: json['active'] as bool,
    );
  }
}
