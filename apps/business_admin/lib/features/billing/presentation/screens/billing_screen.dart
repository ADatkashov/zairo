import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../../data/models/payment_method.dart';
import '../../data/models/subscription.dart';
import '../../data/models/subscription_charge.dart';
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

/// What the screen is waiting to see after the owner was sent to pay in the browser.
enum _PendingPayment { upgrade, renewal }

class _BillingBodyState extends ConsumerState<_BillingBody> with WidgetsBindingObserver {
  /// About five minutes of polling at the default interval, then we stop and let the owner pull to check.
  static const _maxPolls = 100;

  bool _isSubmitting = false;
  bool _isRetryingCharge = false;
  String? _error;
  _PendingPayment? _pendingPayment;
  Timer? _pollTimer;
  int _polls = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the browser: check straight away instead of waiting for the next poll.
    if (state == AppLifecycleState.resumed && _pendingPayment != null) _refresh();
  }

  @override
  void didUpdateWidget(_BillingBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pending = _pendingPayment;
    if (pending == null) return;
    final done = switch (pending) {
      _PendingPayment.upgrade => widget.subscription.isPro,
      _PendingPayment.renewal => widget.subscription.status != 'PAST_DUE',
    };
    if (!done) return;
    _stopWaiting();
    final l10n = AppLocalizations.of(context)!;
    // Providers can't be invalidated while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(myChargesProvider);
      ref.invalidate(myPaymentMethodProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pending == _PendingPayment.upgrade ? l10n.billingUpgradeConfirmed : l10n.billingGracePeriodFixSucceeded,
          ),
        ),
      );
    });
  }

  void _refresh() {
    ref.invalidate(mySubscriptionProvider);
    ref.invalidate(myChargesProvider);
  }

  void _stopWaiting() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pendingPayment = null;
    _polls = 0;
  }

  /// Sends the owner to the provider's payment page and starts watching the
  /// server for the provider's webhook — the browser coming back proves nothing by itself.
  Future<void> _openCheckout(String url, _PendingPayment pending) async {
    final l10n = AppLocalizations.of(context)!;
    var opened = false;
    try {
      opened = await ref.read(billingCheckoutLauncherProvider)(Uri.parse(url));
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    if (!opened) {
      setState(() => _error = l10n.billingCheckoutOpenFailed);
      return;
    }
    final interval = ref.read(billingPollIntervalProvider);
    _pollTimer?.cancel();
    setState(() {
      _pendingPayment = pending;
      _polls = 0;
    });
    _pollTimer = Timer.periodic(interval, (timer) {
      if (!mounted) return;
      if (++_polls > _maxPolls) {
        setState(_stopWaiting);
        return;
      }
      _refresh();
    });
  }

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
        _PlanHero(
          planLabel: _planLabel(l10n, subscription.plan),
          badge: FactoryBadge(
            label: _statusLabel(l10n, subscription.status),
            variant: _statusVariant(subscription.status),
          ),
          priceRow: subscription.isPro || subscription.proMonthlyPrice == null
              ? null
              : Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(
                      '${l10n.billingProPriceLabel} ',
                      style: textTheme.bodySmall?.copyWith(color: colors.onPrimary.withValues(alpha: 0.8)),
                    ),
                    FactoryPriceText(
                      amount: subscription.proMonthlyPrice!,
                      currencySymbol: subscription.currency,
                      color: colors.onPrimary,
                    ),
                    Text(
                      l10n.billingPerMonthSuffix,
                      style: textTheme.bodySmall?.copyWith(color: colors.onPrimary.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
          notice: subscription.cancelAtPeriodEnd
              ? l10n.billingDowngradeScheduledNotice(_formatDate(subscription.currentPeriodEnd))
              : null,
        ),
        if (subscription.status == 'PAST_DUE' && subscription.gracePeriodEndsAt != null) ...[
          const SizedBox(height: FactorySpacing.space3),
          _GracePeriodBanner(
            gracePeriodEndsAt: subscription.gracePeriodEndsAt!,
            isRetrying: _isRetryingCharge,
            onFix: _retryCharge,
          ),
        ],
        if (_pendingPayment != null) ...[
          const SizedBox(height: FactorySpacing.space3),
          _WaitingForPaymentBanner(
            onCheckNow: _refresh,
            onDismiss: () => setState(_stopWaiting),
          ),
        ],
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
              if (providerCount != null && subscription.limits.maxProviders > 0) ...[
                const SizedBox(height: FactorySpacing.space2),
                _UsageBar(used: providerCount, limit: subscription.limits.maxProviders),
              ],
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
        if (subscription.isPro) ...[
          const SizedBox(height: FactorySpacing.space4),
          Text(l10n.billingPaymentMethodTitle, style: textTheme.titleSmall),
          const SizedBox(height: FactorySpacing.space2),
          _PaymentMethodSection(subscription: subscription),
        ],
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
        const SizedBox(height: FactorySpacing.space6),
        Text(l10n.billingInvoicesSectionTitle, style: textTheme.titleSmall),
        const SizedBox(height: FactorySpacing.space2),
        const _InvoicesSection(),
      ],
    );
  }

  Future<void> _retryCharge() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isRetryingCharge = true);
    try {
      final updated = await ref.read(billingApiProvider).retryPastDueCharge();
      final checkoutUrl = updated.checkoutUrl;
      if (checkoutUrl != null) {
        // The provider can't charge the stored card by itself: pay this renewal on its page.
        await _openCheckout(checkoutUrl, _PendingPayment.renewal);
        return;
      }
      ref.invalidate(mySubscriptionProvider);
      ref.invalidate(myChargesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.status == 'PAST_DUE' ? l10n.billingGracePeriodFixFailed : l10n.billingGracePeriodFixSucceeded,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.billingGracePeriodFixFailed)));
    } finally {
      if (mounted) setState(() => _isRetryingCharge = false);
    }
  }

  Future<void> _upgrade() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(billingApiProvider).upgradeToPro();
      final checkoutUrl = result.checkoutUrl;
      if (checkoutUrl != null) {
        await _openCheckout(checkoutUrl, _PendingPayment.upgrade);
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }
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

