import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../../finance/data/finance_api.dart';
import '../data/dashboard_api.dart';
import '../data/dashboard_metrics.dart';

/// The landing page: first what needs a person today (businesses waiting for
/// approval, refunds that failed, payouts waiting to be paid), then the
/// numbers — businesses, bookings, payments, revenue, users, subscriptions.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final payable = ref.watch(payoutsProvider('PAYABLE'));
    final name = ref.watch(sessionControllerProvider).value?.admin.displayName ?? '';

    Future<void> refresh() {
      ref.invalidate(payoutsProvider('PAYABLE'));
      return ref.refresh(dashboardMetricsProvider.future).then((_) {});
    }

    return AreaScaffold(
      title: l10n.navDashboard,
      actions: [IconButton(tooltip: l10n.refresh, icon: const Icon(Icons.refresh_rounded), onPressed: refresh)],
      body: AsyncView<DashboardMetrics>(
        value: metricsAsync,
        onRetry: () => ref.invalidate(dashboardMetricsProvider),
        builder: (m) => ContentFrame(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(FactorySpacing.space4),
              children: [
                Text(l10n.dashboardGreeting(name.split(' ').first), style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: FactorySpacing.space4),
                _Attention(metrics: m, payableCount: payable.value?.length ?? 0),
                const SizedBox(height: FactorySpacing.space5),
                _Section(
                  title: l10n.dashSectionBusinesses,
                  actionLabel: l10n.dashOpen,
                  onAction: () => context.go(ConsoleRoutes.businesses),
                  tiles: [
                    _Stat(l10n.dashTotal, m.businessesTotal),
                    _Stat(l10n.statusActive, m.businessesActive),
                    _Stat(l10n.businessPending, m.businessesPending, warn: m.businessesPending > 0),
                    _Stat(l10n.businessSuspended, m.businessesBlocked),
                  ],
                ),
                _Section(
                  title: l10n.dashSectionBookings,
                  tiles: [
                    _Stat(l10n.dashToday, m.bookingsToday),
                    _Stat(l10n.dashThisWeek, m.bookingsWeek),
                    _Stat(l10n.dashThisMonth, m.bookingsMonth),
                    _Stat(l10n.dashCompleted, m.bookingsCompleted),
                    _Stat(l10n.dashCancelled, m.bookingsCancelled),
                  ],
                ),
                _Section(
                  title: l10n.dashSectionRevenue,
                  subtitle: l10n.dashRevenueNote,
                  tiles: [
                    _Money(l10n.dashSubscriptionRevenue, m.mrr, m.currency),
                    _Money(l10n.dashCommission, m.platformCommission, m.commissionCurrency),
                  ],
                ),
                _Section(
                  title: l10n.dashSectionPayments,
                  actionLabel: l10n.navFinance,
                  onAction: () => context.go(ConsoleRoutes.finance),
                  tiles: [
                    _Stat(l10n.paymentSucceeded, m.paymentsSucceeded),
                    _Stat(l10n.paymentPending, m.paymentsPending),
                    _Stat(l10n.paymentFailed, m.paymentsFailed, warn: m.paymentsFailed > 0),
                    _Stat(l10n.paymentRefunded, m.paymentsRefunded),
                    _Stat(l10n.paymentRefundFailed, m.paymentsRefundFailed, warn: m.paymentsRefundFailed > 0),
                  ],
                ),
                _Section(
                  title: l10n.dashSectionSubscriptions,
                  tiles: [
                    _Stat(l10n.dashPlanFree, m.subsFree),
                    _Stat(l10n.dashPlanPro, m.subsPro),
                    _Stat(l10n.statusActive, m.subsActive),
                    _Stat(l10n.dashPastDue, m.subsPastDue, warn: m.subsPastDue > 0),
                    _Stat(l10n.dashCancelled, m.subsCancelled),
                  ],
                ),
                _Section(title: l10n.dashSectionUsers, tiles: [_Stat(l10n.dashTotal, m.users)]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Attention extends StatelessWidget {
  const _Attention({required this.metrics, required this.payableCount});

  final DashboardMetrics metrics;
  final int payableCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = <_AttentionItem>[
      if (metrics.businessesPending > 0)
        _AttentionItem(
          icon: Icons.pending_actions_rounded,
          text: l10n.attentionPendingBusinesses(metrics.businessesPending),
          action: l10n.attentionReview,
          path: '${ConsoleRoutes.businesses}?status=PENDING',
        ),
      if (metrics.paymentsRefundFailed > 0)
        _AttentionItem(
          icon: Icons.error_outline_rounded,
          text: l10n.attentionFailedRefunds(metrics.paymentsRefundFailed),
          action: l10n.attentionReview,
          path: '${ConsoleRoutes.finance}?tab=refunds',
        ),
      if (payableCount > 0)
        _AttentionItem(
          icon: Icons.payments_outlined,
          text: l10n.attentionPayablePayouts(payableCount),
          action: l10n.attentionReview,
          path: ConsoleRoutes.finance,
        ),
    ];
    final colors = context.factoryColors;
    if (items.isEmpty) {
      return FactoryCard(
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: colors.success),
            const SizedBox(width: FactorySpacing.space3),
            Expanded(child: Text(l10n.attentionAllClear)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(title: l10n.attentionTitle),
        const SizedBox(height: FactorySpacing.space2),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
            child: FactoryCard(
              padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4, vertical: FactorySpacing.space2),
              child: Row(
                children: [
                  Icon(item.icon, color: colors.error),
                  const SizedBox(width: FactorySpacing.space3),
                  Expanded(child: Text(item.text, style: Theme.of(context).textTheme.bodyMedium)),
                  TextButton(onPressed: () => context.go(item.path), child: Text(item.action)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AttentionItem {
  const _AttentionItem({required this.icon, required this.text, required this.action, required this.path});

  final IconData icon;
  final String text;
  final String action;
  final String path;
}

abstract class _Tile {
  const _Tile(this.label);
  final String label;
  String value(String locale);
  bool get warn => false;
}

class _Stat extends _Tile {
  const _Stat(super.label, this.count, {this.warn = false});
  final int count;
  @override
  final bool warn;
  @override
  String value(String locale) => formatCount(locale, count);
}

class _Money extends _Tile {
  const _Money(super.label, this.amount, this.currency);
  final num amount;
  final String? currency;
  @override
  String value(String locale) => currency == null ? '—' : formatMoney(locale, amount, currency);
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.tiles, this.subtitle, this.actionLabel, this.onAction});

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: FactorySpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FactorySectionHeader(title: title, actionLabel: actionLabel, onActionTap: onAction),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
            ),
          const SizedBox(height: FactorySpacing.space2),
          AdaptiveGrid(
            minTileWidth: 150,
            maxColumns: 5,
            children: [
              for (final tile in tiles)
                FactoryCard(
                  padding: const EdgeInsets.all(FactorySpacing.space3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tile.label, style: textTheme.labelMedium?.copyWith(color: colors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        tile.value(locale),
                        // Figures are data: mono + tabular so a column of
                        // tiles lines up; warnings use the AA-safe error hue.
                        style: FactoryTypography.mono(
                          size: 22,
                          weight: FontWeight.w600,
                          color: tile.warn ? colors.error : colors.text,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
