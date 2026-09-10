/// Mirrors backend's PlatformAdminDtos.AuditLogEntryResponse
/// (backend/platform-admin/.../PlatformAdminDtos.java).
class PlatformAuditLogEntry {
  final String id;
  final String actorEmail;
  final String action;
  final String? targetType;
  final String? targetId;
  final String? previousValue;
  final String? newValue;
  final String? reason;
  final DateTime createdAt;

  const PlatformAuditLogEntry({
    required this.id,
    required this.actorEmail,
    required this.action,
    this.targetType,
    this.targetId,
    this.previousValue,
    this.newValue,
    this.reason,
    required this.createdAt,
  });

  factory PlatformAuditLogEntry.fromJson(Map<String, dynamic> json) {
    return PlatformAuditLogEntry(
      id: json['id'] as String,
      actorEmail: json['actorEmail'] as String,
      action: json['action'] as String,
      targetType: json['targetType'] as String?,
      targetId: json['targetId'] as String?,
      previousValue: json['previousValue'] as String?,
      newValue: json['newValue'] as String?,
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
