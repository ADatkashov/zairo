import 'package:core_network/core_network.dart';

import 'models/needs_attention.dart';
import 'models/worker_schedule.dart';

/// The owner's side of worker-related appointments (backend `WorkerOwnerController`). Not final:
/// tests substitute a subclass overriding these methods — same pattern as the other APIs.
class StaffOwnerApi {
  final DioClient _dioClient;

  StaffOwnerApi(this._dioClient);

  Future<List<NeedsAttentionItem>> needsAttention(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/appointments/needs-attention');
    final data = response.data as List<dynamic>;
    return data.map((e) => NeedsAttentionItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Cancels the appointment: the slot is released, a paid booking is refunded and the customer is
  /// notified. Only the owner can do this — a worker can only ask.
  Future<void> cancelAppointment(String providerId, String bookingId, {String? reason}) {
    return _dioClient.post(
      '/providers/$providerId/appointments/$bookingId/cancel',
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  /// Hands the appointment to a colleague at the same time (409 if they are busy).
  Future<void> reassignAppointment(String providerId, String bookingId, String workerId) {
    return _dioClient.post('/providers/$providerId/appointments/$bookingId/reassign', data: {'workerId': workerId});
  }

  /// Lets the customer choose: a colleague, another time with the same person, or a refunded cancel.
  Future<void> askCustomer(String providerId, String bookingId) {
    return _dioClient.post('/providers/$providerId/appointments/$bookingId/ask-customer');
  }

  /// The customer did come after a wrong no-show mark: it becomes a normal completion.
  Future<void> markAttended(String providerId, String bookingId) {
    return _dioClient.post('/providers/$providerId/appointments/$bookingId/mark-attended');
  }

  // --- per-worker prices ---

  /// serviceId -> this worker's own price, for services where it differs from the base price.
  Future<Map<String, double>> workerPrices(String providerId, String workerId) async {
    final response = await _dioClient.get('/providers/$providerId/workers/$workerId/prices');
    final data = response.data as List<dynamic>;
    return {for (final e in data) (e as Map<String, dynamic>)['serviceId'] as String: (e['price'] as num).toDouble()};
  }

  /// A null [price] goes back to the service's own price.
  Future<void> setWorkerPrice(String providerId, String workerId, String serviceId, double? price) {
    return _dioClient.put('/providers/$providerId/workers/$workerId/prices', data: {'serviceId': serviceId, 'price': price});
  }

  // --- team schedule ---

  Future<List<WorkerSummary>> workers(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/workers');
    final data = response.data as List<dynamic>;
    return data.map((e) => WorkerSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WorkerRating> workerRating(String providerId, String workerId) async {
    final response = await _dioClient.get('/providers/$providerId/workers/$workerId/rating');
    return WorkerRating.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WorkerScheduleData> schedule(String providerId, String workerId) async {
    final response = await _dioClient.get('/providers/$providerId/workers/$workerId/schedule');
    return WorkerScheduleData.fromJson(response.data as Map<String, dynamic>);
  }

  /// Replaces the weekly hours and (re)generates the person's own bookable times. Only the owner can do this.
  Future<SaveScheduleResult> saveSchedule(
    String providerId,
    String workerId, {
    required int slotMinutes,
    required int breakMinutes,
    required List<HoursInterval> hours,
  }) async {
    final response = await _dioClient.put(
      '/providers/$providerId/workers/$workerId/schedule',
      data: {
        'zoneId': localZoneOffset(),
        'slotMinutes': slotMinutes,
        'breakMinutes': breakMinutes,
        'hours': hours.map((h) => h.toJson()).toList(),
      },
    );
    return SaveScheduleResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Back to the business's shared slots.
  Future<void> deleteSchedule(String providerId, String workerId) =>
      _dioClient.delete('/providers/$providerId/workers/$workerId/schedule');

  Future<List<TimeOffItem>> timeOff(String providerId, String workerId) async {
    final response = await _dioClient.get('/providers/$providerId/workers/$workerId/time-off');
    final data = response.data as List<dynamic>;
    return data.map((e) => TimeOffItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// "The master isn't in": closes new bookings for the period. Booked appointments are NOT cancelled.
  Future<TimeOffCreated> createTimeOff(
    String providerId,
    String workerId, {
    required DateTime startsAt,
    required DateTime endsAt,
    String? reason,
  }) async {
    final response = await _dioClient.post(
      '/providers/$providerId/workers/$workerId/time-off',
      data: {
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return TimeOffCreated.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteTimeOff(String providerId, String timeOffId) =>
      _dioClient.delete('/providers/$providerId/time-off/$timeOffId');

  Future<WorkforceSettings> settings(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/workforce-settings');
    return WorkforceSettings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WorkforceSettings> updateSettings(
    String providerId, {
    required bool allowWorkerChoice,
    required bool workerPricingEnabled,
  }) async {
    final response = await _dioClient.put(
      '/providers/$providerId/workforce-settings',
      data: {'allowWorkerChoice': allowWorkerChoice, 'workerPricingEnabled': workerPricingEnabled},
    );
    return WorkforceSettings.fromJson(response.data as Map<String, dynamic>);
  }

  /// The device's current fixed UTC offset (e.g. "+06:00"). The app has no IANA zone data, but the server accepts
  /// a fixed-offset zone as validly as "Asia/Almaty" — same convention as the recurring-schedule dialog.
  static String localZoneOffset([Duration? offset]) {
    final o = offset ?? DateTime.now().timeZoneOffset;
    final sign = o.isNegative ? '-' : '+';
    final hours = o.abs().inHours.toString().padLeft(2, '0');
    final minutes = (o.abs().inMinutes % 60).toString().padLeft(2, '0');
    return '$sign$hours:$minutes';
  }
}
