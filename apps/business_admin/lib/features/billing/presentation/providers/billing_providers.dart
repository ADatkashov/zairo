import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/billing_api.dart';
import '../../data/models/subscription.dart';
import '../../data/models/subscription_charge.dart';

final billingApiProvider = Provider<BillingApi>((ref) {
  return BillingApi(ref.watch(dioClientProvider));
});

/// Not keyed by ownerUserId (unlike myProvidersProvider) — "my subscription"
/// always means the caller's own, resolved server-side from the auth token,
/// same as GET /subscriptions/me needs no id in its path.
final mySubscriptionProvider = FutureProvider.autoDispose<Subscription>((ref) {
  return ref.watch(billingApiProvider).getMine();
});

/// The Billing screen's invoice history (v2 design audit) — same
/// not-keyed-by-owner reasoning as [mySubscriptionProvider].
final myChargesProvider = FutureProvider.autoDispose<List<SubscriptionCharge>>((ref) {
  return ref.watch(billingApiProvider).listCharges();
});
