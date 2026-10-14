import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/admin_provider.dart';
import '../providers/salon_providers.dart';
import '../widgets/analytics_period.dart';

/// Reports: the same Business Intelligence numbers, drawn as charts — revenue
/// over time, revenue by service as a donut, bookings by status as bars — with
/// the period filter in a panel beside them (stacked on top on a phone).
/// Everything is read from the providers behind [BusinessAnalyticsScreen], so
/// the two screens always agree for the same period.
class BusinessReportsScreen extends ConsumerStatefulWidget {
  final AdminProvider provider;

  const BusinessReportsScreen({super.key, required this.provider});

  @override
  ConsumerState<BusinessReportsScreen> createState() => _BusinessReportsScreenState();
}

class _BusinessReportsScreenState extends ConsumerState<BusinessReportsScreen> {
  static const _defaultPeriod = AnalyticsPeriod.thisMonth;
  static const _wideBreakpoint = 840.0;

  AnalyticsPeriod _period = _defaultPeriod;
  DateTimeRange? _customRange;

  Future<void> _pickCustomRange() async {
    final picked = await pickAnalyticsRange(context, _customRange);
    if (picked != null && mounted) {
      setState(() {
        _period = AnalyticsPeriod.custom;
        _customRange = picked;
      });
    }
  }

  void _reset() => setState(() {
    _period = _defaultPeriod;
    _customRange = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final providerId = widget.provider.id;
    final range = analyticsRangeFor(_period, _customRange);

    final panel = FactoryFilterPanel(
      title: l10n.reportsFiltersTitle,
      resetLabel: l10n.reportsFiltersReset,
      onReset: _period == _defaultPeriod ? null : _reset,
      children: [
        FactoryFilterField(
          label: l10n.reportsPeriodLabel,
          child: AnalyticsPeriodChips(
            period: _period,
            customRange: _customRange,
            onSelect: (p) => setState(() => _period = p),
            onCustom: _pickCustomRange,
          ),
        ),
      ],
    );
    final cards = [
      _RevenueTrendCard(providerId: providerId, range: range),
      _RevenueByServiceCard(providerId: providerId, range: range),
      _BookingsByStatusCard(providerId: providerId, range: range),
    ];

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.businessReportsTitle),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(businessAnalyticsRevenueProvider);
          ref.invalidate(businessAnalyticsBookingsProvider);
        },
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
  }
}

/// A titled card whose body follows an async value: spinner, retryable error,
/// or whatever [data] draws.
class _ReportCard<T> extends StatelessWidget {
  final String title;
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) data;

  const _ReportCard({required this.title, required this.value, required this.onRetry, required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: FactorySpacing.space3),
          value.when(
            data: data,
            loading: () => const FactoryLoadingState(),
            error: (error, _) => FactoryErrorState(message: l10n.errorAnalyticsLoadFailed, onRetry: onRetry),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;

  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.factoryColors.textTertiary),
  );
}

class _RevenueTrendCard extends ConsumerWidget {
  final String providerId;
  final AnalyticsRange range;

  const _RevenueTrendCard({required this.providerId, required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final key = (providerId, range);
    return _ReportCard<BusinessAnalyticsRevenue>(
      title: l10n.analyticsRevenueByDayTitle,
      value: ref.watch(businessAnalyticsRevenueProvider(key)),
      onRetry: () => ref.invalidate(businessAnalyticsRevenueProvider(key)),
      data: (revenue) {
        if (revenue.revenueByDay.isEmpty) return _Empty(l10n.analyticsNoRevenueYet);
        final days = [...revenue.revenueByDay]..sort((a, b) => a.date.compareTo(b.date));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatFactoryMoney(revenue.totalRevenue, revenue.currency),
              style: FactoryTypography.mono(size: 22, weight: FontWeight.w600, color: context.factoryColors.accentInk),
            ),
            if (days.length >= 2) ...[
              const SizedBox(height: FactorySpacing.space3),
              FactorySparkline(
                values: [for (final d in days) d.amount.toDouble()],
                height: 96,
                semanticLabel: l10n.analyticsRevenueByDayTitle,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RevenueByServiceCard extends ConsumerWidget {
  static const _shown = 5;

  final String providerId;
  final AnalyticsRange range;

  const _RevenueByServiceCard({required this.providerId, required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final key = (providerId, range);
    return _ReportCard<BusinessAnalyticsRevenue>(
      title: l10n.analyticsRevenueByServiceTitle,
      value: ref.watch(businessAnalyticsRevenueProvider(key)),
      onRetry: () => ref.invalidate(businessAnalyticsRevenueProvider(key)),
      data: (revenue) {
        final services = [...revenue.revenueByService]..sort((a, b) => b.amount.compareTo(a.amount));
        if (services.isEmpty) return _Empty(l10n.analyticsNoRevenueYet);
        final top = services.take(_shown).toList();
        final restTotal = services.skip(_shown).fold<double>(0, (sum, s) => sum + s.amount);
        String money(double amount) => formatFactoryMoney(amount, revenue.currency);
        return LayoutBuilder(
          builder: (context, constraints) => FactoryDonutChart(
            stacked: constraints.maxWidth < 420,
            centerLabel: money(revenue.totalRevenue),
            centerCaption: l10n.analyticsKpiRevenue,
            semanticLabel: l10n.analyticsRevenueByServiceTitle,
            segments: [
              for (final s in top) FactoryChartSegment(label: s.title ?? '—', value: s.amount, valueLabel: money(s.amount)),
              if (restTotal > 0)
                FactoryChartSegment(label: l10n.reportsOtherServices, value: restTotal, valueLabel: money(restTotal)),
            ],
          ),
        );
      },
    );
  }
}

class _BookingsByStatusCard extends ConsumerWidget {
  final String providerId;
  final AnalyticsRange range;

  const _BookingsByStatusCard({required this.providerId, required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final key = (providerId, range);
    return _ReportCard<BusinessAnalyticsBookings>(
      title: l10n.reportsBookingsByStatusTitle,
      value: ref.watch(businessAnalyticsBookingsProvider(key)),
      onRetry: () => ref.invalidate(businessAnalyticsBookingsProvider(key)),
      data: (bookings) {
        if (bookings.totalBookings == 0) return _Empty(l10n.analyticsNoBookingsYet);
        final rows = [
          (l10n.analyticsCompletedBookingsLabel, bookings.completedBookings, colors.success),
          (l10n.analyticsUpcomingBookingsLabel, bookings.upcomingBookings, colors.info),
          (l10n.analyticsCancelledBookingsLabel, bookings.cancelledBookings, colors.error),
          (l10n.analyticsNoShowLabel, bookings.noShowBookings, colors.warning),
        ];
        return Column(
          children: [
            for (final (label, count, color) in rows)
              _StatusBar(label: label, count: count, fraction: count / bookings.totalBookings, color: color),
          ],
        );
      },
    );
  }
}

class _StatusBar extends StatelessWidget {
  final String label;
  final int count;
  final double fraction;
  final Color color;

  const _StatusBar({required this.label, required this.count, required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: textTheme.bodySmall)),
              Text('$count', style: FactoryTypography.mono(size: 13, weight: FontWeight.w600, color: colors.text)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: colors.surfaceAlt,
            ),
          ),
        ],
      ),
    );
  }
}
