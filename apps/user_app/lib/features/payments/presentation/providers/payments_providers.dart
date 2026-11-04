import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/payment.dart';
import '../../data/models/saved_card.dart';
import '../../data/payments_api.dart';

final paymentsApiProvider = Provider<PaymentsApi>((ref) {
  return PaymentsApi(ref.watch(dioClientProvider));
});

final paymentForBookingProvider = FutureProvider.autoDispose.family<Payment?, String>((ref, bookingId) {
  return ref.watch(paymentsApiProvider).getPayment(bookingId);
});

/// The customer's payment history, newest first.
final myPaymentsProvider = FutureProvider.autoDispose<List<Payment>>((ref) {
  return ref.watch(paymentsApiProvider).listMyPayments();
});

/// Opens the provider's payment page in the phone's own browser (card data
/// never touches this app). A provider so tests can see what was opened
/// instead of reaching for a platform channel.
final checkoutLauncherProvider = Provider<Future<bool> Function(Uri)>((ref) {
  return (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
});

/// How often the payment screen asks the server whether the payment has been
/// confirmed. The server (the provider's webhook) is the only source of truth —
/// coming back from the payment page proves nothing by itself.
final paymentPollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 3));

/// The customer's saved cards (brand and last four digits only).
final savedCardsProvider = FutureProvider.autoDispose<SavedCards>((ref) {
  return ref.watch(paymentsApiProvider).getSavedCards();
});

/// Saved cards the customer can pay with right now. A failed lookup means "none":
/// paying through the provider's payment page always still works.
Future<List<SavedCard>> usableSavedCards(PaymentsApi api) async {
  try {
    return (await api.getSavedCards()).usable;
  } catch (_) {
    return const [];
  }
}
