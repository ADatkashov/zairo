import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';

/// Weekday keys, Monday first — the same ones the backend stores.
const workingHoursDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// What a day switches to when the owner turns it on.
const defaultWorkingRange = '09:00-20:00';

/// True when every range is `HH:mm-HH:mm` with the end after the start.
bool workingHoursValid(Map<String, String> hours) =>
    hours.values.every((range) {
      final m = RegExp(r'^(\d\d:\d\d)-(\d\d:\d\d)$').firstMatch(range);
      return m != null && m.group(1)!.compareTo(m.group(2)!) < 0;
    });

/// Seven rows: a switch (open / day off) and, for an open day, the opening and closing times. One tap copies
/// Monday to every day, because most businesses keep the same hours all week.
class WorkingHoursEditor extends StatelessWidget {
  const WorkingHoursEditor({
    super.key,
    required this.hours,
    required this.onChanged,
    this.enabled = true,
  });

  final Map<String, String> hours;
  final ValueChanged<Map<String, String>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.workingHoursLabel, style: textTheme.labelMedium),
        for (final day in workingHoursDays)
          Row(
            children: [
              Switch(
                value: hours.containsKey(day),
                onChanged: enabled ? (on) => _toggle(day, on) : null,
              ),
              SizedBox(
                width: 36,
                // 2024-01-01 is a Monday.
                child: Text(
                  DateFormat.E(locale).format(
                    DateTime(2024, 1, 1 + workingHoursDays.indexOf(day)),
                  ),
                ),
              ),
              const SizedBox(width: FactorySpacing.space2),
              if (hours.containsKey(day)) ...[
                _TimeButton(
                  key: ValueKey('open-$day'),
                  time: hours[day]!.substring(0, 5),
                  onTap: enabled
                      ? () => _pick(context, day, start: true)
                      : null,
                ),
                const Text('–'),
                _TimeButton(
                  key: ValueKey('close-$day'),
                  time: hours[day]!.substring(6),
                  onTap: enabled
                      ? () => _pick(context, day, start: false)
                      : null,
                ),
              ] else
                Text(l10n.workingHoursDayOff, style: textTheme.bodyMedium),
            ],
          ),
        if (hours.containsKey('mon'))
          TextButton(
            onPressed: enabled
                ? () => onChanged({
                    for (final d in workingHoursDays) d: hours['mon']!,
                  })
                : null,
            child: Text(l10n.workingHoursApplyToAll),
          ),
      ],
    );
  }

  void _toggle(String day, bool on) {
    final next = Map<String, String>.of(hours);
    if (on) {
      next[day] = defaultWorkingRange;
    } else {
      next.remove(day);
    }
    onChanged(next);
  }

  Future<void> _pick(
    BuildContext context,
    String day, {
    required bool start,
  }) async {
    final range = hours[day]!;
    final current = start ? range.substring(0, 5) : range.substring(6);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(current.substring(0, 2)),
        minute: int.parse(current.substring(3)),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    String two(int n) => n.toString().padLeft(2, '0');
    final value = '${two(picked.hour)}:${two(picked.minute)}';
    final next = Map<String, String>.of(hours);
    next[day] = start
        ? '$value-${range.substring(6)}'
        : '${range.substring(0, 5)}-$value';
    onChanged(next);
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({super.key, required this.time, required this.onTap});

  final String time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: onTap, child: Text(time));
}
