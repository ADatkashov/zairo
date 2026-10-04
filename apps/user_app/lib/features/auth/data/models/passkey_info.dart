/// Mirrors backend's AuthDtos.PasskeySummary — one passkey registered on the
/// caller's account (GET /auth/passkeys), for Settings > Security.
class PasskeyInfo {
  final String id;
  final String name;
  final DateTime? createdAt;

  const PasskeyInfo({required this.id, required this.name, this.createdAt});

  factory PasskeyInfo.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'] as String?;
    return PasskeyInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: created == null ? null : DateTime.tryParse(created),
    );
  }
}

/// A started passkey ceremony: the options for the platform authenticator and
/// the single-use id to send back with the result.
class PasskeyCeremony {
  final String ceremonyId;
  final Map<String, dynamic> options;

  const PasskeyCeremony({required this.ceremonyId, required this.options});

  factory PasskeyCeremony.fromJson(Map<String, dynamic> json) {
    return PasskeyCeremony(
      ceremonyId: json['ceremonyId'] as String,
      options: Map<String, dynamic>.from(json['options'] as Map),
    );
  }
}
