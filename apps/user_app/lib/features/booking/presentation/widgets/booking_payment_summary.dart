import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/payment_plan.dart';

/// Tells the customer, in plain terms, what this booking costs *them right
/// now*: free to book, a deposit now and the rest at the venue, or the full
/// price online. The service price is never the headline when it isn't what
/// gets charged.
class BookingPaymentSummary extends StatelessWidget {
  final PaymentPlan plan;
  final bool compact;

  const BookingPaymentSummary({super.key, required this.plan, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    final isFull = plan.mode == PaymentMode.full;
    final icon = isFull ? Symbols.credit_card_rounded : Symbols.payments_rounded;
    final title = isFull ? l10n.bookingPayFullTitle : l10n.bookingPayDueNow;

    return Container(
      padding: EdgeInsets.all(compact ? FactorySpacing.space2 : FactorySpacing.space3),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: FactoryRadius.mdRadius,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: compact ? 18 : 22, color: colors.primary),
              const SizedBox(width: FactorySpacing.space2),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              FactoryPriceText(amount: plan.dueNow, fontSize: compact ? 15 : 18, weight: FontWeight.w800),
            ],
          ),
          const SizedBox(height: FactorySpacing.space2),
          if (isFull)
            Text(
              l10n.bookingPayFullBody,
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            )
          else ...[
            _Line(label: l10n.bookingPayAtVenue, amount: plan.atVenue, note: l10n.paymentRemainingInfo),
            if (plan.mode == PaymentMode.deposit) ...[
              const SizedBox(height: FactorySpacing.space1),
              _Line(label: l10n.bookingPayServicePrice, amount: plan.total, muted: true),
            ],
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final double amount;
  final String? note;
  final bool muted;

  const _Line({required this.label, required this.amount, this.note, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final color = muted ? colors.textTertiary : colors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: textTheme.bodySmall?.copyWith(color: color)),
            FactoryPriceText(
              amount: amount,
              fontSize: 13,
              color: color,
              weight: muted ? FontWeight.w500 : FontWeight.w600,
            ),
          ],
        ),
        if (note != null)
          Text(note!, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary, fontSize: 12)),
      ],
    );
  }
}
