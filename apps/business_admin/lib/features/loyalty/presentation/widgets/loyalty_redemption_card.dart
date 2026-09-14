import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/loyalty_redemption.dart';

/// One redemption code -- who spent it, on what, how much, its status, and
/// (once applied) which booking it went to.
class LoyaltyRedemptionCard extends StatelessWidget {
  final LoyaltyRedemption redemption;
  final String locale;
  final VoidCallback? onCancel;

  const LoyaltyRedemptionCard({super.key, required this.redemption, required this.locale, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  redemption.rewardName,
                  style: textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: FactorySpacing.space2),
              FactoryBadge(
                label: loyaltyRedemptionStatusLabel(l10n, redemption.status),
                variant: loyaltyRedemptionStatusVariant(redemption.status),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.confirmation_number_outlined, size: 14, color: colors.textTertiary),
              const SizedBox(width: 4),
              Text(
                redemption.code,
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.space2),
          Wrap(
            spacing: FactorySpacing.space3,
            runSpacing: 4,
            children: [
              Text(l10n.loyaltyRedemptionPointsSpentLabel(redemption.pointsSpent), style: textTheme.bodySmall),
              Text(
                DateFormat.yMMMd(locale).add_Hm().format(redemption.createdAt.toLocal()),
                style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              ),
              if (redemption.appliedBookingId != null)
                Text(
                  l10n.loyaltyRedemptionAppliedBookingLabel(redemption.appliedBookingId!),
                  style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
            ],
          ),
          if (onCancel != null) ...[
            const SizedBox(height: FactorySpacing.space3),
            Align(
              alignment: Alignment.centerRight,
              child: FactoryButton(
                label: l10n.loyaltyRedemptionCancelButton,
                variant: FactoryButtonVariant.textDanger,
                onPressed: onCancel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

FactoryBadgeVariant loyaltyRedemptionStatusVariant(LoyaltyRedemptionStatus status) => switch (status) {
      LoyaltyRedemptionStatus.active => FactoryBadgeVariant.available,
      LoyaltyRedemptionStatus.applied => FactoryBadgeVariant.verified,
      LoyaltyRedemptionStatus.cancelled => FactoryBadgeVariant.neutral,
      LoyaltyRedemptionStatus.expired => FactoryBadgeVariant.error,
    };

String loyaltyRedemptionStatusLabel(AppLocalizations l10n, LoyaltyRedemptionStatus status) => switch (status) {
      LoyaltyRedemptionStatus.active => l10n.loyaltyRedemptionStatusActive,
      LoyaltyRedemptionStatus.applied => l10n.loyaltyRedemptionStatusApplied,
      LoyaltyRedemptionStatus.cancelled => l10n.loyaltyRedemptionStatusCancelled,
      LoyaltyRedemptionStatus.expired => l10n.loyaltyRedemptionStatusExpired,
    };
