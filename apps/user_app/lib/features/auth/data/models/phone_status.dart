/// Mirrors backend's AuthDtos.PhoneStatusResponse.
class PhoneStatus {
  /// A ZAIRO account is already reachable through this phone.
  final bool registered;

  /// That account has a password, so sign-in asks for it instead of an SMS.
  final bool hasPassword;

  const PhoneStatus({required this.registered, required this.hasPassword});

  factory PhoneStatus.fromJson(Map<String, dynamic> json) {
    return PhoneStatus(
      registered: json['registered'] as bool? ?? false,
      hasPassword: json['hasPassword'] as bool? ?? false,
    );
  }
}
