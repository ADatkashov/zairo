/// Mirrors the backend's `InvitationDtos.InvitationResponse`: a not-yet-registered person invited by phone.
class StaffInvitation {
  final String id;
  final String providerId;
  final String phone;
  final String kind;
  final String status;

  const StaffInvitation({
    required this.id,
    required this.providerId,
    required this.phone,
    required this.kind,
    required this.status,
  });

  factory StaffInvitation.fromJson(Map<String, dynamic> json) {
    return StaffInvitation(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      phone: json['phone'] as String,
      kind: json['kind'] as String,
      status: json['status'] as String,
    );
  }
}
