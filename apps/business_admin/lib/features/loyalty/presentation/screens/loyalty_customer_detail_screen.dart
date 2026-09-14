import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/loyalty_customer.dart';
import '../providers/loyalty_admin_providers.dart';
import '../widgets/loyalty_adjust_points_dialog.dart';
import '../widgets/loyalty_retention_badge.dart';

/// One loyalty member's profile with this business -- balance, lifetime
/// earned/redeemed, visits, expiring-soon points, retention status, and the
/// owner's one write action here: a manual balance adjustment, gated behind
/// [showLoyaltyAdjustPointsDialog]'s reason-required confirm flow.
class LoyaltyCustomerDetailScreen extends ConsumerWidget {
  final String providerId;
  final String userId;

  const LoyaltyCustomerDetailScreen({super.key, required this.providerId, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final key = (providerId, userId);
    final customerAsync = ref.watch(loyaltyCustomerDetailProvider(key));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: customerAsync.value?.displayName ?? l10n.loyaltyCustomerDetailTitle),
      body: customerAsync.when(
        data: (customer) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(loyaltyCustomerDetailProvider(key)),
          child: ListView(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            children: [
              _ProfileCard(customer: customer),
              const SizedBox(height: FactorySpacing.space5),
              FactoryButton(
                label: l10n.loyaltyAdjustPointsButton,
                icon: Icons.tune,
                expand: true,
                onPressed: () async {
                  final adjusted = await showLoyaltyAdjustPointsDialog(
                    context,
                    providerId: providerId,
                    userId: userId,
                    currentBalance: customer.pointsBalance,
                  );
                  if (adjusted == true) {
                    invalidateLoyaltyCustomerData(ref, providerId, userId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(l10n.loyaltyAdjustPointsSuccessMessage)));
                    }
                  }
                },
              ),
            ],
          ),
        ),
        loading: () => const FactoryLoadingState(),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorLoyaltyCustomersLoadFailed(error.toString()),
              onRetry: () => ref.invalidate(loyaltyCustomerDetailProvider(key)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final LoyaltyCustomerInsight customer;

  const _ProfileCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  customer.displayName ?? customer.email ?? '—',
                  style: textTheme.titleMedium,
                ),
              ),
              LoyaltyRetentionBadge(status: customer.retentionStatus),
            ],
          ),
          if (customer.email != null && customer.displayName != null) ...[
            const SizedBox(height: 2),
            Text(customer.email!, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
          ],
          const SizedBox(height: FactorySpacing.space4),
          Wrap(
            spacing: FactorySpacing.space5,
            runSpacing: FactorySpacing.space4,
            children: [
              FactoryStatTile(label: l10n.loyaltyCustomerDetailBalance, value: '${customer.pointsBalance}'),
              FactoryStatTile(label: l10n.loyaltyCustomerDetailLifetimeEarned, value: '${customer.lifetimeEarned}'),
              FactoryStatTile(label: l10n.loyaltyCustomerDetailLifetimeRedeemed, value: '${customer.lifetimeRedeemed}'),
              FactoryStatTile(label: l10n.loyaltyCustomerDetailVisits, value: '${customer.completedVisits}'),
              if (customer.pointsExpiringSoon30d > 0)
                FactoryStatTile(
                  label: l10n.loyaltyCustomerDetailExpiringSoon,
                  value: '${customer.pointsExpiringSoon30d}',
                ),
            ],
          ),
          if (customer.lastActivityAt != null) ...[
            const SizedBox(height: FactorySpacing.space3),
            Text(
              l10n.loyaltyCustomerLastActivityLabel(DateFormat.yMMMd(locale).format(customer.lastActivityAt!.toLocal())),
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
