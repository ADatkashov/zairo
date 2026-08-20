import 'package:core_ui/core_ui.dart';
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
        return FactoryBadge(
          label: 'Payment: ${_label(payment.status)}',
          variant: switch (payment.status) {
            'SUCCEEDED' => FactoryBadgeVariant.available,
            'FAILED' => FactoryBadgeVariant.error,
            _ => FactoryBadgeVariant.neutral,
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

String _label(String status) => status.isEmpty ? status : '${status[0]}${status.substring(1).toLowerCase()}';
