/// Mirrors the backend's `UserDtos.UserLookupResponse` — just enough to show a
/// registered person (name, avatar) before adding them as a master.
class UserLookup {
  final String id;
  final String displayName;
  final String? avatarUrl;

  const UserLookup({required this.id, required this.displayName, this.avatarUrl});

  factory UserLookup.fromJson(Map<String, dynamic> json) {
    return UserLookup(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
