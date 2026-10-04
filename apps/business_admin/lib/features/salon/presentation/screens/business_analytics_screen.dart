import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../campaigns/presentation/widgets/smart_action_center_section.dart';
import '../../data/models/admin_provider.dart';
import '../../data/models/business_analytics.dart';
import '../providers/salon_providers.dart';
import 'customer_list_screen.dart';
import 'smart_fill_campaigns_screen.dart';

enum _Period { today, thisWeek, thisMonth, custom }

/// The Revenue Intelligence Dashboard: what this business earned, what
/// ZAIRO recovered, what's at risk, and what deserves attention next — all
/// composed from real Booking/Payment/Smart Fill/Revenue Engine/Customer
/// Intelligence data for one owner-selected reporting period (see backend's
/// {@code BusinessAnalyticsService}). Every section shares the same
/// [AnalyticsRange] so the numbers on screen always agree with each other.
class BusinessAnalyticsScreen extends ConsumerStatefulWidget {
  final AdminProvider provider;

  const BusinessAnalyticsScreen({super.key, required this.provider});

  @override
  ConsumerState<BusinessAnalyticsScreen> createState() => _BusinessAnalyticsScreenState();
}

class _BusinessAnalyticsScreenState extends ConsumerState<BusinessAnalyticsScreen> {
  _Period _period = _Period.thisMonth;
  DateTimeRange? _customRange;

