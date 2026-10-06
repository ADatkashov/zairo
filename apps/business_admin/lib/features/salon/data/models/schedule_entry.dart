/// Mirrors backend's BookingDtos.ScheduleEntryResponse: a booking together
/// with when its slot starts and ends (a booking itself only references its
/// slot).
class ScheduleEntry {
  final String bookingId;
  final String serviceId;
  final String availabilitySlotId;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final double totalPrice;
  final String? currency;

  const ScheduleEntry({
    required this.bookingId,
    required this.serviceId,
    required this.availabilitySlotId,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.totalPrice,
    this.currency,
  });

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) {
    return ScheduleEntry(
      bookingId: json['bookingId'] as String,
      serviceId: json['serviceId'] as String,
      availabilitySlotId: json['availabilitySlotId'] as String,
      status: json['status'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      currency: json['currency'] as String?,
    );
  }
}

/// A schedule entry with the names an agenda row shows.
class AgendaItem {
  final ScheduleEntry entry;
  final String providerName;
  final String serviceTitle;

  const AgendaItem({required this.entry, required this.providerName, required this.serviceTitle});
}
