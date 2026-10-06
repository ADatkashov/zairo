/// Mirrors backend's StaffOwnerDtos.NeedsAttentionResponse
/// (backend/workforce/.../WorkerOwnerDtos.java): an appointment that needs the owner's decision.
class NeedsAttentionItem {
  final String bookingId;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? serviceTitle;
  final String? customerName;
  final String? customerPhone;
  final double totalPrice;
  final String currency;
  final String workerId;

  /// MASTER / MECHANIC / CLEANER / STAFF.
  final String? workerKind;
  final String? workerName;

  /// `WORKER_CANNOT_ATTEND`, `WORKER_UNAVAILABLE` or `WORKER_INACTIVE`.
  final String reason;
  final String? workerNote;
  final DateTime? requestedAt;

  /// `SPECIFIC` (customer chose this person) or `ANY`.
  final String preference;

  /// When the customer was asked to decide; null if not yet.
  final DateTime? customerAskedAt;
  final List<Replacement> replacements;

  const NeedsAttentionItem({
    required this.bookingId,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.serviceTitle,
    required this.customerName,
    required this.customerPhone,
    required this.totalPrice,
    required this.currency,
    required this.workerId,
    required this.workerKind,
    required this.workerName,
    required this.reason,
    required this.workerNote,
    required this.requestedAt,
    this.preference = 'SPECIFIC',
    this.customerAskedAt,
    this.replacements = const [],
  });

  factory NeedsAttentionItem.fromJson(Map<String, dynamic> json) {
    final requested = json['requestedAt'] as String?;
    final asked = json['customerAskedAt'] as String?;
    return NeedsAttentionItem(
      bookingId: json['bookingId'] as String,
      status: json['status'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      serviceTitle: json['serviceTitle'] as String?,
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      totalPrice: (json['totalPrice'] as num).toDouble(),
      currency: json['currency'] as String,
      workerId: json['workerId'] as String,
      workerKind: json['workerKind'] as String?,
      workerName: json['workerName'] as String?,
      reason: json['reason'] as String,
      workerNote: json['workerNote'] as String?,
      requestedAt: requested == null ? null : DateTime.parse(requested),
      preference: json['preference'] as String? ?? 'SPECIFIC',
      customerAskedAt: asked == null ? null : DateTime.parse(asked),
      replacements: ((json['replacements'] as List<dynamic>?) ?? const [])
          .map((e) => Replacement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A colleague who could take the appointment.
class Replacement {
  final String workerId;
  final String name;

  /// False when the time is outside their usual working hours.
  final bool atWorkingTime;

  const Replacement({required this.workerId, required this.name, required this.atWorkingTime});

  factory Replacement.fromJson(Map<String, dynamic> json) => Replacement(
        workerId: json['workerId'] as String,
        name: json['name'] as String? ?? '',
        atWorkingTime: json['atWorkingTime'] as bool? ?? true,
      );
}