  AnalyticsRange get _range {
    final now = DateTime.now();
    switch (_period) {
      case _Period.today:
        final start = DateTime(now.year, now.month, now.day);
        return (start, start.add(const Duration(days: 1)));
      case _Period.thisWeek:
        final todayStart = DateTime(now.year, now.month, now.day);
        final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
        return (weekStart, weekStart.add(const Duration(days: 7)));
      case _Period.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        final nextMonth = now.month == 12 ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
        return (monthStart, nextMonth);
      case _Period.custom:
        final range = _customRange;
        if (range == null) {
          return (DateTime(now.year, now.month, 1), now);
        }
        // showDateRangePicker's end is inclusive of that whole day; the API's [from, to) is exclusive.
        return (range.start, range.end.add(const Duration(days: 1)));
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _customRange ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (picked != null && mounted) {
      setState(() {
        _period = _Period.custom;
        _customRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final providerId = widget.provider.id;
    final range = _range;

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.businessAnalyticsTitle),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(businessAnalyticsOverviewProvider);
          ref.invalidate(businessAnalyticsRevenueProvider);
          ref.invalidate(businessAnalyticsBookingsProvider);
          ref.invalidate(businessAnalyticsSmartFillProvider);
          ref.invalidate(businessAnalyticsCustomersProvider);
          ref.invalidate(businessAnalyticsActionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            _PeriodSelector(
              period: _period,
              customRange: _customRange,
              onSelect: (p) => setState(() => _period = p),
              onCustom: _pickCustomRange,
            ),
            const SizedBox(height: FactorySpacing.space6),
            _ActionCenterSection(providerId: providerId),
            const SizedBox(height: FactorySpacing.space6),
            SmartActionCenterSection(providerId: providerId),
            const SizedBox(height: FactorySpacing.space6),
            _OverviewSection(providerId: providerId, range: range),
            const SizedBox(height: FactorySpacing.space6),
            _RevenueSection(providerId: providerId, range: range),
            const SizedBox(height: FactorySpacing.space6),
            _BookingsSection(providerId: providerId, range: range),
            const SizedBox(height: FactorySpacing.space6),
            _SmartFillSection(providerId: providerId, range: range),
            const SizedBox(height: FactorySpacing.space6),
            _CustomersSection(providerId: providerId, range: range),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final _Period period;
  final DateTimeRange? customRange;
  final ValueChanged<_Period> onSelect;
  final VoidCallback onCustom;

  const _PeriodSelector({
    required this.period,
    required this.customRange,
    required this.onSelect,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final customLabel = period == _Period.custom && customRange != null
        ? '${DateFormat.yMMMd(locale).format(customRange!.start)} – ${DateFormat.yMMMd(locale).format(customRange!.end)}'
        : l10n.analyticsPeriodCustom;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FactoryChip(
          label: l10n.analyticsPeriodToday,
          selected: period == _Period.today,
          onTap: () => onSelect(_Period.today),
        ),
        FactoryChip(
          label: l10n.analyticsPeriodThisWeek,
          selected: period == _Period.thisWeek,
          onTap: () => onSelect(_Period.thisWeek),
        ),
        FactoryChip(
          label: l10n.analyticsPeriodThisMonth,
          selected: period == _Period.thisMonth,
          onTap: () => onSelect(_Period.thisMonth),
        ),
        FactoryChip(
          label: customLabel,
          selected: period == _Period.custom,
          icon: Icons.calendar_month_outlined,
          onTap: onCustom,
        ),
      ],
    );
  }
}

String _pct(double value) => '${(value * 100).round()}%';

class _ActionCenterSection extends ConsumerWidget {
  final String providerId;

  const _ActionCenterSection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final actionsAsync = ref.watch(businessAnalyticsActionsProvider(providerId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(title: l10n.actionCenterSectionTitle),
        actionsAsync.when(
          data: (data) {
            if (data.actions.isEmpty) {
              return Text(
                l10n.actionCenterEmpty,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              );
            }
            return Column(
              children: data.actions.map((action) => _ActionCard(providerId: providerId, action: action)).toList(),
            );
          },
          loading: () => const FactoryLoadingState(),
          error: (error, _) => FactoryErrorState(
            message: l10n.errorAnalyticsLoadFailed(error.toString()),
            onRetry: () => ref.invalidate(businessAnalyticsActionsProvider(providerId)),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String providerId;
  final ActionItem action;

  const _ActionCard({required this.providerId, required this.action});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final (icon, text) = switch (action.type) {
      ActionItemType.smartFillOpportunity => (Icons.bolt_outlined, l10n.actionSmartFillOpportunity(action.count)),
      ActionItemType.rebookOpportunity => (Icons.event_repeat_outlined, l10n.actionRebookOpportunity(action.count)),
      ActionItemType.retentionRisk => (Icons.warning_amber_outlined, l10n.actionRetentionRisk(action.count)),
      ActionItemType.lowUtilization => (Icons.calendar_month_outlined, l10n.actionLowUtilization(action.count)),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
      child: FactoryCard(
        onTap: () => _onTap(context, l10n),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(width: FactorySpacing.space3),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
            Icon(Icons.chevron_right, size: 20, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }

  /// Each type opens the real screen behind its count — the currently
  /// active Smart Fill campaigns, the actual overdue/at-risk customers, or
  /// (for a low-utilization day, which has no dedicated screen yet) back to
  /// this business's own schedule section on SalonDetailScreen.
  void _onTap(BuildContext context, AppLocalizations l10n) {
    switch (action.type) {
      case ActionItemType.smartFillOpportunity:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SmartFillCampaignsScreen(providerId: providerId)),
        );
      case ActionItemType.rebookOpportunity:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomerListScreen(
              providerId: providerId,
              retentionStatus: CustomerRetentionStatus.dueForRebooking,
              title: l10n.analyticsDueForRebookingLabel,
            ),
          ),
        );
      case ActionItemType.retentionRisk:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomerListScreen(
              providerId: providerId,
              retentionStatus: CustomerRetentionStatus.atRisk,
              title: l10n.analyticsAtRiskCustomersLabel,
            ),
          ),
        );
      case ActionItemType.lowUtilization:
        Navigator.of(context).pop();
    }
  }
}

class _OverviewSection extends ConsumerWidget {
  final String providerId;
  final AnalyticsRange range;

  const _OverviewSection({required this.providerId, required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final overviewAsync = ref.watch(businessAnalyticsOverviewProvider((providerId, range)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(title: l10n.analyticsOverviewSectionTitle),
        overviewAsync.when(
          data: (overview) => _OverviewContent(overview: overview),
          loading: () => const FactoryLoadingState(),
          error: (error, _) => FactoryErrorState(
            message: l10n.errorAnalyticsLoadFailed(error.toString()),
            onRetry: () => ref.invalidate(businessAnalyticsOverviewProvider((providerId, range))),
          ),
        ),
      ],
    );
  }
}

class _OverviewContent extends StatelessWidget {
  final BusinessAnalyticsOverview overview;

  const _OverviewContent({required this.overview});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final utilization = overview.utilization;

    return Wrap(
      spacing: FactorySpacing.space3,
      runSpacing: FactorySpacing.space3,
      children: [
        FactoryStatTile(
          label: l10n.analyticsKpiRevenue,
          value: formatFactoryMoney(overview.totalRevenue, overview.currency),
        ),
        FactoryStatTile(label: l10n.analyticsKpiBookings, value: '${overview.totalBookings}'),
        FactoryStatTile(
          label: l10n.analyticsKpiUtilization,
          value: utilization == null ? l10n.analyticsUtilizationUnavailable : _pct(utilization),
        ),
        FactoryStatTile(
          label: l10n.analyticsKpiRevenueRecovered,
          value: formatFactoryMoney(overview.revenueRecovered, overview.revenueRecoveredCurrency),
        ),
        FactoryStatTile(label: l10n.analyticsCompletedBookingsLabel, value: '${overview.completedBookings}'),
        FactoryStatTile(label: l10n.analyticsUpcomingBookingsLabel, value: '${overview.upcomingBookings}'),
        FactoryStatTile(label: l10n.analyticsCancelledBookingsLabel, value: '${overview.cancelledBookings}'),
        FactoryStatTile(label: l10n.analyticsNoShowLabel, value: '${overview.noShowBookings}'),
        FactoryStatTile(label: l10n.analyticsCancellationRateLabel, value: _pct(overview.cancellationRate)),
        FactoryStatTile(label: l10n.analyticsNoShowRateLabel, value: _pct(overview.noShowRate)),
        FactoryStatTile(
          label: l10n.analyticsReturningCustomerRateLabel,
          value: _pct(overview.returningCustomerRate),
        ),
        if (overview.averageBookingValue != null)
          FactoryStatTile(
            label: l10n.analyticsAverageBookingValueLabel,
            value: formatFactoryMoney(overview.averageBookingValue!, overview.currency),
          ),
      ],
    );
  }
}

class _RevenueSection extends ConsumerWidget {
  final String providerId;
  final AnalyticsRange range;

  const _RevenueSection({required this.providerId, required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final revenueAsync = ref.watch(businessAnalyticsRevenueProvider((providerId, range)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(title: l10n.analyticsRevenueSectionTitle),
        revenueAsync.when(
          data: (revenue) {
            if (revenue.revenueByDay.isEmpty) {
              return Text(
                l10n.analyticsNoRevenueYet,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              );
            }
            final maxDaily = revenue.revenueByDay.map((d) => d.amount).reduce((a, b) => a > b ? a : b);
            final locale = Localizations.localeOf(context).toString();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.analyticsRevenueByDayTitle, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: FactorySpacing.space2),
                ...revenue.revenueByDay.map(
                  (day) => _BarRow(
                    label: DateFormat.MMMd(locale).format(day.date),
                    value: day.amount,
                    maxValue: maxDaily,
                    trailing: formatFactoryMoney(day.amount, revenue.currency),
                  ),
                ),
                if (revenue.revenueByService.isNotEmpty) ...[
                  const SizedBox(height: FactorySpacing.space4),
                  Text(l10n.analyticsRevenueByServiceTitle, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: FactorySpacing.space2),
                  ...revenue.revenueByService.map(
                    (service) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(service.title ?? '—')),
                          Text('${service.bookingCount}', style: TextStyle(color: colors.textTertiary)),
                          const SizedBox(width: FactorySpacing.space3),
                          FactoryPriceText(amount: service.amount),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const FactoryLoadingState(),
          error: (error, _) => FactoryErrorState(
            message: l10n.errorAnalyticsLoadFailed(error.toString()),
            onRetry: () => ref.invalidate(businessAnalyticsRevenueProvider((providerId, range))),
          ),
        ),
      ],
    );
  }
}

class _BookingsSection extends ConsumerWidget {
  final String providerId;
  final AnalyticsRange range;

  const _BookingsSection({required this.providerId, required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final bookingsAsync = ref.watch(businessAnalyticsBookingsProvider((providerId, range)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(title: l10n.analyticsBookingsSectionTitle),
        bookingsAsync.when(
          data: (bookings) {
            if (bookings.totalBookings == 0) {
              return Text(
                l10n.analyticsNoBookingsYet,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              );
            }
            final locale = Localizations.localeOf(context).toString();
            final maxDaily = bookings.trend.isEmpty
                ? 0
                : bookings.trend.map((d) => d.total).reduce((a, b) => a > b ? a : b);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: FactorySpacing.space3,
                  runSpacing: FactorySpacing.space3,
                  children: [
                    FactoryStatTile(label: l10n.analyticsCompletedBookingsLabel, value: '${bookings.completedBookings}'),
                    FactoryStatTile(label: l10n.analyticsUpcomingBookingsLabel, value: '${bookings.upcomingBookings}'),
                    FactoryStatTile(label: l10n.analyticsCancelledBookingsLabel, value: '${bookings.cancelledBookings}'),
                    FactoryStatTile(label: l10n.analyticsNoShowLabel, value: '${bookings.noShowBookings}'),
                    FactoryStatTile(
                      label: l10n.analyticsRepeatBookingRateLabel,
                      value: _pct(bookings.repeatBookingRate),
                    ),
                  ],
                ),
                if (bookings.trend.isNotEmpty && maxDaily > 0) ...[
                  const SizedBox(height: FactorySpacing.space4),
                  Text(l10n.analyticsBookingTrendTitle, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: FactorySpacing.space2),
                  ...bookings.trend.map(
                    (day) => _BarRow(
                      label: DateFormat.MMMd(locale).format(day.date),
                      value: day.total.toDouble(),
                      maxValue: maxDaily.toDouble(),
                      trailing: '${day.total}',
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const FactoryLoadingState(),
          error: (error, _) => FactoryErrorState(
            message: l10n.errorAnalyticsLoadFailed(error.toString()),
            onRetry: () => ref.invalidate(businessAnalyticsBookingsProvider((providerId, range))),
          ),
        ),
      ],
    );
  }
}

class _SmartFillSection extends ConsumerWidget {
  final String providerId;
  final AnalyticsRange range;

  const _SmartFillSection({required this.providerId, required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final smartFillAsync = ref.watch(businessAnalyticsSmartFillProvider((providerId, range)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(title: l10n.analyticsSmartFillSectionTitle),
        smartFillAsync.when(
          data: (smartFill) {
            if (smartFill.campaignsCreated == 0) {
              return Text(
                l10n.analyticsSmartFillEmpty,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.analyticsSmartFillSummary(smartFill.slotsRecovered, smartFill.campaignsCreated),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: FactorySpacing.space3),
                Wrap(
                  spacing: FactorySpacing.space3,
                  runSpacing: FactorySpacing.space3,
                  children: [
                    FactoryStatTile(label: l10n.analyticsSlotsFreedLabel, value: '${smartFill.slotsFreed}'),
                    FactoryStatTile(label: l10n.analyticsCampaignsCreatedLabel, value: '${smartFill.campaignsCreated}'),
                    FactoryStatTile(label: l10n.analyticsSlotsRecoveredLabel, value: '${smartFill.slotsRecovered}'),
                    FactoryStatTile(label: l10n.analyticsRecoveryRateLabel, value: _pct(smartFill.recoveryRate)),
                    FactoryStatTile(
                      label: l10n.analyticsRecoveredRevenueLabel,
                      value: formatFactoryMoney(smartFill.recoveredRevenue, smartFill.currency),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const FactoryLoadingState(),
          error: (error, _) => FactoryErrorState(
            message: l10n.errorAnalyticsLoadFailed(error.toString()),
            onRetry: () => ref.invalidate(businessAnalyticsSmartFillProvider((providerId, range))),
          ),
        ),
      ],
    );
  }
}

class _CustomersSection extends ConsumerWidget {
  final String providerId;
  final AnalyticsRange range;

  const _CustomersSection({required this.providerId, required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final customersAsync = ref.watch(businessAnalyticsCustomersProvider((providerId, range)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(title: l10n.analyticsCustomersSectionTitle),
        customersAsync.when(
          data: (customers) {
            if (customers.totalCustomers == 0) {
              return Text(
                l10n.analyticsNoCustomersYet,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: FactorySpacing.space3,
                  runSpacing: FactorySpacing.space3,
                  children: [
                    FactoryStatTile(label: l10n.analyticsTotalCustomersLabel, value: '${customers.totalCustomers}'),
                    FactoryStatTile(label: l10n.analyticsActiveCustomersLabel, value: '${customers.activeCustomers}'),
                    FactoryStatTile(
                      label: l10n.analyticsReturningCustomersLabel,
                      value: '${customers.returningCustomers}',
                    ),
                    FactoryStatTile(label: l10n.analyticsNewCustomersLabel, value: '${customers.newCustomers}'),
                    FactoryStatTile(
                      label: l10n.analyticsDueForRebookingLabel,
                      value: '${customers.dueForRebooking}',
                    ),
                    FactoryStatTile(label: l10n.analyticsAtRiskCustomersLabel, value: '${customers.atRiskCustomers}'),
                    FactoryStatTile(
                      label: l10n.analyticsInactiveCustomersLabel,
                      value: '${customers.inactiveCustomers}',
                    ),
                    if (customers.averageVisitIntervalDays != null)
                      FactoryStatTile(
                        label: l10n.analyticsAverageVisitIntervalLabel,
                        value: l10n.analyticsAverageVisitIntervalValue(customers.averageVisitIntervalDays!.round()),
                      ),
                    if (customers.averageCustomerValue != null)
                      FactoryStatTile(
                        label: l10n.analyticsAverageCustomerValueLabel,
                        value: formatFactoryMoney(customers.averageCustomerValue!, customers.currency),
                      ),
                  ],
                ),
                if (customers.favouriteServices.isNotEmpty) ...[
                  const SizedBox(height: FactorySpacing.space4),
                  Text(l10n.analyticsFavouriteServicesTitle, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: FactorySpacing.space2),
                  ...customers.favouriteServices.map(
                    (service) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(service.title ?? '—')),
                          Text('${service.customerCount}', style: TextStyle(color: colors.textTertiary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const FactoryLoadingState(),
          error: (error, _) => FactoryErrorState(
            message: l10n.errorAnalyticsLoadFailed(error.toString()),
            onRetry: () => ref.invalidate(businessAnalyticsCustomersProvider((providerId, range))),
          ),
        ),
      ],
    );
  }
}

/// A single proportional bar row — day-by-day revenue/booking trend,
/// without pulling in a charting dependency for one bar per row.
class _BarRow extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final String trailing;

  const _BarRow({required this.label, required this.value, required this.maxValue, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final fraction = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(width: FactorySpacing.space2),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: colors.border,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(width: FactorySpacing.space3),
          SizedBox(
            width: 64,
            child: Text(trailing, textAlign: TextAlign.end, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
