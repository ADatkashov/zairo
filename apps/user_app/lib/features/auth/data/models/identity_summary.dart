/// Mirrors backend's AuthDtos.IdentitySummary — one linked sign-in method
/// on the caller's own account (see GET /auth/identities). Powers Settings
/// > Security's "linked accounts" list.
class IdentitySummary {
  final String provider;

  const IdentitySummary({required this.provider});

  factory IdentitySummary.fromJson(Map<String, dynamic> json) {
    return IdentitySummary(provider: json['provider'] as String);
  }
}
