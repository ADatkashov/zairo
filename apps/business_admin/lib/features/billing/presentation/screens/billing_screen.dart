import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../../data/models/subscription.dart';
import '../providers/billing_providers.dart';

/// The owner's tariff plan: current plan, its limits, how many businesses
/// they're actually using against that limit, and the upgrade/downgrade
/// action — reached from Settings.
class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final subscriptionAsync = ref.watch(mySubscriptionProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.billingScreenTitle),
      body: subscriptionAsync.when(
        data: (subscription) => _BillingBody(subscription: subscription),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorBillingLoadFailed,
              onRetry: () => ref.invalidate(mySubscriptionProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _BillingBody extends ConsumerStatefulWidget {
  const _BillingBody({required this.subscription});

  final Subscription subscription;

  @override
  ConsumerState<_BillingBody> createState() => _BillingBodyState();
}

class _BillingBodyState extends ConsumerState<_BillingBody> {
  bool _isSubmitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final subscription = widget.subscription;
    final user = ref.watch(authControllerProvider).value;
    final providerCount = user == null ? null : ref.watch(myProvidersProvider(user.id)).value?.length;

    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.space4),
      children: [
        FactoryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_planLabel(l10n, subscription.plan), style: textTheme.titleMedium),
                  const SizedBox(width: FactorySpacing.space2),
                  FactoryBadge(
                    label: _statusLabel(l10n, subscription.status),
                    variant: _statusVariant(subscription.status),
                  ),
                ],
              ),
              if (!subscription.isPro) ...[
                const SizedBox(height: FactorySpacing.space2),
                Row(
                  children: [
                    Text('${l10n.billingProPriceLabel} ', style: textTheme.bodySmall),
                    FactoryPriceText(amount: 29),
                    Text(l10n.billingPerMonthSuffix, style: textTheme.bodySmall),
                  ],
                ),
              ],
              if (subscription.cancelAtPeriodEnd) ...[
                const SizedBox(height: FactorySpacing.space3),
                Text(
                  l10n.billingDowngradeScheduledNotice(_formatDate(subscription.currentPeriodEnd)),
                  style: textTheme.bodySmall?.copyWith(color: colors.warning),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: FactorySpacing.space4),
        Text(l10n.billingUsageSectionTitle, style: textTheme.titleSmall),
        const SizedBox(height: FactorySpacing.space2),
        FactoryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LimitRow(
                label: l10n.billingLimitProvidersLabel,
                value: providerCount == null
                    ? l10n.billingUsageXOfY(0, subscription.limits.maxProviders)
                    : l10n.billingUsageXOfY(providerCount, subscription.limits.maxProviders),
              ),
              const SizedBox(height: FactorySpacing.space2),
              _LimitRow(
                label: l10n.billingLimitStaffLabel,
                value: l10n.billingLimitStaffValue(subscription.limits.maxStaffPerProvider),
              ),
              const SizedBox(height: FactorySpacing.space2),
              _LimitRow(
                label: l10n.billingLimitBookingsLabel,
                value: subscription.limits.isUnlimitedBookings
                    ? l10n.billingLimitUnlimited
                    : l10n.billingLimitBookingsValue(subscription.limits.maxBookingsPerMonth),
              ),
              const SizedBox(height: FactorySpacing.space2),
              _LimitRow(
                label: l10n.billingLimitRecurringScheduleLabel,
                value: subscription.limits.recurringScheduleAllowed
                    ? l10n.billingFeatureIncluded
                    : l10n.billingFeatureRequiresPro,
              ),
            ],
          ),
        ),
        const SizedBox(height: FactorySpacing.space4),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
            child: Text(_error!, style: TextStyle(color: colors.error)),
          ),
        if (!subscription.isPro)
          FactoryButton(
            label: l10n.billingUpgradeButtonLabel,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _upgrade,
          )
        else if (!subscription.cancelAtPeriodEnd)
          FactoryButton(
            label: l10n.billingDowngradeButtonLabel,
            variant: FactoryButtonVariant.secondary,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _downgrade,
          ),
      ],
    );
  }

  Future<void> _upgrade() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(billingApiProvider).upgradeToPro();
      ref.invalidate(mySubscriptionProvider);
      // _BillingBody has no Key, so a rebuild with fresh `subscription` data
      // reuses this State object rather than creating a new one — reset
      // _isSubmitting explicitly, or the button's spinner would animate
      // forever (pumpAndSettle would never resolve in tests, and a real
      // user would see a stuck button).
      if (mounted) setState(() => _isSubmitting = false);
    } catch (e) {
      setState(() {
        _error = l10n.errorBillingUpgradeFailed;
        _isSubmitting = false;
      });
    }
  }

  Future<void> _downgrade() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(billingApiProvider).downgradeToFree();
      ref.invalidate(mySubscriptionProvider);
      if (mounted) setState(() => _isSubmitting = false);
    } catch (e) {
      setState(() => _isSubmitting = false);
    }
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
        Text(value, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

String _planLabel(AppLocalizations l10n, String plan) => switch (plan) {
      'PRO' => l10n.billingPlanPro,
      _ => l10n.billingPlanFree,
    };

String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
      'ACTIVE' => l10n.billingStatusActive,
      'PAST_DUE' => l10n.billingStatusPastDue,
      _ => l10n.billingStatusActive,
    };

FactoryBadgeVariant _statusVariant(String status) => switch (status) {
      'PAST_DUE' => FactoryBadgeVariant.error,
      _ => FactoryBadgeVariant.available,
    };

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
