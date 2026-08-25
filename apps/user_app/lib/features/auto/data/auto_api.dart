import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../../booking/data/models/booking.dart';
import 'auto_exception.dart';
import 'models/mechanic.dart';
import 'models/vehicle.dart';

/// Not final: tests substitute a subclass overriding these methods instead
/// of mocking Dio — same pattern as BeautyApi/BookingApi.
class AutoApi {
  final DioClient _dioClient;

  AutoApi(this._dioClient);

  Future<List<Mechanic>> listMechanics(String providerId) async {
    final response = await _dioClient.get('/auto/providers/$providerId/mechanics');
    final data = response.data as List<dynamic>;
    return data.map((e) => Mechanic.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Vehicle>> listVehicles(String userId) async {
    final response = await _dioClient.get('/users/$userId/vehicles');
    final data = response.data as List<dynamic>;
    return data.map((e) => Vehicle.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Vehicle> registerVehicle({
    required String ownerUserId,
    required String make,
    required String model,
    required int year,
    required String licensePlate,
  }) async {
    final response = await _dioClient.post(
      '/vehicles',
      data: {
        'ownerUserId': ownerUserId,
        'make': make,
        'model': model,
        'year': year,
        'licensePlate': licensePlate,
      },
    );
    return Vehicle.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteVehicle(String vehicleId) {
    return _dioClient.delete('/vehicles/$vehicleId');
  }

  /// Response shape differs from the plain [Booking] JSON (`bookingId` +
  /// `mechanicId`/`vehicleId` instead of `id`), so this maps it into the
  /// same [Booking] model by hand rather than reusing `Booking.fromJson` —
  /// same reasoning as BeautyApi.createBeautyBooking.
  Future<Booking> createAutoBooking({
    required String userId,
    required String mechanicId,
    required String vehicleId,
    required String serviceId,
    required String availabilitySlotId,
    required double totalPrice,
  }) async {
    try {
      final response = await _dioClient.post(
        '/auto/bookings',
        data: {
          'userId': userId,
          'mechanicId': mechanicId,
          'vehicleId': vehicleId,
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
        // 409 covers two distinct backend rejections (the mechanic doesn't
        // offer this service, or the slot was just taken by someone else)
        // that the response body doesn't distinguish for the client, so
        // this message stays general enough to cover both.
        throw const AutoException(AutoErrorKey.bookingFailed);
      }
      rethrow;
    }
  }
}
