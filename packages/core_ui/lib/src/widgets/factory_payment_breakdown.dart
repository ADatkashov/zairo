import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_spacing.dart';
import '../theme/factory_typography.dart';
import 'factory_card.dart';
import 'factory_price_text.dart';

/// Total / deposit / remaining summary shown before a booking is confirmed
/// (audit P1: users must see what they pay now and what they pay later).
/// Labels are passed in so the caller supplies localized strings; amounts
/// are in major units. [deposit] of 0 hides the deposit and remaining rows.
class FactoryPaymentBreakdown extends StatelessWidget {
  const FactoryPaymentBreakdown({
    super.key,
    required this.total,
    required this.deposit,
    required this.totalLabel,
    required this.depositLabel,
    required this.remainingLabel,
    this.currency,
    this.note,
  });

  final num total;
  final num deposit;
  final String totalLabel;
  final String depositLabel;
  final String remainingLabel;

  /// ISO 4217 code; null uses the platform default.
  final String? currency;

  /// Optional fine print, e.g. the cancellation policy.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final hasDeposit = deposit > 0;
    final remaining = (total - deposit).clamp(0, double.infinity);

    Widget row(String label, num amount, {Color? color, bool strong = false}) => Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: (strong ? textTheme.titleSmall : textTheme.bodyMedium)
                    ?.copyWith(color: strong ? colors.text : colors.textSecondary),
              ),
            ),
            const SizedBox(width: FactorySpacing.space3),
            Text(
              formatFactoryMoney(amount, currency),
              style: FactoryTypography.mono(size: 14, color: color ?? colors.text),
            ),
          ],
        );

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          row(totalLabel, total, strong: !hasDeposit),
          if (hasDeposit) ...[
            const SizedBox(height: FactorySpacing.space2),
            row(depositLabel, deposit, color: colors.primary),
            const SizedBox(height: FactorySpacing.space3),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: FactorySpacing.space3),
            row(remainingLabel, remaining, strong: true),
          ],
          if (note != null) ...[
            const SizedBox(height: FactorySpacing.space3),
            Text(note!, style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
