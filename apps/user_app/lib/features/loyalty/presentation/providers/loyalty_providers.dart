import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/loyalty_api.dart';
import '../../data/models/loyalty.dart';
import '../../data/models/page.dart';

final loyaltyApiProvider = Provider<LoyaltyApi>((ref) {
  return LoyaltyApi(ref.watch(dioClientProvider));
});

/// "My rewards" across every business -- no key, always the caller's own
/// (see LoyaltyApi's doc comment on why these calls take no userId).
final myLoyaltyProvider = FutureProvider.autoDispose<List<LoyaltyBusinessSummary>>((ref) {
  return ref.watch(loyaltyApiProvider).myLoyalty();
});

final loyaltyBusinessDetailProvider =
    FutureProvider.autoDispose.family<LoyaltyBusinessDetail, String>((ref, providerId) {
  return ref.watch(loyaltyApiProvider).businessLoyalty(providerId);
});

final loyaltyRewardsProvider = FutureProvider.autoDispose.family<List<LoyaltyReward>, String>((ref, providerId) {
  return ref.watch(loyaltyApiProvider).rewards(providerId);
});

/// One page of a business's points history, keyed by (providerId, page).
/// [LoyaltyHistoryScreen] accumulates successive pages itself, same
/// division of responsibility as Campaign Center's campaignListProvider.
final loyaltyHistoryProvider =
    FutureProvider.autoDispose.family<Page<LoyaltyTransaction>, (String providerId, int page)>((ref, key) {
  final (providerId, page) = key;
  return ref.watch(loyaltyApiProvider).history(providerId, page: page);
});

/// One page of the caller's own redemptions across every business, keyed by
/// page number alone (unlike [loyaltyHistoryProvider], there's no
/// per-business scoping here -- GET /loyalty/redemptions spans all of
/// them).
final myRedemptionsProvider = FutureProvider.autoDispose.family<Page<LoyaltyRedemption>, int>((ref, page) {
  return ref.watch(loyaltyApiProvider).myRedemptions(page: page);
});

final loyaltyRedemptionProvider = FutureProvider.autoDispose.family<LoyaltyRedemption, String>((ref, id) {
  return ref.watch(loyaltyApiProvider).getRedemption(id);
});

/// Invalidates every provider a redeem/cancel action could have changed the
/// answer to for one business -- its own detail/rewards/history, the "my
/// rewards" home row it appears in, and every cached page of "my
/// redemptions" (a fresh redemption or a cancellation both change that
/// list). Called by the redeem/cancel flows after a successful mutation --
/// same write-then-invalidate pattern as Campaign Center's
/// invalidateCampaignData.
void invalidateLoyaltyData(WidgetRef ref, String providerId) {
  ref.invalidate(myLoyaltyProvider);
  ref.invalidate(loyaltyBusinessDetailProvider(providerId));
  ref.invalidate(loyaltyRewardsProvider(providerId));
  ref.invalidate(loyaltyHistoryProvider);
  ref.invalidate(myRedemptionsProvider);
}
