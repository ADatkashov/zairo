import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/salon_providers.dart';

/// The reporting windows an owner can pick on the analytics and reports screens.
enum AnalyticsPeriod { today, thisWeek, thisMonth, custom }

/// The `[from, to)` window for [period] (the API's `to` is exclusive).
/// [custom] is the picked day range, whose end day is inclusive; before one is
/// picked, "custom" means the month so far. [now] is injectable for tests.
AnalyticsRange analyticsRangeFor(AnalyticsPeriod period, DateTimeRange? custom, {DateTime? now}) {
  final at = now ?? DateTime.now();
  switch (period) {
    case AnalyticsPeriod.today:
      final start = DateTime(at.year, at.month, at.day);
      return (start, start.add(const Duration(days: 1)));
    case AnalyticsPeriod.thisWeek:
      final todayStart = DateTime(at.year, at.month, at.day);
      final weekStart = todayStart.subtract(Duration(days: at.weekday - 1));
      return (weekStart, weekStart.add(const Duration(days: 7)));
    case AnalyticsPeriod.thisMonth:
      final monthStart = DateTime(at.year, at.month, 1);
      final nextMonth = at.month == 12 ? DateTime(at.year + 1, 1, 1) : DateTime(at.year, at.month + 1, 1);
      return (monthStart, nextMonth);
    case AnalyticsPeriod.custom:
      if (custom == null) {
        return (DateTime(at.year, at.month, 1), at);
      }
      // showDateRangePicker's end is inclusive of that whole day; the API's [from, to) is exclusive.
      return (custom.start, custom.end.add(const Duration(days: 1)));
  }
}

/// Opens the date-range picker (up to three years back, never into the future).
Future<DateTimeRange?> pickAnalyticsRange(BuildContext context, DateTimeRange? current) {
  final now = DateTime.now();
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(now.year - 3),
    lastDate: now,
    initialDateRange: current ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
  );
}

/// Today / This week / This month / custom range, as one row of chips.
class AnalyticsPeriodChips extends StatelessWidget {
  final AnalyticsPeriod period;
  final DateTimeRange? customRange;
  final ValueChanged<AnalyticsPeriod> onSelect;
  final VoidCallback onCustom;

  const AnalyticsPeriodChips({
    super.key,
    required this.period,
    required this.customRange,
    required this.onSelect,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final customLabel = period == AnalyticsPeriod.custom && customRange != null
        ? '${DateFormat.yMMMd(locale).format(customRange!.start)} – ${DateFormat.yMMMd(locale).format(customRange!.end)}'
        : l10n.analyticsPeriodCustom;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FactoryChip(
          label: l10n.analyticsPeriodToday,
          selected: period == AnalyticsPeriod.today,
          onTap: () => onSelect(AnalyticsPeriod.today),
        ),
        FactoryChip(
          label: l10n.analyticsPeriodThisWeek,
          selected: period == AnalyticsPeriod.thisWeek,
          onTap: () => onSelect(AnalyticsPeriod.thisWeek),
        ),
        FactoryChip(
          label: l10n.analyticsPeriodThisMonth,
          selected: period == AnalyticsPeriod.thisMonth,
          onTap: () => onSelect(AnalyticsPeriod.thisMonth),
        ),
        FactoryChip(
          label: customLabel,
          selected: period == AnalyticsPeriod.custom,
          icon: Icons.calendar_month_outlined,
          onTap: onCustom,
        ),
      ],
    );
  }
}
