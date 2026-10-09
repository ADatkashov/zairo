import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/billing_api.dart';
import '../../data/models/payment_method.dart';
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

/// The card the subscription renews with — brand and last four digits only.
final myPaymentMethodProvider = FutureProvider.autoDispose<PaymentMethod>((ref) {
  return ref.watch(billingApiProvider).getPaymentMethod();
});

/// Opens the provider's payment page in the phone's own browser (card data
/// never touches this app). A provider so tests can see what was opened.
final billingCheckoutLauncherProvider = Provider<Future<bool> Function(Uri)>((ref) {
  return (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
});

/// How often the Billing screen re-reads the subscription while it waits for
/// the provider's webhook to confirm a payment made in the browser.
final billingPollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 3));
