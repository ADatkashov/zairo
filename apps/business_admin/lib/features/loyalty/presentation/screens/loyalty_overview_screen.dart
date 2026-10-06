import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/loyalty_overview.dart';
import '../providers/loyalty_admin_providers.dart';

/// The six cheap aggregate numbers from `GET .../loyalty/overview`, laid out
/// as a Bento in the same treatment as the Business Intelligence Dashboard:
/// members are the hero (with the active share as a ring), points issued vs
/// redeemed come next, liability and rewards close the screen.
class LoyaltyOverviewScreen extends ConsumerWidget {
  final String providerId;

  const LoyaltyOverviewScreen({super.key, required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final overviewAsync = ref.watch(loyaltyOverviewProvider(providerId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(loyaltyOverviewProvider(providerId)),
      child: ListView(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        children: [
          overviewAsync.when(
            data: (overview) => _OverviewBento(overview: overview),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: FactorySpacing.space6),
              child: FactoryLoadingState(),
            ),
            error: (error, _) => FactoryErrorState(
              message: l10n.errorLoyaltyOverviewLoadFailed(error.toString()),
              onRetry: () => ref.invalidate(loyaltyOverviewProvider(providerId)),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewBento extends StatelessWidget {
  final LoyaltyOverview overview;

  const _OverviewBento({required this.overview});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const gap = SizedBox(height: FactorySpacing.space3);
    const hgap = SizedBox(width: FactorySpacing.space3);
    final activeShare = overview.totalMembers == 0 ? 0.0 : overview.activeMembers / overview.totalMembers;
    final redeemedShare = overview.totalPointsIssued == 0
        ? 0.0
        : overview.totalPointsRedeemed / overview.totalPointsIssued;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MembersHero(
          label: l10n.loyaltyOverviewTotalMembers,
          total: '${overview.totalMembers}',
          activeLabel: l10n.loyaltyOverviewActiveMembers,
          active: '${overview.activeMembers}',
          activeShare: activeShare,
        ),
        gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.add_circle_outline,
                label: l10n.loyaltyOverviewPointsIssued,
                value: '${overview.totalPointsIssued}',
              ),
            ),
            hgap,
            Expanded(
              child: _MetricCard(
                icon: Icons.remove_circle_outline,
                label: l10n.loyaltyOverviewPointsRedeemed,
                value: '${overview.totalPointsRedeemed}',
                share: redeemedShare,
              ),
            ),
          ],
        ),
        gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.account_balance_wallet_outlined,
                label: l10n.loyaltyOverviewOutstandingLiability,
                value: '${overview.outstandingPointsLiability}',
              ),
            ),
            hgap,
            Expanded(
              child: _MetricCard(
                icon: Icons.card_giftcard_outlined,
                label: l10n.loyaltyOverviewRewardsRedeemed,
                value: '${overview.rewardsRedeemed}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MembersHero extends StatelessWidget {
  final String label;
  final String total;
  final String activeLabel;
  final String active;
  final double activeShare;

  const _MembersHero({
    required this.label,
    required this.total,
    required this.activeLabel,
    required this.active,
    required this.activeShare,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final radius = context.factoryProfileOrNull?.cardBorderRadius ?? FactoryRadius.xlRadius;
    final muted = colors.onPrimary.withValues(alpha: 0.8);

    return Container(
      padding: const EdgeInsets.all(FactorySpacing.space5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryStrong, colors.primary],
        ),
        borderRadius: radius,
        boxShadow: context.factoryElevation(FactoryElevationLevel.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.labelLarge?.copyWith(color: muted)),
                const SizedBox(height: FactorySpacing.space1),
                Text(
                  total,
                  style: FactoryTypography.mono(size: 36, weight: FontWeight.w600, color: colors.onPrimary),
                ),
                const SizedBox(height: FactorySpacing.space2),
                Text('$active · $activeLabel', style: textTheme.labelMedium?.copyWith(color: muted)),
              ],
            ),
          ),
          const SizedBox(width: FactorySpacing.space4),
          FactoryProgressRing(
            value: activeShare,
            size: 72,
            strokeWidth: 8,
            color: colors.onPrimary,
            trackColor: colors.onPrimary.withValues(alpha: 0.2),
            semanticLabel: activeLabel,
            child: Text(
              '${(activeShare * 100).round()}%',
              style: FactoryTypography.mono(size: 14, color: colors.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// 0..1 — draws a thin meter under the value when set.
  final double? share;

  const _MetricCard({required this.icon, required this.label, required this.value, this.share});

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return FactoryCard(
      padding: const EdgeInsets.all(FactorySpacing.space4),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(height: FactorySpacing.space2),
            Text(
              value,
              style: FactoryTypography.mono(size: 22, weight: FontWeight.w600, color: colors.text),
            ),
            const SizedBox(height: 2),
            Text(label, style: textTheme.labelMedium?.copyWith(color: colors.textSecondary)),
            if (share != null) ...[
              const SizedBox(height: FactorySpacing.space2),
              ClipRRect(
                borderRadius: BorderRadius.circular(FactoryRadius.sm),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: share!.clamp(0.0, 1.0)),
                  duration: FactoryMotion.resolve(context, FactoryMotion.slow),
                  curve: FactoryMotion.standard,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    backgroundColor: colors.primaryTint,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
