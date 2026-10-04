/// Mirrors backend's AuthDtos.SmsModeResponse (GET /auth/phone/sms-mode).
/// While [mock] is true the backend sends no real SMS and [mockCode] works
/// for every phone — pre-production only (OTP_MOCK_CODE on the server).
class SmsMode {
  final bool mock;
  final String? mockCode;

  const SmsMode({required this.mock, this.mockCode});

  static const real = SmsMode(mock: false);

  factory SmsMode.fromJson(Map<String, dynamic> json) {
    return SmsMode(mock: json['mock'] as bool? ?? false, mockCode: json['mockCode'] as String?);
  }
}
