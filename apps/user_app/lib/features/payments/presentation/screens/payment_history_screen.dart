import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../booking/data/models/booking.dart';
import '../../../booking/presentation/providers/booking_providers.dart';
import '../../data/models/payment.dart';
import '../providers/payments_providers.dart';

/// "What did I pay": every payment that moved money, newest first, each with the service and business it was for
/// (looked up from the customer's bookings — best effort, the list still shows without them). A tap opens the receipt.
class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final paymentsAsync = ref.watch(myPaymentsProvider);
    final userId = ref.watch(authControllerProvider).value?.id;
    final bookings = userId == null ? null : ref.watch(myBookingsProvider(userId)).value;
    final byId = {for (final b in bookings ?? const <Booking>[]) b.id: b};

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.paymentHistoryTitle),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.paymentHistoryLoadFailed,
              onRetry: () => ref.invalidate(myPaymentsProvider),
            ),
          ),
        ),
        data: (payments) => payments.isEmpty
            ? Center(
                child: FactoryEmptyState(
                  icon: Symbols.receipt_long_rounded,
                  title: l10n.paymentHistoryEmptyTitle,
                  message: l10n.paymentHistoryEmptyHint,
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(myPaymentsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(FactorySpacing.space4),
                  itemCount: payments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space2),
                  itemBuilder: (context, i) => _PaymentRow(payment: payments[i], booking: byId[payments[i].bookingId]),
                ),
              ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.booking});

  final Payment payment;
  final Booking? booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final title = booking?.serviceTitle ?? l10n.paymentHistoryUnknownService;
    final subtitle = [
      if (booking?.providerName != null) booking!.providerName!,
      formatMonthDayTime(l10n, payment.createdAt.toLocal()),
    ].join(' · ');
    return InkWell(
      onTap: () => showPaymentReceipt(context, payment: payment, booking: booking),
      borderRadius: FactoryRadius.mdRadius,
      child: FactoryCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: FactorySpacing.space3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatFactoryMoney(payment.amount, payment.currency),
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                FactoryBadge(label: paymentStatusLabel(l10n, payment.status), variant: _variant(payment.status)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

FactoryBadgeVariant _variant(String status) => switch (status) {
  'SUCCEEDED' => FactoryBadgeVariant.available,
  'REFUND_FAILED' => FactoryBadgeVariant.error,
  'REFUNDED' || 'REFUND_PENDING' => FactoryBadgeVariant.limited,
  _ => FactoryBadgeVariant.neutral,
};

/// The customer-facing name of a payment status that appears in the history.
String paymentStatusLabel(AppLocalizations l10n, String status) => switch (status) {
  'SUCCEEDED' => l10n.paymentStatusSucceeded,
  'REFUNDED' => l10n.paymentStatusRefunded,
  'REFUND_PENDING' => l10n.paymentStatusRefundPending,
  'REFUND_FAILED' => l10n.paymentStatusRefundFailed,
  'FAILED' => l10n.paymentStatusFailed,
  'PENDING' => l10n.paymentStatusPending,
  _ => status,
};

String _typeLabel(AppLocalizations l10n, String? type) => switch (type) {
  'DEPOSIT' => l10n.paymentTypeDeposit,
  'FULL' => l10n.paymentTypeFull,
  'REMAINING' => l10n.paymentTypeRemaining,
  _ => '',
};

/// The receipt for one payment: what, where, when, how much, and the payment number to quote to support.
Future<void> showPaymentReceipt(BuildContext context, {required Payment payment, required Booking? booking}) {
  return showFactoryBottomSheet<void>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      final textTheme = Theme.of(context).textTheme;
      final colors = context.factoryColors;
      final type = _typeLabel(l10n, payment.paymentType);
      final rows = <(String, String)>[
        if (booking?.serviceTitle != null) (l10n.paymentReceiptService, booking!.serviceTitle!),
        if (booking?.providerName != null) (l10n.paymentReceiptBusiness, booking!.providerName!),
        if (booking?.startsAt != null) (l10n.paymentReceiptVisit, formatMonthDayTime(l10n, booking!.startsAt!.toLocal())),
        (l10n.paymentReceiptPaidOn, formatMonthDayTime(l10n, payment.createdAt.toLocal())),
        (l10n.paymentReceiptAmount, [formatFactoryMoney(payment.amount, payment.currency), if (type.isNotEmpty) type].join(' · ')),
        (l10n.paymentReceiptStatus, paymentStatusLabel(l10n, payment.status)),
        (l10n.paymentReceiptNumber, payment.id.substring(0, 8).toUpperCase()),
      ];
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.paymentReceiptTitle, style: textTheme.titleMedium),
          const SizedBox(height: FactorySpacing.space3),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(label, style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(value, textAlign: TextAlign.end, style: textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