class _WaitingForPaymentBanner extends StatelessWidget {
  const _WaitingForPaymentBanner({required this.onCheckNow, required this.onDismiss});

  final VoidCallback onCheckNow;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3, vertical: FactorySpacing.space2),
      decoration: BoxDecoration(
        color: colors.primaryTint,
        borderRadius: FactoryRadius.mdRadius,
      ),
      child: Row(
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(child: Text(l10n.billingWaitingForPayment, style: Theme.of(context).textTheme.bodySmall)),
          TextButton(onPressed: onCheckNow, child: Text(l10n.billingWaitingCheckNow)),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ],
      ),
    );
  }
}

/// The card the subscription renews with: brand and last four digits only,
/// whether it renews by itself, and a way to forget it.
class _PaymentMethodSection extends ConsumerWidget {
  const _PaymentMethodSection({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final methodAsync = ref.watch(myPaymentMethodProvider);

    return methodAsync.when(
      loading: () => const LinearProgressIndicator(),
      // The card is a convenience line; a failed lookup must not break the rest of the screen.
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (method) => FactoryCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!method.saved)
              Text(l10n.billingNoSavedCard, style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary))
            else ...[
              Row(
                children: [
                  Icon(Icons.credit_card_rounded, color: colors.textSecondary),
                  const SizedBox(width: FactorySpacing.space2),
                  Text(
                    _cardLabel(l10n, method),
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: FactorySpacing.space2),
              Text(
                method.autoRenew
                    ? l10n.billingAutoRenewOn(_formatDate(subscription.currentPeriodEnd))
                    : l10n.billingManualRenewal,
                style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              ),
              const SizedBox(height: FactorySpacing.space2),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => _confirmRemove(context, ref),
                  child: Text(l10n.billingRemoveCardButton),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.billingRemoveCardTitle),
        content: Text(l10n.billingRemoveCardBody(_formatDate(subscription.currentPeriodEnd))),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.billingRemoveCardKeep)),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.billingRemoveCardConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(billingApiProvider).removePaymentMethod();
      ref.invalidate(myPaymentMethodProvider);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.billingRemoveCardFailed)));
    }
  }
}

String _cardLabel(AppLocalizations l10n, PaymentMethod method) =>
    l10n.billingCardLabel(method.brand ?? l10n.billingCardGenericBrand, method.last4 ?? '••••');

/// Board 16 (v2 design audit) — surfaces [Subscription.gracePeriodEndsAt],
/// which the model already carried but no screen ever rendered: an owner
/// whose renewal charge failed had no way to know PRO was about to lapse.
class _GracePeriodBanner extends StatelessWidget {
  const _GracePeriodBanner({required this.gracePeriodEndsAt, required this.isRetrying, required this.onFix});

