import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';

/// Month calendar for planning ahead: days with free times are tappable, the rest are muted (and read aloud as
/// "no free times"). Pops with the tapped day (local midnight), or null when dismissed. [availableDays] are local
/// midnights, as `groupByLocalDay` produces them.
Future<DateTime?> showDayCalendarSheet(
  BuildContext context, {
  required Set<DateTime> availableDays,
  required DateTime selectedDay,
}) {
  return showFactoryBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DayCalendar(availableDays: availableDays, selectedDay: selectedDay),
  );
}

class DayCalendar extends StatefulWidget {
  const DayCalendar({super.key, required this.availableDays, required this.selectedDay, this.today});

  final Set<DateTime> availableDays;
  final DateTime selectedDay;

  /// For tests; defaults to now.
  final DateTime? today;

  @override
  State<DayCalendar> createState() => _DayCalendarState();
}

class _DayCalendarState extends State<DayCalendar> {
  late DateTime _month = DateTime(widget.selectedDay.year, widget.selectedDay.month);

  DateTime get _firstMonth {
    final first = widget.availableDays.reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime(first.year, first.month);
  }

  DateTime get _lastMonth {
    final last = widget.availableDays.reduce((a, b) => a.isAfter(b) ? a : b);
    return DateTime(last.year, last.month);
  }

  void _go(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final now = widget.today ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final leading = DateTime(_month.year, _month.month).weekday - 1; // Monday first
    final canGoBack = _month.isAfter(_firstMonth);
    final canGoForward = _month.isBefore(_lastMonth);
    // A real Monday to label the weekday header with the app's own short names.
    final monday = DateTime(2024, 1, 1);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(FactorySpacing.space4, FactorySpacing.space2, FactorySpacing.space4,
            FactorySpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.bookingCalendarTitle, style: textTheme.titleMedium),
            const SizedBox(height: FactorySpacing.space3),
            Row(
              children: [
                IconButton(
                  tooltip: l10n.bookingCalendarPrevMonth,
                  onPressed: canGoBack ? () => _go(-1) : null,
                  icon: const Icon(Symbols.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '${formatMonthShort(l10n, _month)} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: l10n.bookingCalendarNextMonth,
                  onPressed: canGoForward ? () => _go(1) : null,
                  icon: const Icon(Symbols.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: FactorySpacing.space2),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        formatWeekdayShort(l10n, monday.add(Duration(days: i))),
                        style: textTheme.labelSmall?.copyWith(color: colors.textTertiary),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: FactorySpacing.space1),
            for (var week = 0; week < ((leading + daysInMonth) / 7).ceil(); week++)
              Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: _cell(context, l10n, colors, textTheme, today, week * 7 + col - leading + 1,
                          daysInMonth),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, AppLocalizations l10n, FactoryColors colors, TextTheme textTheme,
      DateTime today, int dayNumber, int daysInMonth) {
    if (dayNumber < 1 || dayNumber > daysInMonth) return const SizedBox(height: 48);
    final day = DateTime(_month.year, _month.month, dayNumber);
    final free = widget.availableDays.contains(day);
    final selected = day == widget.selectedDay;
    final label = formatWeekdayMonthDay(l10n, day);
    final fg = selected ? colors.onPrimary : (free ? colors.text : colors.textTertiary);

    return Semantics(
      button: true,
      enabled: free,
      selected: selected,
      label: free ? l10n.bookingCalendarDayFree(label) : l10n.bookingCalendarDayBusy(label),
      excludeSemantics: true,
      child: InkWell(
        onTap: free ? () => Navigator.of(context).pop(day) : null,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? colors.primary : (free ? colors.primary.withValues(alpha: 0.10) : null),
                // Today is ringed, never colour alone: it also reads as "today" to a screen reader via the label order.
                border: day == today && !selected ? Border.all(color: colors.primary, width: 1.5) : null,
              ),
              child: Text(
                '$dayNumber',
                style: textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: free ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
