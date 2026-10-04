import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/loyalty_admin_api.dart';
import '../../data/models/loyalty_birthday.dart';
import '../../data/models/loyalty_customer.dart';
import '../../data/models/loyalty_milestone.dart';
import '../../data/models/loyalty_overview.dart';
import '../../data/models/loyalty_page.dart';
import '../../data/models/loyalty_redemption.dart';
import '../../data/models/loyalty_reward.dart';
import '../../data/models/loyalty_settings.dart';
import '../../data/models/loyalty_tier.dart';

final loyaltyAdminApiProvider = Provider<LoyaltyAdminApi>((ref) {
  return LoyaltyAdminApi(ref.watch(dioClientProvider));
});

final loyaltySettingsProvider = FutureProvider.autoDispose.family<LoyaltySettings, String>((ref, providerId) {
  return ref.watch(loyaltyAdminApiProvider).fetchSettings(providerId);
});

/// Upcoming birthdays of opted-in members, keyed by (providerId, days).
final loyaltyBirthdaysProvider =
    FutureProvider.autoDispose.family<List<LoyaltyBirthday>, (String providerId, int days)>((ref, key) {
  return ref.watch(loyaltyAdminApiProvider).fetchBirthdays(key.$1, days: key.$2);
});

final loyaltyMilestonesProvider =
    FutureProvider.autoDispose.family<List<LoyaltyMilestone>, String>((ref, providerId) {
  return ref.watch(loyaltyAdminApiProvider).fetchMilestones(providerId);
});

final loyaltyTiersProvider = FutureProvider.autoDispose.family<List<LoyaltyTier>, String>((ref, providerId) {
  return ref.watch(loyaltyAdminApiProvider).fetchTiers(providerId);
});

final loyaltyOverviewProvider = FutureProvider.autoDispose.family<LoyaltyOverview, String>((ref, providerId) {
  return ref.watch(loyaltyAdminApiProvider).fetchOverview(providerId);
});

/// One page of the loyalty roster, keyed by (providerId, page) -- the
/// customer list screen accumulates successive pages itself, same pattern
/// as [campaignListProvider] in the campaigns feature.
final loyaltyCustomersProvider =
    FutureProvider.autoDispose.family<LoyaltyPage<LoyaltyCustomerInsight>, (String providerId, int page)>((
  ref,
  key,
) {
  return ref.watch(loyaltyAdminApiProvider).fetchCustomers(key.$1, page: key.$2);
});

final loyaltyCustomerDetailProvider =
    FutureProvider.autoDispose.family<LoyaltyCustomerInsight, (String providerId, String userId)>((ref, key) {
  return ref.watch(loyaltyAdminApiProvider).fetchCustomer(key.$1, key.$2);
});

final loyaltyRewardsProvider = FutureProvider.autoDispose.family<List<LoyaltyReward>, String>((ref, providerId) {
  return ref.watch(loyaltyAdminApiProvider).fetchRewards(providerId);
});

final loyaltyRedemptionsProvider =
    FutureProvider.autoDispose.family<LoyaltyPage<LoyaltyRedemption>, (String providerId, int page)>((ref, key) {
  return ref.watch(loyaltyAdminApiProvider).fetchRedemptions(key.$1, page: key.$2);
});

/// Invalidates every cached read a settings save could have changed the
/// answer to -- called after a successful `updateSettings`, same
/// write-then-invalidate pattern as `invalidateCampaignData`.
void invalidateLoyaltySettings(WidgetRef ref, String providerId) {
  ref.invalidate(loyaltySettingsProvider(providerId));
}

void invalidateLoyaltyMilestones(WidgetRef ref, String providerId) {
  ref.invalidate(loyaltyMilestonesProvider(providerId));
}

void invalidateLoyaltyTiers(WidgetRef ref, String providerId) {
  ref.invalidate(loyaltyTiersProvider(providerId));
}

/// After creating/updating/activating/deactivating/deleting a reward -- the
/// catalog list and the dashboard overview (rewards redeemed count is
/// unaffected by catalog edits, but this keeps the invalidation simple and
/// correct rather than guessing which mutations do/don't touch it).
void invalidateLoyaltyRewards(WidgetRef ref, String providerId) {
  ref.invalidate(loyaltyRewardsProvider(providerId));
  ref.invalidate(loyaltyOverviewProvider(providerId));
}

/// After a manual points adjustment -- the roster, this customer's detail
/// row, and the dashboard overview (outstanding liability changes).
void invalidateLoyaltyCustomerData(WidgetRef ref, String providerId, String userId) {
  ref.invalidate(loyaltyCustomersProvider);
  ref.invalidate(loyaltyCustomerDetailProvider((providerId, userId)));
  ref.invalidate(loyaltyOverviewProvider(providerId));
}

/// After applying or cancelling a redemption -- the redemptions list and the
/// dashboard overview (outstanding liability / rewards redeemed change).
void invalidateLoyaltyRedemptionData(WidgetRef ref, String providerId) {
  ref.invalidate(loyaltyRedemptionsProvider);
  ref.invalidate(loyaltyOverviewProvider(providerId));
}
