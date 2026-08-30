import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../../booking/data/models/booking.dart';
import 'models/staff.dart';
import 'staff_exception.dart';

/// Not final: tests substitute a subclass overriding these methods instead
/// of mocking Dio — same pattern as BeautyApi/AutoApi/CleaningApi. Unlike
/// those, this works for a provider in ANY category — the provider detail
/// screen falls back to this whenever the provider's vertical isn't one of
/// the three hardcoded ones with their own staff module.
class StaffApi {
  final DioClient _dioClient;

  StaffApi(this._dioClient);

  Future<List<Staff>> listStaff(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/staff');
    final data = response.data as List<dynamic>;
    return data.map((e) => Staff.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Response shape differs from the plain [Booking] JSON (`bookingId` +
  /// `staffId` instead of `id`), so this maps it into the same [Booking]
  /// model by hand rather than reusing `Booking.fromJson` — same reasoning
  /// as BeautyApi.createBeautyBooking/CleaningApi.createCleaningBooking.
  Future<Booking> createStaffBooking({
    required String userId,
    required String staffId,
    required String serviceId,
    required String availabilitySlotId,
    required double totalPrice,
  }) async {
    try {
      final response = await _dioClient.post(
        '/staff/bookings',
        data: {
          'userId': userId,
          'staffId': staffId,
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
        // 409 covers two distinct backend rejections (the staff member
        // doesn't offer this service, or the slot was just taken by
        // someone else) that the response body doesn't distinguish for the
        // client, so this message stays general enough to cover both.
        throw const StaffException(StaffErrorKey.bookingFailed);
      }
      rethrow;
    }
  }
}
