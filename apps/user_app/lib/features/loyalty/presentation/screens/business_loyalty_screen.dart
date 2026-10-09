import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_exception.dart';
import '../../data/models/loyalty.dart';
import '../providers/loyalty_providers.dart';
import '../widgets/loyalty_reward_card.dart';
import '../widgets/points_expiring_banner.dart';
import 'loyalty_history_screen.dart';

/// One business's own loyalty program, from the customer's point of view --
/// reached from the "My Rewards" list (see MyRewardsScreen) or from that
/// business's own provider detail page (see ProviderDetailScreen's "Rewards
/// & loyalty" entry tile). Works even for a business the caller has never
/// booked with (an all-zero, program-disabled view -- the backend never
/// 404s this), so this screen has no not-found handling to do, only the
/// program-disabled banner.
class BusinessLoyaltyScreen extends ConsumerStatefulWidget {
  final String providerId;
  final String? providerName;

  const BusinessLoyaltyScreen({super.key, required this.providerId, this.providerName});

  @override
  ConsumerState<BusinessLoyaltyScreen> createState() => _BusinessLoyaltyScreenState();
}

class _BusinessLoyaltyScreenState extends ConsumerState<BusinessLoyaltyScreen> {
  String? _redeemingRewardId;

  Future<void> _refresh() => ref.refresh(loyaltyBusinessDetailProvider(widget.providerId).future);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final detailAsync = ref.watch(loyaltyBusinessDetailProvider(widget.providerId));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: widget.providerName ?? l10n.loyaltyEntryTileTitle),
      body: detailAsync.when(
        data: (detail) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            children: [
              if (!detail.programEnabled) ...[
                _InfoBanner(text: l10n.loyaltyProgramDisabledBanner),
                const SizedBox(height: FactorySpacing.space4),
              ],
              if (detail.tierName != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: FactoryBadge(label: detail.tierName!, variant: FactoryBadgeVariant.verified, icon: Symbols.star_rounded),
                ),
                const SizedBox(height: FactorySpacing.space3),
              ],
              FactoryCard(
                child: Row(
                  children: [
                    Expanded(
                      child: FactoryStatTile(
                        value: l10n.loyaltyPointsBalanceShort(detail.pointsBalance),
                        label: l10n.loyaltyStatBalance,
                        icon: Symbols.toll_rounded,
                      ),
                    ),
                    Container(width: 1, height: 36, color: colors.border),
                    Expanded(
                      child: FactoryStatTile(
                        value: detail.lifetimeEarned.toString(),
                        label: l10n.loyaltyStatLifetimeEarned,
                      ),
                    ),
                    Container(width: 1, height: 36, color: colors.border),
                    Expanded(
                      child: FactoryStatTile(
                        value: detail.completedVisits.toString(),
                        label: l10n.loyaltyStatVisits,
                      ),
                    ),
                  ],
                ),
              ),
              if (detail.pointsExpiringSoon30d > 0) ...[
                const SizedBox(height: FactorySpacing.space3),
                PointsExpiringBanner(points: detail.pointsExpiringSoon30d),
              ],
              if (detail.waysToEarn.isNotEmpty) ...[
                const SizedBox(height: FactorySpacing.space6),
                Text(l10n.loyaltyWaysToEarnTitle, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: FactorySpacing.space2),
                // Server-generated English sentences (see LoyaltyBusinessDetail's
                // doc comment) -- rendered as-is, never re-localized.
                ...detail.waysToEarn.map(
                  (way) => Padding(
                    padding: const EdgeInsets.only(bottom: FactorySpacing.space1),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Symbols.check_circle_rounded, size: 16, color: colors.primary),
                        const SizedBox(width: FactorySpacing.space2),
                        Expanded(
                          child: Text(
                            way,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (detail.nextMilestone != null) ...[
                const SizedBox(height: FactorySpacing.space6),
                Text(l10n.loyaltyNextMilestoneTitle, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: FactorySpacing.space2),
                _NextMilestoneCard(milestone: detail.nextMilestone!, completedVisits: detail.completedVisits),
              ],
              const SizedBox(height: FactorySpacing.space6),
              FactorySectionHeader(
                title: l10n.loyaltyRewardsTitle,
                actionLabel: l10n.loyaltyViewHistoryAction,
                onActionTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LoyaltyHistoryScreen(providerId: widget.providerId, providerName: widget.providerName),
                  ),
                ),
              ),
              const SizedBox(height: FactorySpacing.space3),
              _RewardsSection(
                providerId: widget.providerId,
                redeemingRewardId: _redeemingRewardId,
                onRedeem: (reward) => _redeem(context, reward),
              ),
            ],
          ),
        ),
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorLoyaltyBusinessLoadFailed,
              onRetry: () => ref.invalidate(loyaltyBusinessDetailProvider(widget.providerId)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _redeem(BuildContext context, LoyaltyReward reward) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showFactoryDialog<bool>(
      context: context,
      title: l10n.loyaltyRedeemConfirmTitle,
      message: l10n.loyaltyRedeemConfirmMessage(reward.pointsCost, reward.name),
      actions: [
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.loyaltyRedeemCancelButton,
            variant: FactoryButtonVariant.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.loyaltyRedeemConfirmButton,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ],
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _redeemingRewardId = reward.id);
    try {
      final redemption = await ref.read(loyaltyApiProvider).redeem(reward.id);
      invalidateLoyaltyData(ref, widget.providerId);
      if (!context.mounted) return;
      await showFactoryDialog<void>(
        context: context,
        title: l10n.loyaltyRedemptionSuccessTitle,
        barrierDismissible: false,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.loyaltyRedemptionSuccessMessage),
            const SizedBox(height: FactorySpacing.space4),
            Center(
              child: SelectableText(
                redemption.code,
                style: FactoryTypography.mono(size: 28, weight: FontWeight.w800, color: context.factoryColors.text),
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (dialogContext) => FactoryButton(
              label: l10n.loyaltyRedemptionSuccessDone,
              expand: true,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ],
      );
    } on LoyaltyException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorLoyaltyRedeemFailed)));
    } finally {
      if (mounted) setState(() => _redeemingRewardId = null);
    }
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;

  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Container(
      padding: const EdgeInsets.all(FactorySpacing.space3),
      decoration: BoxDecoration(
        color: Color.alphaBlend(colors.info.withValues(alpha: 0.1), colors.surface),
        borderRadius: FactoryRadius.mdRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.info_rounded, size: 18, color: colors.info),
          const SizedBox(width: FactorySpacing.space2),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _NextMilestoneCard extends StatelessWidget {
  final NextMilestone milestone;
  final int completedVisits;

  const _NextMilestoneCard({required this.milestone, required this.completedVisits});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final fraction = milestone.visitsRequired > 0 ? (completedVisits / milestone.visitsRequired).clamp(0.0, 1.0) : 0.0;

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The milestone's own business-defined name (or the backend's
          // "{n} visits" fallback) -- server text, never re-localized, same
          // treatment as waysToEarn above.
          Text(milestone.label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: FactorySpacing.space2),
          ClipRRect(
            borderRadius: FactoryRadius.smRadius,
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: colors.surfaceAlt,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: FactorySpacing.space2),
          Text(
            l10n.loyaltyNextMilestoneProgressText(milestone.visitsRemaining, milestone.pointsAwarded),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RewardsSection extends ConsumerWidget {
  final String providerId;
  final String? redeemingRewardId;
  final ValueChanged<LoyaltyReward> onRedeem;

  const _RewardsSection({required this.providerId, required this.redeemingRewardId, required this.onRedeem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final rewardsAsync = ref.watch(loyaltyRewardsProvider(providerId));

    return rewardsAsync.when(
      data: (rewards) {
        if (rewards.isEmpty) {
          return FactoryEmptyState(
            compact: true,
            icon: Symbols.redeem_rounded,
            title: l10n.loyaltyRewardsEmptyTitle,
            message: l10n.loyaltyRewardsEmptyMessage,
          );
        }
        return Column(
          children: [
            for (final reward in rewards) ...[
              LoyaltyRewardCard(
                reward: reward,
                isRedeeming: redeemingRewardId == reward.id,
                onRedeem: redeemingRewardId == null ? () => onRedeem(reward) : null,
              ),
              const SizedBox(height: FactorySpacing.space3),
            ],
          ],
        );
      },
      loading: () => const FactoryLoadingState(),
      error: (error, stackTrace) => FactoryErrorState(
        message: l10n.errorLoyaltyRewardsLoadFailed,
        onRetry: () => ref.invalidate(loyaltyRewardsProvider(providerId)),
      ),
    );
  }
}
