import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/availability_slot.dart';
import 'day_calendar_sheet.dart';

/// "Pick a day, then a time", shortest path first:
///  * **Soonest** — the next few free times as one-tap chips (most people just want the next free time);
///  * a strip of the days that have free times, plus a **calendar** button for planning further ahead;
///  * the chosen day's times, grouped into morning / afternoon / evening once there are enough to need it.
///
/// Only free times are shown; a busy slot would just be noise.
class DaySlotPicker extends StatefulWidget {
  /// Open slots only.
  final List<AvailabilitySlot> slots;
  final String? selectedSlotId;
  final ValueChanged<String> onSelected;

  /// How many of the earliest times are offered as "Soonest".
  static const int soonestCount = 3;

  /// A day with more times than this gets morning / afternoon / evening headings.
  static const int groupingThreshold = 6;

  const DaySlotPicker({
    super.key,
    required this.slots,
    required this.selectedSlotId,
    required this.onSelected,
  });

  @override
  State<DaySlotPicker> createState() => _DaySlotPickerState();
}

class _DaySlotPickerState extends State<DaySlotPicker> {
  DateTime? _pickedDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final byDay = groupByLocalDay<AvailabilitySlot>(widget.slots, (s) => s.startsAt);
    if (byDay.isEmpty) return const SizedBox.shrink();

    final days = byDay.keys.toList();
    final activeDay = _resolveDay(byDay, days);
    final textTheme = Theme.of(context).textTheme;
    final colors = context.factoryColors;
    final soonest = [for (final day in days) ...byDay[day]!].take(DaySlotPicker.soonestCount).toList();
    // One day with a handful of times is already "soonest"; repeating it would only add noise.
    final showSoonest = days.length > 1 || widget.slots.length > DaySlotPicker.groupingThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSoonest) ...[
          Text(l10n.bookingSoonest, style: textTheme.labelLarge?.copyWith(color: colors.textSecondary)),
          const SizedBox(height: FactorySpacing.space2),
          Wrap(
            key: const Key('bookingSoonest'),
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final slot in soonest)
                FactoryTimeSlot(
                  label: _soonestLabel(l10n, slot.startsAt.toLocal()),
                  state: widget.selectedSlotId == slot.id
                      ? FactoryTimeSlotState.selected
                      : FactoryTimeSlotState.available,
                  onTap: () => widget.onSelected(slot.id),
                ),
            ],
          ),
          const SizedBox(height: FactorySpacing.space4),
        ],
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 76 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: days.length,
                  separatorBuilder: (_, _) => const SizedBox(width: FactorySpacing.space2),
                  itemBuilder: (context, i) => _DayChip(
                    day: days[i],
                    selected: days[i] == activeDay,
                    onTap: () => setState(() => _pickedDay = days[i]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: FactorySpacing.space2),
            _CalendarButton(onTap: () => _openCalendar(days.toSet(), activeDay)),
          ],
        ),
        const SizedBox(height: FactorySpacing.space3),
        Text(formatWeekdayMonthDay(l10n, activeDay), style: textTheme.titleSmall),
        const SizedBox(height: FactorySpacing.space2),
        ..._timesOfDay(l10n, byDay[activeDay]!),
      ],
    );
  }

  Future<void> _openCalendar(Set<DateTime> days, DateTime activeDay) async {
    final picked = await showDayCalendarSheet(context, availableDays: days, selectedDay: activeDay);
    if (picked != null && mounted) setState(() => _pickedDay = picked);
  }

  /// "Today 16:00", "Tomorrow 10:00", else "Mon, Oct 5 · 10:00".
  String _soonestLabel(AppLocalizations l10n, DateTime start) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(start.year, start.month, start.day);
    final time = formatHourMinute(start);
    if (day == today) return '${l10n.waitlistToday} $time';
    if (day == DateTime(today.year, today.month, today.day + 1)) {
      return '${l10n.waitlistTomorrow} $time';
    }
    return '${formatWeekdayMonthDay(l10n, day)} · $time';
  }

  List<Widget> _timesOfDay(AppLocalizations l10n, List<AvailabilitySlot> slots) {
    Widget wrap(List<AvailabilitySlot> list) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slot in list)
              FactoryTimeSlot(
                label: formatHourMinute(slot.startsAt.toLocal()),
                state: widget.selectedSlotId == slot.id
                    ? FactoryTimeSlotState.selected
                    : FactoryTimeSlotState.available,
                onTap: () => widget.onSelected(slot.id),
              ),
          ],
        );

    if (slots.length <= DaySlotPicker.groupingThreshold) return [wrap(slots)];

    final textTheme = Theme.of(context).textTheme;
    final colors = context.factoryColors;
    final groups = <(String, List<AvailabilitySlot>)>[
      (l10n.bookingPartMorning, [for (final s in slots) if (s.startsAt.toLocal().hour < 12) s]),
      (l10n.bookingPartAfternoon, [
        for (final s in slots) if (s.startsAt.toLocal().hour >= 12 && s.startsAt.toLocal().hour < 17) s
      ]),
      (l10n.bookingPartEvening, [for (final s in slots) if (s.startsAt.toLocal().hour >= 17) s]),
    ];
    return [
      for (final (title, list) in groups)
        if (list.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: FactorySpacing.space2, bottom: FactorySpacing.space2),
            child: Text(title, style: textTheme.labelLarge?.copyWith(color: colors.textSecondary)),
          ),
          wrap(list),
        ],
    ];
  }

  /// The day the person tapped, else the day of the slot already selected,
  /// else the earliest day with an open slot.
  DateTime _resolveDay(Map<DateTime, List<AvailabilitySlot>> byDay, List<DateTime> days) {
    if (_pickedDay != null && byDay.containsKey(_pickedDay)) return _pickedDay!;
    final selectedId = widget.selectedSlotId;
    if (selectedId != null) {
      for (final entry in byDay.entries) {
        if (entry.value.any((s) => s.id == selectedId)) return entry.key;
      }
    }
    return days.first;
  }
}

/// A 44px calendar button next to the day strip.
class _CalendarButton extends StatelessWidget {
  const _CalendarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    return Semantics(
      button: true,
      label: l10n.bookingCalendarButton,
      excludeSemantics: true,
      child: InkWell(
        key: const Key('bookingCalendarButton'),
        onTap: onTap,
        borderRadius: FactoryRadius.smRadius,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: FactoryRadius.smRadius,
            border: Border.all(color: colors.border, width: 1.5),
          ),
          child: Icon(Symbols.calendar_month_rounded, color: colors.primary),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({required this.day, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final fg = selected ? colors.onPrimary : colors.text;
    final muted = selected ? colors.onPrimary : colors.textTertiary;

    return Semantics(
      button: true,
      selected: selected,
      label: formatWeekdayMonthDay(l10n, day),
      child: InkWell(
        onTap: onTap,
        borderRadius: FactoryRadius.smRadius,
        child: Container(
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surface,
            borderRadius: FactoryRadius.smRadius,
            border: Border.all(color: selected ? colors.primary : colors.border, width: 1.5),
          ),
          // The chip keeps its size; a very large system font shrinks the three lines to fit rather than overflow.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatWeekdayShort(l10n, day), style: textTheme.labelSmall?.copyWith(color: muted)),
                Text(
                  '${day.day}',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: fg),
                ),
                Text(formatMonthShort(l10n, day), style: textTheme.labelSmall?.copyWith(color: muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
