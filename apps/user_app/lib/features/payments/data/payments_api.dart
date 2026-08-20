import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import 'models/payment.dart';
import 'payment_exception.dart';

/// Not final: tests substitute a subclass overriding these methods instead
/// of mocking Dio — same pattern as the other feature APIs.
class PaymentsApi {
  final DioClient _dioClient;

  PaymentsApi(this._dioClient);

  /// Returns null when the booking has no payment yet — a 404 here is a
  /// normal state, not an error (same pattern as reviews/favorites).
  Future<Payment?> getPayment(String bookingId) async {
    try {
      final response = await _dioClient.get('/bookings/$bookingId/payments');
      return Payment.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<Payment> createPayment(String bookingId) async {
    try {
      final response = await _dioClient.post('/bookings/$bookingId/payments');
      return Payment.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const PaymentException('This booking has already been paid for.');
      }
      rethrow;
    }
  }
}
