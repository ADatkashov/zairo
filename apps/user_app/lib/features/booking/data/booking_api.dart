import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import 'booking_exception.dart';
import 'models/availability_slot.dart';
import 'models/booking.dart';

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
        throw const BookingException(
          'This time slot was just booked by someone else. Please pick another one.',
        );
      }
      rethrow;
    }
  }

  Future<List<Booking>> listMyBookings(String userId) async {
    final response = await _dioClient.get('/users/$userId/bookings');
    final data = response.data as List<dynamic>;
    return data.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
  }
}
