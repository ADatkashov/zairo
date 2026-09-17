import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/logged_out_gate.dart';
import '../../data/models/loyalty.dart';
import '../providers/loyalty_providers.dart';
import '../widgets/points_expiring_banner.dart';
import 'business_loyalty_screen.dart';

/// "My rewards across every business" -- pushed from Profile (see
/// ProfileScreen's stat row), same navigation pattern as FavoritesScreen.
/// Every business the caller has ever earned or held points with, one row
/// each; balances are entirely independent between rows (see this
/// feature's own package doc comment on `loyalty` never pooling across
/// businesses).
class MyRewardsScreen extends ConsumerWidget {
  const MyRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.myRewardsTitle),
      body: authState.when(
        data: (user) => user == null
            ? LoggedOutGate(icon: Symbols.redeem_rounded, message: l10n.myRewardsLoggedOutPrompt)
            : const _MyRewardsList(),
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorProfileGeneric(error.toString()),
              onRetry: () => ref.invalidate(authControllerProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _MyRewardsList extends ConsumerWidget {
  const _MyRewardsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final rewardsAsync = ref.watch(myLoyaltyProvider);

    return rewardsAsync.when(
      data: (businesses) {
        Future<void> refresh() => ref.refresh(myLoyaltyProvider.future);

        if (businesses.isEmpty) {
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(
                    child: FactoryEmptyState(
                      icon: Symbols.redeem_rounded,
                      title: l10n.myRewardsEmptyTitle,
                      message: l10n.myRewardsEmptyMessage,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: businesses.length,
            separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space3),
            itemBuilder: (context, index) => _BusinessRow(business: businesses[index]),
          ),
        );
      },
      loading: () => const FactoryLoadingState(),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          child: FactoryErrorState(
            message: l10n.errorMyRewardsLoadFailed,
            onRetry: () => ref.invalidate(myLoyaltyProvider),
          ),
        ),
      ),
    );
  }
}

class _BusinessRow extends StatelessWidget {
  final LoyaltyBusinessSummary business;

  const _BusinessRow({required this.business});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return FactoryCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BusinessLoyaltyScreen(
            providerId: business.providerId,
            providerName: business.providerName,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: colors.primaryTint, shape: BoxShape.circle),
                child: Icon(Symbols.storefront_rounded, size: 20, color: colors.primary),
              ),
              const SizedBox(width: FactorySpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.providerName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                    if (business.tierName != null) ...[
                      const SizedBox(height: 2),
                      FactoryBadge(label: business.tierName!, variant: FactoryBadgeVariant.verified),
                    ] else if (!business.programEnabled) ...[
                      const SizedBox(height: 2),
                      FactoryBadge(label: l10n.loyaltyProgramInactiveLabel),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: FactorySpacing.space2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.loyaltyPointsBalanceShort(business.pointsBalance),
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: colors.primary),
                  ),
                  Icon(Symbols.chevron_right_rounded, size: 18, color: colors.textTertiary),
                ],
              ),
            ],
          ),
          if (business.pointsExpiringSoon30d > 0) ...[
            const SizedBox(height: FactorySpacing.space3),
            PointsExpiringBanner(points: business.pointsExpiringSoon30d),
          ],
        ],
      ),
    );
  }
}
