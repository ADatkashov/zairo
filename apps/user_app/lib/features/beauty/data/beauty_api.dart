import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../../booking/data/models/booking.dart';
import 'beauty_exception.dart';
import 'models/master.dart';
import 'models/portfolio_item.dart';

/// Not final: tests substitute a subclass overriding these methods instead
/// of mocking Dio — same pattern as DiscoveryApi/BookingApi.
class BeautyApi {
  final DioClient _dioClient;

  BeautyApi(this._dioClient);

  Future<List<Master>> listMasters(String providerId) async {
    final response = await _dioClient.get('/beauty/providers/$providerId/masters');
    final data = response.data as List<dynamic>;
    return data.map((e) => Master.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<PortfolioItem>> listPortfolio(String masterId) async {
    final response = await _dioClient.get('/beauty/masters/$masterId/portfolio');
    final data = response.data as List<dynamic>;
    return data.map((e) => PortfolioItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Response shape differs from the plain [Booking] JSON (`bookingId` +
  /// `masterId` instead of `id`), so this maps it into the same [Booking]
  /// model by hand rather than reusing `Booking.fromJson` — the rest of the
  /// booking flow (payment charge, confirmation message) doesn't need to
  /// know which endpoint created the booking.
  Future<Booking> createBeautyBooking({
    required String userId,
    required String masterId,
    required String serviceId,
    required String availabilitySlotId,
    required double totalPrice,
  }) async {
    try {
      final response = await _dioClient.post(
        '/beauty/bookings',
        data: {
          'userId': userId,
          'masterId': masterId,
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
        // 409 covers two distinct backend rejections (the master doesn't
        // offer this service, or the slot was just taken by someone else)
        // that the response body doesn't distinguish for the client, so
        // this message stays general enough to cover both.
        throw const BeautyException(
          "Couldn't complete this booking — the master may not offer this service, or the time slot was just taken. Please try again.",
        );
      }
      rethrow;
    }
  }
}
