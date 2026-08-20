import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/payments_providers.dart';

/// Read-only status display — charging happens right after booking
/// creation (see ProviderDetailScreen), not from this widget.
class PaymentStatusChip extends ConsumerWidget {
  final String bookingId;

  const PaymentStatusChip({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentAsync = ref.watch(paymentForBookingProvider(bookingId));

    return paymentAsync.when(
      data: (payment) {
        if (payment == null) return const SizedBox.shrink();
        return Chip(
          label: Text('Payment: ${payment.status}'),
          visualDensity: VisualDensity.compact,
          backgroundColor: payment.status == 'SUCCEEDED'
              ? Colors.green.withValues(alpha: 0.2)
              : payment.status == 'FAILED'
                  ? Colors.red.withValues(alpha: 0.2)
                  : null,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
