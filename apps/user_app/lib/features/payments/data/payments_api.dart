import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import 'models/payment.dart';
import 'models/saved_card.dart';
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
        throw const PaymentException(PaymentErrorKey.alreadyPaid);
      }
      rethrow;
    }
  }

  /// Charges one of the customer's saved cards right away (no payment page).
  /// Only valid when [SavedCards.canPayWithSavedCard].
  Future<Payment> payWithSavedCard(String bookingId, String savedCardId) async {
    try {
      final response = await _dioClient.post(
        '/bookings/$bookingId/payments',
        data: {'savedCardId': savedCardId},
      );
      return Payment.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const PaymentException(PaymentErrorKey.alreadyPaid);
      }
      rethrow;
    }
  }

  Future<SavedCards> getSavedCards() async {
    final response = await _dioClient.get('/me/payment-cards');
    return SavedCards.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SavedCards> setSaveOnNextPayment(bool value) async {
    final response = await _dioClient.put('/me/payment-cards/preference', data: {'saveOnNextPayment': value});
    return SavedCards.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> removeSavedCard(String cardId) async {
    await _dioClient.delete('/me/payment-cards/$cardId');
  }
}
