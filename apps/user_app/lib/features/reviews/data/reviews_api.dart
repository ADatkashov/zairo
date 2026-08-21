import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import 'models/review.dart';
import 'review_exception.dart';

/// Not final: tests substitute a subclass overriding these methods instead
/// of mocking Dio — same pattern as the other feature APIs.
class ReviewsApi {
  final DioClient _dioClient;

  ReviewsApi(this._dioClient);

  /// Returns null when the booking has no review yet — a 404 here is an
  /// expected, normal state, not an error condition.
  Future<Review?> getReview(String bookingId) async {
    try {
      final response = await _dioClient.get('/bookings/$bookingId/reviews');
      return Review.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<Review> createReview({
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await _dioClient.post(
        '/bookings/$bookingId/reviews',
        data: {'rating': rating, 'comment': comment},
      );
      return Review.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 409) {
        throw const ReviewException(ReviewErrorKey.duplicateOrNotCompleted);
      }
      if (status == 400) {
        throw const ReviewException(ReviewErrorKey.invalidRating);
      }
      rethrow;
    }
  }
}
