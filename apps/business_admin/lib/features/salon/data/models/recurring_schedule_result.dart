/// Mirrors backend's AvailabilitySlotDtos.RecurringScheduleResult
/// (backend/booking/.../AvailabilitySlotDtos.java) — only the counts are
/// kept, not the full created-slot list, since the caller just refetches
/// the slot list to show the actual rows.
class RecurringScheduleResult {
  final int createdCount;
  final int skippedConflictCount;

  const RecurringScheduleResult({required this.createdCount, required this.skippedConflictCount});

  factory RecurringScheduleResult.fromJson(Map<String, dynamic> json) {
    final created = json['created'] as List<dynamic>;
    return RecurringScheduleResult(
      createdCount: created.length,
      skippedConflictCount: json['skippedConflictCount'] as int,
    );
  }
}
