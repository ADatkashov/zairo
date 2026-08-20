import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/review.dart';
import '../../data/reviews_api.dart';

final reviewsApiProvider = Provider<ReviewsApi>((ref) {
  return ReviewsApi(ref.watch(dioClientProvider));
});

final reviewForBookingProvider = FutureProvider.autoDispose.family<Review?, String>((ref, bookingId) {
  return ref.watch(reviewsApiProvider).getReview(bookingId);
});
