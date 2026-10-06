import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../../booking/data/booking_exception.dart';
import '../../booking/data/models/availability_slot.dart';
import '../../booking/data/models/booking.dart';
import 'models/any_slot.dart';

/// Customer-facing worker availability and "any master" booking (backend `WorkerAvailabilityController`). Not
/// final: tests substitute a subclass overriding these methods — same pattern as the other APIs.
class WorkforceApi {
  final DioClient _dioClient;

  WorkforceApi(this._dioClient);

  /// Whether the business lets customers pick a specific person. True when it can't be read, so a hiccup never hides
  /// the choice of person from a business that offers it.
  Future<bool> allowsWorkerChoice(String providerId) async {
    try {
      final response = await _dioClient.get('/providers/$providerId/workforce-settings');
      return (response.data as Map<String, dynamic>)['allowWorkerChoice'] as bool? ?? true;
    } on DioException {
      return true;
    }
  }

  /// The bookable times of one person: only times when they actually work, aren't off and aren't booked anywhere.
  Future<List<AvailabilitySlot>> workerSlots(String providerId, String workerId) async {
    final response = await _dioClient.get('/providers/$providerId/workers/$workerId/availability');
    final data = response.data as List<dynamic>;
    return data.map((e) => AvailabilitySlot.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Times to book with "any master" for a service, soonest first.
  Future<List<AnySlot>> anySlots(String providerId, String serviceId) async {
    final response = await _dioClient.get(
      '/providers/$providerId/availability/any',
      queryParameters: {'serviceId': serviceId},
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => AnySlot.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Books the picked time with "any master": the system assigns a free person. Maps the response into the same
  /// [Booking] the other flows return.
  Future<Booking> bookAny({
    required String providerId,
    required String userId,
    required String serviceId,
    required DateTime startsAt,
    String? vehicleId,
  }) async {
    try {
      final response = await _dioClient.post(
        '/providers/$providerId/bookings/any',
        data: {
          'userId': userId,
          'serviceId': serviceId,
          'startsAt': startsAt.toUtc().toIso8601String(),
          'vehicleId': ?vehicleId,
        },
      );
      final json = response.data as Map<String, dynamic>;
      return Booking(
        id: json['bookingId'] as String,
        userId: json['userId'] as String,
        serviceId: json['serviceId'] as String,
        availabilitySlotId: json['availabilitySlotId'] as String,
        status: json['status'] as String,
        totalPrice: (json['totalPrice'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        // The time was taken a moment ago — same message the other booking flows show.
        throw const BookingException(BookingErrorKey.slotTaken);
      }
      rethrow;
    }
  }
}
