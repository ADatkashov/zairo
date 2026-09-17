import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/loyalty_admin_providers.dart';

/// The six cheap aggregate numbers from `GET .../loyalty/overview`, styled
/// as metric tiles -- same [FactoryStatTile]-in-a-[FactoryCard] treatment
/// the Business Intelligence Dashboard uses for its own KPI rows (see
/// `salon`'s BusinessAnalyticsScreen), so this reads as one system rather
/// than inventing a new tile style for Loyalty specifically.
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
            data: (overview) => FactoryCard(
              child: Wrap(
                spacing: FactorySpacing.space5,
                runSpacing: FactorySpacing.space5,
                children: [
                  FactoryStatTile(
                    icon: Icons.groups_outlined,
                    label: l10n.loyaltyOverviewTotalMembers,
                    value: '${overview.totalMembers}',
                  ),
                  FactoryStatTile(
                    icon: Icons.bolt_outlined,
                    label: l10n.loyaltyOverviewActiveMembers,
                    value: '${overview.activeMembers}',
                  ),
                  FactoryStatTile(
                    icon: Icons.add_circle_outline,
                    label: l10n.loyaltyOverviewPointsIssued,
                    value: '${overview.totalPointsIssued}',
                  ),
                  FactoryStatTile(
                    icon: Icons.remove_circle_outline,
                    label: l10n.loyaltyOverviewPointsRedeemed,
                    value: '${overview.totalPointsRedeemed}',
                  ),
                  FactoryStatTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: l10n.loyaltyOverviewOutstandingLiability,
                    value: '${overview.outstandingPointsLiability}',
                  ),
                  FactoryStatTile(
                    icon: Icons.card_giftcard_outlined,
                    label: l10n.loyaltyOverviewRewardsRedeemed,
                    value: '${overview.rewardsRedeemed}',
                  ),
                ],
              ),
            ),
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
