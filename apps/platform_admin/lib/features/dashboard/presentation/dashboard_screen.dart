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
import '../data/dashboard_trends.dart';

/// The landing page, in the order of a glance: first what needs a person today
/// (businesses waiting for approval, refunds that failed, payouts waiting to be
/// paid), then four headline numbers (revenue, commission, bookings with their
/// trend, users), then how businesses, bookings, payments and subscriptions
/// break down. Every figure that has a list behind it opens that list.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final payable = ref.watch(payoutsProvider('PAYABLE'));
    final trends = ref.watch(dashboardTrendsProvider).value ?? const DashboardTrends.empty();
    final name = ref.watch(sessionControllerProvider).value?.admin.displayName ?? '';

    Future<void> refresh() {
      ref.invalidate(payoutsProvider('PAYABLE'));
      ref.invalidate(dashboardTrendsProvider);
      return ref.refresh(dashboardMetricsProvider.future).then((_) {});
    }

    return AreaScaffold(
      title: l10n.navDashboard,
      actions: [
        IconButton(
          tooltip: l10n.navReports,
          icon: const Icon(Icons.insert_chart_outlined_rounded),
          onPressed: () => context.go(ConsoleRoutes.reports),
        ),
        IconButton(tooltip: l10n.refresh, icon: const Icon(Icons.refresh_rounded), onPressed: refresh),
      ],
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
                const SizedBox(height: FactorySpacing.space4),
                _Headline(metrics: m, trends: trends),
                const SizedBox(height: FactorySpacing.space4),
                _Breakdowns(metrics: m),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything that waits on a person, most urgent first, as one red panel whose
/// rows each open the place where it is dealt with. With nothing waiting, a
/// calm one-liner says so.
class _Attention extends StatelessWidget {
  const _Attention({required this.metrics, required this.payableCount});

  final DashboardMetrics metrics;
  final int payableCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    void open(String path) => context.go(path);
    final items = <FactoryAlertItem>[
      if (metrics.businessesPending > 0)
        FactoryAlertItem(
          icon: Icons.pending_actions_rounded,
          label: l10n.attentionPendingBusinesses(metrics.businessesPending),
          actionLabel: l10n.attentionReview,
          onTap: () => open('${ConsoleRoutes.businesses}?status=PENDING'),
        ),
      if (metrics.reviewsReported > 0)
        FactoryAlertItem(
          icon: Icons.rate_review_outlined,
          label: l10n.attentionReportedReviews(metrics.reviewsReported),
          actionLabel: l10n.attentionReview,
          onTap: () => open(ConsoleRoutes.reviews),
        ),
      if (metrics.paymentsRefundFailed > 0)
        FactoryAlertItem(
          icon: Icons.error_outline_rounded,
          label: l10n.attentionFailedRefunds(metrics.paymentsRefundFailed),
          actionLabel: l10n.attentionReview,
          onTap: () => open('${ConsoleRoutes.finance}?tab=refunds'),
        ),
      if (payableCount > 0)
        FactoryAlertItem(
          icon: Icons.payments_outlined,
          label: l10n.attentionPayablePayouts(payableCount),
          actionLabel: l10n.attentionReview,
          onTap: () => open(ConsoleRoutes.finance),
        ),
    ];
    if (items.isEmpty) return FactoryAlertPanel.allClear(title: l10n.attentionAllClear);
    return FactoryAlertPanel(title: l10n.attentionTitle, count: items.length, items: items);
  }
}

/// Four numbers that say how the platform is doing: money in from subscriptions
/// and from commission, bookings over the last two weeks (with the trend line and
/// the change against the week before), and how many people use it.
class _Headline extends StatelessWidget {
  const _Headline({required this.metrics, required this.trends});

  final DashboardMetrics metrics;
  final DashboardTrends trends;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final locale = Localizations.localeOf(context).toString();
    final m = metrics;
    String money(num amount, String? currency) => currency == null ? '—' : formatMoney(locale, amount, currency);

    final hasTrend = trends.bookingsCreated.length >= 2;
    final change = trends.bookingsWeekChange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactoryMetricGrid(
          minTileWidth: 160,
          maxColumns: 4,
          equalHeight: true,
          children: [
            FactoryKpiCard(
              label: l10n.dashSubscriptionRevenue,
              value: money(m.mrr, m.currency),
              caption: l10n.dashSectionRevenue,
              icon: Icons.workspace_premium_rounded,
              accent: colors.primary,
            ),
            FactoryKpiCard(
              label: l10n.dashCommission,
              value: money(m.platformCommission, m.commissionCurrency),
              caption: l10n.dashSectionRevenue,
              icon: Icons.percent_rounded,
              accent: colors.mint,
            ),
            FactoryKpiCard(
              label: hasTrend ? l10n.dashBookingsLastDays(trends.bookingsCreated.length) : l10n.dashThisWeek,
              value: formatCount(locale, hasTrend ? trends.bookingsTotal.round() : m.bookingsWeek),
              icon: Icons.event_available_rounded,
              accent: colors.coral,
              delta: change,
              caption: change == null ? null : l10n.dashVsPrevious7,
              trend: hasTrend ? trends.bookingsCreated : null,
              trendLabel: hasTrend ? l10n.dashBookingsLastDays(trends.bookingsCreated.length) : null,
            ),
            FactoryKpiCard(
              label: l10n.dashSectionUsers,
              value: formatCount(locale, m.users),
              icon: Icons.people_alt_rounded,
              accent: colors.lavender,
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.space2),
        Text(
          l10n.dashRevenueNote,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
        ),
      ],
    );
  }
}

