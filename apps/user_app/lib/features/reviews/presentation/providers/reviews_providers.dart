import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/public_review.dart';
import '../../data/models/review.dart';
import '../../data/reviews_api.dart';

final reviewsApiProvider = Provider<ReviewsApi>((ref) {
  return ReviewsApi(ref.watch(dioClientProvider));
});

final reviewForBookingProvider = FutureProvider.autoDispose
    .family<Review?, String>((ref, bookingId) {
      return ref.watch(reviewsApiProvider).getReview(bookingId);
    });

final reviewSummaryProvider = FutureProvider.autoDispose
    .family<ReviewSummary, String>((ref, providerId) {
      return ref.watch(reviewsApiProvider).getSummary(providerId);
    });

typedef PublicReviewsKey = ({
  String providerId,
  int size,
  int? rating,
  bool withCommentOnly,
  ReviewSort sort,
});

final publicReviewsProvider = FutureProvider.autoDispose
    .family<PublicReviewsPage, PublicReviewsKey>((ref, key) {
      return ref
          .watch(reviewsApiProvider)
          .getPublicReviews(
            key.providerId,
            size: key.size,
            rating: key.rating,
            withCommentOnly: key.withCommentOnly,
            sort: key.sort,
          );
    });
