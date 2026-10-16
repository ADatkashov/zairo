import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/availability_slot.dart';

/// "Pick a day, then a time": a horizontal strip of days that have open
/// slots, and only the chosen day's times underneath — instead of one long
/// wall of "Oct 5, 10:00" chips that grows with every recurring week.
class DaySlotPicker extends StatefulWidget {
  /// Open slots only.
  final List<AvailabilitySlot> slots;
  final String? selectedSlotId;
  final ValueChanged<String> onSelected;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
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
        const SizedBox(height: FactorySpacing.space3),
        Text(formatWeekdayMonthDay(l10n, activeDay), style: textTheme.titleSmall),
        const SizedBox(height: FactorySpacing.space2),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slot in byDay[activeDay]!)
              FactoryTimeSlot(
                label: formatHourMinute(slot.startsAt.toLocal()),
                state: widget.selectedSlotId == slot.id
                    ? FactoryTimeSlotState.selected
                    : FactoryTimeSlotState.available,
                onTap: () => widget.onSelected(slot.id),
              ),
          ],
        ),
      ],
    );
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
