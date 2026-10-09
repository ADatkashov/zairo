/// Mirrors backend's WorkerChangeDtos.ChangeRequestResponse: an appointment whose person can't make
/// it, where the owner asked the customer to decide.
class ChangeRequest {
  final String bookingId;
  final String providerId;
  final String? providerName;
  final String? serviceTitle;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? workerName;
  final List<ReplacementOption> replacements;
  final List<TimeOption> otherTimes;

  const ChangeRequest({
    required this.bookingId,
    required this.providerId,
    required this.providerName,
    required this.serviceTitle,
    required this.startsAt,
    required this.endsAt,
    required this.workerName,
    required this.replacements,
    required this.otherTimes,
  });

  factory ChangeRequest.fromJson(Map<String, dynamic> json) => ChangeRequest(
        bookingId: json['bookingId'] as String,
        providerId: json['providerId'] as String,
        providerName: json['providerName'] as String?,
        serviceTitle: json['serviceTitle'] as String?,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        workerName: json['workerName'] as String?,
        replacements: ((json['replacements'] as List<dynamic>?) ?? const [])
            .map((e) => ReplacementOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        otherTimes: ((json['otherTimes'] as List<dynamic>?) ?? const [])
            .map((e) => TimeOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ReplacementOption {
  final String workerId;
  final String name;

  const ReplacementOption({required this.workerId, required this.name});

  factory ReplacementOption.fromJson(Map<String, dynamic> json) =>
      ReplacementOption(workerId: json['workerId'] as String, name: json['name'] as String? ?? '');
}

class TimeOption {
  final String slotId;
  final DateTime startsAt;
  final DateTime endsAt;

  const TimeOption({required this.slotId, required this.startsAt, required this.endsAt});

  factory TimeOption.fromJson(Map<String, dynamic> json) => TimeOption(
        slotId: json['slotId'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
      );
}
