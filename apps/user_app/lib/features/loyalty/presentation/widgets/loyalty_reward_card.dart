import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/loyalty.dart';

/// One redeemable reward -- the "locked" (unaffordable) state is a
/// deliberately distinct visual (dimmed content, a lock badge, a disabled
/// button reading "Not enough points") rather than color alone, same rule
/// [FactorySelectableTile]'s selected state and [FactoryTimeSlot]'s booked
/// state already follow.
class LoyaltyRewardCard extends StatelessWidget {
  final LoyaltyReward reward;

  /// Null while a redeem call for a *different* card in the same list is
  /// in flight, or once this card just isn't tappable for another reason --
  /// the button disables. [isRedeeming] separately drives this card's own
  /// spinner.
  final VoidCallback? onRedeem;
  final bool isRedeeming;

  const LoyaltyRewardCard({
    super.key,
    required this.reward,
    required this.onRedeem,
    this.isRedeeming = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locked = !reward.affordable;

    return Opacity(
      opacity: locked ? 0.6 : 1,
      child: FactoryCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: locked ? colors.surfaceAlt : colors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    locked ? Symbols.lock_rounded : _iconFor(reward.type),
                    size: 20,
                    color: locked ? colors.textTertiary : colors.primary,
                  ),
                ),
                const SizedBox(width: FactorySpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reward.name, style: textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        _discountSummary(l10n),
                        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space2, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.accentTint,
                    borderRadius: FactoryRadius.smRadius,
                  ),
                  child: Text(
                    l10n.loyaltyRewardPointsCost(reward.pointsCost),
                    style: textTheme.labelSmall?.copyWith(color: colors.text, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (reward.description != null && reward.description!.isNotEmpty) ...[
              const SizedBox(height: FactorySpacing.space2),
              Text(
                reward.description!,
                style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              ),
            ],
            if (reward.terms != null && reward.terms!.isNotEmpty) ...[
              const SizedBox(height: FactorySpacing.space1),
              Text(
                l10n.loyaltyRewardTerms(reward.terms!),
                style: textTheme.bodySmall?.copyWith(color: colors.textTertiary, fontStyle: FontStyle.italic),
              ),
            ],
            if (reward.endsAt != null) ...[
              const SizedBox(height: FactorySpacing.space1),
              Text(
                l10n.loyaltyRewardEndsOn(formatMonthDayTime(l10n, reward.endsAt!.toLocal())),
                style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              ),
            ],
            const SizedBox(height: FactorySpacing.space3),
            FactoryButton(
              label: locked ? l10n.loyaltyRewardLockedLabel : l10n.loyaltyRewardRedeemButton,
              variant: locked ? FactoryButtonVariant.secondary : FactoryButtonVariant.primary,
              isLoading: isRedeeming,
              expand: true,
              onPressed: locked ? null : onRedeem,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(LoyaltyRewardType type) => switch (type) {
        LoyaltyRewardType.fixedDiscount => Symbols.sell_rounded,
        LoyaltyRewardType.percentageDiscount => Symbols.percent_rounded,
        LoyaltyRewardType.freeService => Symbols.card_giftcard_rounded,
        LoyaltyRewardType.custom => Symbols.redeem_rounded,
      };

  String _discountSummary(AppLocalizations l10n) => switch (reward.type) {
        LoyaltyRewardType.fixedDiscount when reward.discountAmount != null =>
          l10n.loyaltyRewardDiscountFixed(
            formatFactoryAmount(reward.discountAmount!),
            reward.discountCurrency ?? '',
          ),
        LoyaltyRewardType.percentageDiscount when reward.discountPercentage != null =>
          l10n.loyaltyRewardDiscountPercentage(_formatPercentage(reward.discountPercentage!)),
        LoyaltyRewardType.freeService => l10n.loyaltyRewardFreeService,
        _ => reward.name,
      };

  String _formatPercentage(double value) => value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}
