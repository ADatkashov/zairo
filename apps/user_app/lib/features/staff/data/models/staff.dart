/// Mirrors backend's StaffDtos.StaffResponse
/// (backend/staff/.../StaffDtos.java) — the generic, category-agnostic
/// staff directory, not a per-vertical Master/Mechanic/Cleaner.
class Staff {
  final String id;
  final String providerId;
  final String displayName;
  final String? bio;
  final String? photoUrl;
  final bool active;

  const Staff({
    required this.id,
    required this.providerId,
    required this.displayName,
    this.bio,
    this.photoUrl,
    required this.active,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      displayName: json['displayName'] as String,
      bio: json['bio'] as String?,
      photoUrl: json['photoUrl'] as String?,
      active: json['active'] as bool,
    );
  }
}
