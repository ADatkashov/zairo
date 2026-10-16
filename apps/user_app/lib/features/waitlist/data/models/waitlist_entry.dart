/// Mirrors backend's WaitlistDtos.WaitlistEntryResponse. [from]/[to] bound the start times the customer wants (an
/// instant range); both null means any time.
class WaitlistEntry {
  final String providerId;
  final DateTime? from;
  final DateTime? to;

  const WaitlistEntry({required this.providerId, this.from, this.to});

  factory WaitlistEntry.fromJson(Map<String, dynamic> json) {
    DateTime? instant(Object? value) => value == null ? null : DateTime.parse(value as String);
    return WaitlistEntry(
      providerId: json['providerId'] as String,
      from: instant(json['from']),
      to: instant(json['to']),
    );
  }

  /// The local calendar day the customer picked, or null for "any day" (or a range that is not one day).
  DateTime? get day {
    final start = from?.toLocal();
    if (start == null) return null;
    return DateTime(start.year, start.month, start.day);
  }
}
