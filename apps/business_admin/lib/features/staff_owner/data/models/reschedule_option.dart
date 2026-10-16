/// A free time the business can move an appointment to (backend `RescheduleOption`).
class RescheduleOption {
  final String slotId;
  final DateTime startsAt;
  final DateTime endsAt;

  const RescheduleOption({required this.slotId, required this.startsAt, required this.endsAt});

  factory RescheduleOption.fromJson(Map<String, dynamic> json) => RescheduleOption(
        slotId: json['slotId'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
      );
}
