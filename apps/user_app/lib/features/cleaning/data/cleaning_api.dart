import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../../booking/data/models/booking.dart';
import 'cleaning_exception.dart';
import 'models/cleaner.dart';

/// Not final: tests substitute a subclass overriding these methods instead
/// of mocking Dio — same pattern as BeautyApi/AutoApi/BookingApi.
class CleaningApi {
  final DioClient _dioClient;

  CleaningApi(this._dioClient);

  Future<List<Cleaner>> listCleaners(String providerId) async {
    final response = await _dioClient.get('/cleaning/providers/$providerId/cleaners');
    final data = response.data as List<dynamic>;
    return data.map((e) => Cleaner.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Response shape differs from the plain [Booking] JSON (`bookingId` +
  /// `cleanerId` instead of `id`), so this maps it into the same [Booking]
  /// model by hand rather than reusing `Booking.fromJson` — same reasoning
  /// as BeautyApi.createBeautyBooking/AutoApi.createAutoBooking.
  Future<Booking> createCleaningBooking({
    required String userId,
    required String cleanerId,
    required String serviceId,
    required String availabilitySlotId,
    required double totalPrice,
  }) async {
    try {
      final response = await _dioClient.post(
        '/cleaning/bookings',
        data: {
          'userId': userId,
          'cleanerId': cleanerId,
          'serviceId': serviceId,
          'availabilitySlotId': availabilitySlotId,
          'totalPrice': totalPrice,
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
        // 409 covers two distinct backend rejections (the cleaner doesn't
        // offer this service, or the slot was just taken by someone else)
        // that the response body doesn't distinguish for the client, so
        // this message stays general enough to cover both.
        throw const CleaningException(CleaningErrorKey.bookingFailed);
      }
      rethrow;
    }
  }
}
