import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/loyalty_reward.dart';

/// One reward in the catalog list -- name, type, cost, and how it's doing
/// (active/inactive, redemption count). Tap opens the edit form.
class LoyaltyRewardCard extends StatelessWidget {
  final LoyaltyReward reward;
  final VoidCallback onTap;

  const LoyaltyRewardCard({super.key, required this.reward, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return FactoryCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(loyaltyRewardTypeIcon(reward.type), size: 16, color: colors.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(reward.name, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: FactorySpacing.space2),
              FactoryBadge(
                label: reward.active ? l10n.loyaltyRewardStatusActive : l10n.loyaltyRewardStatusInactive,
                variant: reward.active ? FactoryBadgeVariant.available : FactoryBadgeVariant.neutral,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            loyaltyRewardTypeLabel(l10n, reward.type),
            style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(height: FactorySpacing.space2),
          Wrap(
            spacing: FactorySpacing.space3,
            runSpacing: 4,
            children: [
              Text(l10n.loyaltyRewardPointsCostLabel(reward.pointsCost), style: textTheme.bodySmall),
              Text(
                l10n.loyaltyRewardRedemptionsCountLabel(reward.redemptionsCount),
                style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
              if (reward.maxRedemptions != null)
                Text(
                  l10n.loyaltyRewardMaxRedemptionsLabel(reward.maxRedemptions!),
                  style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

IconData loyaltyRewardTypeIcon(LoyaltyRewardType type) => switch (type) {
      LoyaltyRewardType.fixedDiscount => Icons.money_off_outlined,
      LoyaltyRewardType.percentageDiscount => Icons.percent_outlined,
      LoyaltyRewardType.freeService => Icons.card_giftcard_outlined,
      LoyaltyRewardType.custom => Icons.stars_outlined,
    };

String loyaltyRewardTypeLabel(AppLocalizations l10n, LoyaltyRewardType type) => switch (type) {
      LoyaltyRewardType.fixedDiscount => l10n.loyaltyRewardTypeFixedDiscount,
      LoyaltyRewardType.percentageDiscount => l10n.loyaltyRewardTypePercentageDiscount,
      LoyaltyRewardType.freeService => l10n.loyaltyRewardTypeFreeService,
      LoyaltyRewardType.custom => l10n.loyaltyRewardTypeCustom,
    };
