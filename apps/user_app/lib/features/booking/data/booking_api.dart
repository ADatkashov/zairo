import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import 'booking_exception.dart';
import 'models/availability_slot.dart';
import 'models/book_again_suggestion.dart';
import 'models/booking.dart';
import 'models/payment_plan.dart';
import 'models/reschedule_option.dart';

/// Not final: tests substitute a subclass overriding these methods instead
/// of mocking Dio — same pattern as DiscoveryApi/AuthApi.
class BookingApi {
  final DioClient _dioClient;

  BookingApi(this._dioClient);

  Future<List<AvailabilitySlot>> listAvailabilitySlots(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/availability-slots');
    final data = response.data as List<dynamic>;
    return data.map((e) => AvailabilitySlot.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Null when the policy can't be read — callers treat that as "unknown" and
  /// must not invent a charge.
  Future<DepositPolicy?> getDepositPolicy(String providerId) async {
    try {
      final response = await _dioClient.get(
        '/payment-settings/public',
        queryParameters: {'providerId': providerId},
      );
      return DepositPolicy.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }

  Future<Booking> createBooking({
    required String userId,
    required String serviceId,
    required String availabilitySlotId,
    required double totalPrice,
  }) async {
    try {
      final response = await _dioClient.post(
        '/bookings',
        data: {
          'userId': userId,
          'serviceId': serviceId,
          'availabilitySlotId': availabilitySlotId,
          'totalPrice': totalPrice,
        },
      );
      return Booking.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const BookingException(BookingErrorKey.slotTaken);
      }
      rethrow;
    }
  }

  Future<Booking> getBooking(String bookingId) async {
    final response = await _dioClient.get('/bookings/$bookingId');
    return Booking.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Booking>> listMyBookings(String userId) async {
    final response = await _dioClient.get('/users/$userId/bookings');
    final data = response.data as List<dynamic>;
    return data.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// "Repeat your last appointment" — one suggestion per distinct service
  /// the customer has a completed booking for, newest visit first.
  Future<List<BookAgainSuggestion>> listBookAgainSuggestions(String userId) async {
    final response = await _dioClient.get('/users/$userId/book-again');
    final data = response.data as List<dynamic>;
    return data.map((e) => BookAgainSuggestion.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Customer-initiated cancellation — backend enforces ownership (403 if
  /// this isn't the caller's own booking) and status (409 if it's already
  /// CANCELLED/COMPLETED). A refund, if the booking had a successful
  /// payment, happens server-side as part of the same call.
  /// The free times this booking can move to: the same business and person, soonest first.
  Future<List<RescheduleOption>> rescheduleOptions(String bookingId) async {
    final response = await _dioClient.get('/bookings/$bookingId/reschedule-options');
    final data = response.data as List<dynamic>;
    return data.map((e) => RescheduleOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Moves the booking to [slotId] (one of [rescheduleOptions]). A 409 means that time was just taken or the booking
  /// can no longer be moved.
  Future<Booking> reschedule(String bookingId, String slotId) async {
    try {
      final response = await _dioClient.post('/bookings/$bookingId/reschedule', data: {'slotId': slotId});
      return Booking.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const BookingException(BookingErrorKey.slotTaken);
      }
      if (e.response?.statusCode == 403) {
        throw const BookingException(BookingErrorKey.notYourBooking);
      }
      rethrow;
    }
  }

  Future<Booking> cancelBooking(String bookingId) async {
    try {
      final response = await _dioClient.post('/bookings/$bookingId/cancel');
      return Booking.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const BookingException(BookingErrorKey.notCancellable);
      }
      if (e.response?.statusCode == 403) {
        throw const BookingException(BookingErrorKey.notYourBooking);
      }
      rethrow;
    }
  }
}