  final DateTime gracePeriodEndsAt;
  final bool isRetrying;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final daysLeft = gracePeriodEndsAt.difference(DateTime.now()).inDays;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3, vertical: FactorySpacing.space3),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.08),
        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
        borderRadius: FactoryRadius.mdRadius,
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.error, size: 20),
          const SizedBox(width: FactorySpacing.space2),
          Expanded(
            child: Text(
              daysLeft <= 0 ? l10n.billingGracePeriodExpiringToday : l10n.billingGracePeriodBanner(daysLeft),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ),
          const SizedBox(width: FactorySpacing.space2),
          FactoryButton(
            label: l10n.billingGracePeriodFixButton,
            variant: FactoryButtonVariant.danger,
            isLoading: isRetrying,
            onPressed: isRetrying ? null : onFix,
          ),
        ],
      ),
    );
  }
}

/// Board 16 (v2 design audit) — [SubscriptionCharge] rows existed in the
/// backend already (the renewal job's own idempotency ledger); this is the
/// first screen that reads them back for the owner.
class _InvoicesSection extends ConsumerWidget {
  const _InvoicesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final chargesAsync = ref.watch(myChargesProvider);

    return chargesAsync.when(
      data: (charges) {
        if (charges.isEmpty) {
          return Text(
            l10n.billingInvoicesEmpty,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          );
        }
        return FactoryCard(
          child: Column(
            children: [
              for (final charge in charges) ...[
                if (charge != charges.first) const Divider(height: FactorySpacing.space5),
                _InvoiceRow(charge: charge),
              ],
            ],
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.charge});

  final SubscriptionCharge charge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FactoryPriceText(
              amount: charge.amount,
              currencySymbol: charge.currency,
              fontSize: 14,
              weight: FontWeight.w600,
            ),
            Text(_formatDate(charge.createdAt), style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
          ],
        ),
        FactoryBadge(label: _invoiceStatusLabel(l10n, charge.status), variant: _invoiceStatusVariant(charge.status)),
      ],
    );
  }
}

/// Gradient plan card in the same treatment as the dashboard hero: the plan
/// is the one big thing on this screen, everything else is secondary.
class _PlanHero extends StatelessWidget {
  const _PlanHero({required this.planLabel, required this.badge, this.priceRow, this.notice});

  final String planLabel;
  final Widget badge;
  final Widget? priceRow;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final radius = context.factoryProfileOrNull?.cardBorderRadius ?? FactoryRadius.xlRadius;
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(planLabel, style: textTheme.headlineSmall?.copyWith(color: colors.onPrimary)),
              ),
              const SizedBox(width: FactorySpacing.space3),
              badge,
            ],
          ),
          if (priceRow != null) ...[const SizedBox(height: FactorySpacing.space2), priceRow!],
          if (notice != null) ...[
            const SizedBox(height: FactorySpacing.space3),
            Text(notice!, style: textTheme.bodySmall?.copyWith(color: colors.onPrimary)),
          ],
        ],
      ),
    );
  }
}

/// Thin animated meter under a "used of limit" row; turns to the warning
/// color once the limit is reached, so a full plan reads without the number.
class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.used, required this.limit});

  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final fraction = (used / limit).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(FactoryRadius.sm),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fraction),
        duration: FactoryMotion.resolve(context, FactoryMotion.slow),
        curve: FactoryMotion.standard,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: 6,
          backgroundColor: colors.primaryTint,
          color: fraction >= 1 ? colors.warning : colors.primary,
        ),
      ),
    );
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
    // The label gives way (and wraps) on a narrow screen; the value never does.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
        ),
        const SizedBox(width: FactorySpacing.space3),
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

String _invoiceStatusLabel(AppLocalizations l10n, String status) => switch (status) {
  'SUCCEEDED' => l10n.billingInvoiceStatusSucceeded,
  'FAILED' => l10n.billingInvoiceStatusFailed,
  _ => l10n.billingInvoiceStatusPending,
};

FactoryBadgeVariant _invoiceStatusVariant(String status) => switch (status) {
  'SUCCEEDED' => FactoryBadgeVariant.available,
  'FAILED' => FactoryBadgeVariant.error,
  _ => FactoryBadgeVariant.neutral,
};
