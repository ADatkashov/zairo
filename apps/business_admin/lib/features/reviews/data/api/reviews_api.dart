import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../../../loyalty/data/models/loyalty_page.dart';
import '../models/provider_review.dart';
import '../reviews_exception.dart';

/// Wraps the business-admin Reviews REST surface
/// (backend/reviews/.../ReviewController) from the owner's point of view.
/// [LoyaltyPage] is reused as-is rather than duplicated -- it already mirrors
/// Spring Data's generic `Page<T>` envelope, which this module's list
/// endpoint returns unchanged (same as Loyalty's customers/redemptions
/// endpoints). Paths never repeat the `/api/v1` prefix -- [DioClient]'s base
/// URL already includes it.
class ReviewsApi {
  final DioClient _dioClient;

  ReviewsApi(this._dioClient);

  Future<LoyaltyPage<ProviderReview>> fetchReviews(String providerId, {int page = 0, int size = 20}) => _run(
        () async {
          final response = await _dioClient.get(
            '/providers/$providerId/reviews',
            queryParameters: {'page': page, 'size': size},
          );
          return LoyaltyPage.fromJson(
            response.data as Map<String, dynamic>,
            (e) => ProviderReview.fromJson(e),
          );
        },
      );

  /// Posting again overwrites the earlier reply -- editing your own reply is
  /// a normal case, not an error, same as the backend's own doc comment.
  /// The reply endpoint returns the plain `ReviewResponse` shape (no
  /// `customerName`), so this only surfaces what changed -- the caller
  /// already has the full row and patches it via [ProviderReview.copyWithReply]
  /// rather than re-fetching the page just to learn its own customerName back.
  Future<({String reply, DateTime repliedAt})> replyToReview(String reviewId, String reply) => _run(() async {
        final response = await _dioClient.post('/reviews/$reviewId/reply', data: {'reply': reply});
        return (
          reply: response.data['businessReply'] as String,
          repliedAt: DateTime.parse(response.data['businessReplyAt'] as String),
        );
      });

  /// Reports a review to the platform. One report per review for good: a second one is a 409.
  Future<void> reportReview(String reviewId, String reason) => _run(() async {
        await _dioClient.post('/reviews/$reviewId/report', data: {'reason': reason});
      });

  /// Every call funnels through here so a 403/404 always surfaces as a
  /// [ReviewsException] carrying the backend's own `message` instead of a
  /// raw DioException -- callers show [ReviewsException.localizedMessage]
  /// rather than e.toString().
  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final message = data is Map && data['message'] is String ? data['message'] as String : null;
      throw ReviewsException(statusCode: status, serverMessage: message);
    }
  }
}
