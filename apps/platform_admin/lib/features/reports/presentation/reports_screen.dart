import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../data/platform_report.dart';
import '../data/report_api.dart';

/// Platform reports: what the marketplace earned and how bookings moved over a
/// window of recent days — commission and subscription revenue as trend lines,
/// bookings created per day, and a donut of where this window's bookings stand.
/// The window filter sits beside the charts on a wide screen, above them on a phone.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  static const windows = [7, 30, 90];
  static const defaultWindow = 30;

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  static const _wideBreakpoint = 840.0;

  int _days = ReportsScreen.defaultWindow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reportAsync = ref.watch(platformReportProvider(_days));

    final panel = FactoryFilterPanel(
      title: l10n.reportsFiltersTitle,
      resetLabel: l10n.reportsReset,
      onReset: _days == ReportsScreen.defaultWindow ? null : () => setState(() => _days = ReportsScreen.defaultWindow),
      children: [
        FactoryFilterField(
          label: l10n.reportsPeriodLabel,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final days in ReportsScreen.windows)
                FactoryChip(
                  label: l10n.reportsLastDays(days),
                  selected: _days == days,
                  onTap: () => setState(() => _days = days),
                ),
            ],
          ),
        ),
      ],
    );

    return AreaScaffold(
      title: l10n.navReports,
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.go(ConsoleRoutes.dashboard),
      ),
      body: AsyncView<PlatformReport>(
        value: reportAsync,
        onRetry: () => ref.invalidate(platformReportProvider(_days)),
        builder: (report) {
          final cards = [
            _TrendCard(
              title: l10n.reportsCommissionTitle,
              series: report.commissionByDay,
              currency: report.commissionCurrency,
            ),
            _TrendCard(
              title: l10n.reportsSubscriptionTitle,
              series: report.subscriptionRevenueByDay,
              currency: report.subscriptionCurrency,
            ),
            _TrendCard(title: l10n.reportsBookingsTitle, series: report.bookingsCreated),
            _StatusCard(status: report.bookingsByStatus),
          ];
          return ContentFrame(
            maxWidth: 1200,
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(platformReportProvider(_days).future).then((_) {}),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const gap = SizedBox(height: FactorySpacing.space4);
                  if (constraints.maxWidth >= _wideBreakpoint) {
                    return Padding(
                      padding: const EdgeInsets.all(FactorySpacing.space4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 280, child: panel),
                          const SizedBox(width: FactorySpacing.space4),
                          Expanded(
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [for (final card in cards) ...[card, gap]],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(FactorySpacing.space4),
                    children: [panel, gap, for (final card in cards) ...[card, gap]],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A daily series as its total over the window plus a trend line. [currency]
/// null means a count (bookings); for money a null currency means nothing was
/// earned in the window, so there is nothing to draw.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.title, required this.series, this.currency});

  final String title;
  final List<DailyValue> series;
  final String? currency;

  bool get _isMoney => currency != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.factoryColors;
    final total = series.total;
    final empty = total == 0;
    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: FactorySpacing.space3),
          if (empty)
            Text(l10n.reportsNoData, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary))
          else ...[
            Text(
              _isMoney ? formatMoney(locale, total, currency) : formatCount(locale, total),
              style: FactoryTypography.mono(size: 22, weight: FontWeight.w600, color: colors.text),
            ),
            if (series.length >= 2) ...[
              const SizedBox(height: FactorySpacing.space3),
              FactorySparkline(values: series.values, height: 80, semanticLabel: title),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final BookingsByStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.factoryColors;
    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.reportsStatusTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: FactorySpacing.space3),
          if (status.total == 0)
            Text(l10n.reportsNoData, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                FactoryChartSegment segment(String label, int count, Color color) => FactoryChartSegment(
                  label: label,
                  value: count.toDouble(),
                  valueLabel: formatCount(locale, count),
                  color: color,
                );
                return FactoryDonutChart(
                  stacked: constraints.maxWidth < 420,
                  centerLabel: formatCount(locale, status.total),
                  centerCaption: l10n.reportsBookingsTitle,
                  semanticLabel: l10n.reportsStatusTitle,
                  segments: [
                    segment(l10n.reportsStatusCompleted, status.completed, colors.success),
                    segment(l10n.reportsStatusConfirmed, status.confirmed, colors.info),
                    segment(l10n.reportsStatusPending, status.pending, colors.warning),
                    segment(l10n.reportsStatusCancelled, status.cancelled, colors.error),
                    segment(l10n.reportsStatusNoShow, status.noShow, colors.lavender),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
