/// Mirrors backend's WorkerAvailabilityDtos.AnySlotResponse (backend/workforce/.../WorkerAvailabilityDtos.java):
/// a time the customer can book with "any master", plus the person the system would assign.
class AnySlot {
  final String slotId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String workerId;

  /// MASTER / MECHANIC / CLEANER / STAFF.
  final String workerKind;

  const AnySlot({
    required this.slotId,
    required this.startsAt,
    required this.endsAt,
    required this.workerId,
    required this.workerKind,
  });

  factory AnySlot.fromJson(Map<String, dynamic> json) => AnySlot(
        slotId: json['slotId'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        workerId: json['workerId'] as String,
        workerKind: json['workerKind'] as String,
      );
}
