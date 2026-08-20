import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/payment.dart';
import '../../data/payments_api.dart';

final paymentsApiProvider = Provider<PaymentsApi>((ref) {
  return PaymentsApi(ref.watch(dioClientProvider));
});

final paymentForBookingProvider = FutureProvider.autoDispose.family<Payment?, String>((ref, bookingId) {
  return ref.watch(paymentsApiProvider).getPayment(bookingId);
});