/// How the platform splits: businesses by status, bookings by outcome, payments
/// by state, subscriptions by plan. Each is a ring with a legend whose rows that
/// have a list behind them open it, filtered the same way (a tap on "Awaiting
/// approval 3" lists exactly those three).
class _Breakdowns extends StatelessWidget {
  const _Breakdowns({required this.metrics});

  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final locale = Localizations.localeOf(context).toString();
    final m = metrics;
    String n(num value) => formatCount(locale, value);
    void open(String path) => context.go(path);

    FactoryChartSegment seg(String label, int value, Color color, {String? path}) => FactoryChartSegment(
      label: label,
      value: value.toDouble(),
      valueLabel: n(value),
      color: color,
      onTap: path == null ? null : () => open(path),
    );

    // Businesses in a state the dashboard has no name for (archived, rejected) still count in the total.
    final named = m.businessesActive + m.businessesPending + m.businessesBlocked;
    final otherBusinesses = (m.businessesTotal - named).clamp(0, m.businessesTotal);

    return FactoryMetricGrid(
      minTileWidth: 330,
      maxColumns: 2,
      equalHeight: true,
      children: [
        _BreakdownCard(
          title: l10n.dashSectionBusinesses,
          subtitle: l10n.dashTotalCount(n(m.businessesTotal)),
          actionLabel: l10n.dashOpen,
          onAction: () => open(ConsoleRoutes.businesses),
          centerLabel: n(m.businessesTotal),
          segments: [
            seg(l10n.statusActive, m.businessesActive, colors.success, path: '${ConsoleRoutes.businesses}?status=ACTIVE'),
            seg(l10n.businessPending, m.businessesPending, colors.warning, path: '${ConsoleRoutes.businesses}?status=PENDING'),
            seg(l10n.businessSuspended, m.businessesBlocked, colors.error, path: '${ConsoleRoutes.businesses}?status=SUSPENDED'),
            seg(l10n.dashOther, otherBusinesses, colors.textTertiary),
          ],
        ),
        _BreakdownCard(
          title: l10n.dashSectionBookings,
          subtitle: l10n.dashBookingsPeriods(n(m.bookingsToday), n(m.bookingsWeek), n(m.bookingsMonth)),
          centerLabel: n(m.bookingsCompleted + m.bookingsCancelled),
          segments: [
            seg(l10n.dashCompleted, m.bookingsCompleted, colors.success),
            seg(l10n.dashCancelled, m.bookingsCancelled, colors.error),
          ],
        ),
        _BreakdownCard(
          title: l10n.dashSectionPayments,
          actionLabel: l10n.navFinance,
          onAction: () => open(ConsoleRoutes.finance),
          centerLabel: n(m.paymentsSucceeded + m.paymentsPending + m.paymentsFailed + m.paymentsRefunded + m.paymentsRefundFailed),
          segments: [
            seg(l10n.paymentSucceeded, m.paymentsSucceeded, colors.success),
            seg(l10n.paymentPending, m.paymentsPending, colors.warning),
            seg(l10n.paymentFailed, m.paymentsFailed, colors.error),
            seg(l10n.paymentRefunded, m.paymentsRefunded, colors.info),
            seg(l10n.paymentRefundFailed, m.paymentsRefundFailed, colors.coral, path: '${ConsoleRoutes.finance}?tab=refunds'),
          ],
        ),
        _BreakdownCard(
          title: l10n.dashSectionSubscriptions,
          subtitle: l10n.dashSubscriptionStates(n(m.subsActive), n(m.subsPastDue), n(m.subsCancelled)),
          centerLabel: n(m.subsFree + m.subsPro),
          segments: [
            seg(l10n.dashPlanPro, m.subsPro, colors.primary),
            seg(l10n.dashPlanFree, m.subsFree, colors.lavender),
          ],
        ),
      ],
    );
  }
}

/// One ring with its title, an optional one-line summary and an optional link to
/// the area behind it. Holds no LayoutBuilder (the grid equalises card heights),
/// so it picks its ring size and legend position from the screen instead of from
/// its own width: smaller on a phone, legend under the ring at a large font.
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.centerLabel,
    required this.segments,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String centerLabel;
  final List<FactoryChartSegment> segments;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final phone = MediaQuery.sizeOf(context).width < 480;
    final bigFont = MediaQuery.textScalerOf(context).scale(16) > 22;

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Not FactorySectionHeader: it measures itself with a LayoutBuilder, which the grid's
          // equal-height rows cannot contain.
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(color: colors.text, fontWeight: FontWeight.w700),
                ),
              ),
              if (actionLabel != null && onAction != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
            ),
          const SizedBox(height: FactorySpacing.space3),
          FactoryDonutChart(
            size: phone ? 104 : 132,
            stacked: bigFont,
            centerLabel: centerLabel,
            segments: segments,
            semanticLabel: title,
          ),
        ],
      ),
    );
  }
}
