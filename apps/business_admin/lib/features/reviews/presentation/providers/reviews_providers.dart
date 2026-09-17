import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../loyalty/data/models/loyalty_page.dart';
import '../../data/api/reviews_api.dart';
import '../../data/models/provider_review.dart';

final reviewsApiProvider = Provider<ReviewsApi>((ref) {
  return ReviewsApi(ref.watch(dioClientProvider));
});

/// One page of a provider's reviews, keyed by (providerId, page) -- the
/// reviews screen accumulates successive pages itself, same pattern as
/// [loyaltyCustomersProvider] in the loyalty feature.
final providerReviewsProvider =
    FutureProvider.autoDispose.family<LoyaltyPage<ProviderReview>, (String providerId, int page)>((ref, key) {
  return ref.watch(reviewsApiProvider).fetchReviews(key.$1, page: key.$2);
});
