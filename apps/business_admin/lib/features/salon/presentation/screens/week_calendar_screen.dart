import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/schedule_entry.dart';
import '../providers/salon_providers.dart';
import '../widgets/agenda_row.dart';

/// Below this width the week is a day strip plus the chosen day's list;
/// from it up, seven day columns side by side.
const double _weekColumnsMinWidth = 720;

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday of the week containing [d], as a local midnight.
DateTime weekStartOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// The owner's bookings for one week across all their businesses. Read-only:
/// it shows what is coming (time, service, status), and the week can be
/// stepped back and forth.
class WeekCalendarScreen extends ConsumerStatefulWidget {
  const WeekCalendarScreen({super.key, required this.ownerUserId, this.today});

  final String ownerUserId;

  /// Overrides "today" in tests.
  final DateTime? today;

  @override
  ConsumerState<WeekCalendarScreen> createState() => _WeekCalendarScreenState();
}

class _WeekCalendarScreenState extends ConsumerState<WeekCalendarScreen> {
  late final DateTime _today = _dayOnly(widget.today ?? DateTime.now());
  late DateTime _weekStart = weekStartOf(_today);
  late int _selectedDay = _today.difference(_weekStart).inDays;

  void _shift(int weeks) => setState(() {
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7 * weeks);
    // Keep the same weekday selected; on the current week prefer today.
    if (_weekStart == weekStartOf(_today)) _selectedDay = _today.difference(_weekStart).inDays;
  });

  void _goToThisWeek() => setState(() {
    _weekStart = weekStartOf(_today);
    _selectedDay = _today.difference(_weekStart).inDays;
  });

  DateTime _day(int index) => DateTime(_weekStart.year, _weekStart.month, _weekStart.day + index);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final agendaAsync = ref.watch(ownerWeekAgendaProvider((widget.ownerUserId, _weekStart)));
    final isThisWeek = _weekStart == weekStartOf(_today);

    final rangeLabel = '${DateFormat.MMMd(locale).format(_day(0))} – ${DateFormat.MMMd(locale).format(_day(6))}';

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.calendarTitle),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(FactorySpacing.space2, FactorySpacing.space2, FactorySpacing.space2, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.calendarPrevWeek,
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _shift(-1),
                  ),
                  Expanded(
                    child: Text(rangeLabel, textAlign: TextAlign.center, style: textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: l10n.calendarNextWeek,
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => _shift(1),
                  ),
                  if (!isThisWeek) TextButton(onPressed: _goToThisWeek, child: Text(l10n.calendarThisWeek)),
                ],
              ),
            ),
            Expanded(
              child: agendaAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(FactorySpacing.space4),
                    child: FactoryErrorState(
                      message: l10n.calendarLoadFailed,
                      onRetry: () => ref.invalidate(ownerWeekAgendaProvider((widget.ownerUserId, _weekStart))),
                    ),
                  ),
                ),
                data: (items) {
                  final byDay = List.generate(7, (i) {
                    final day = _day(i);
                    return items.where((it) => _dayOnly(it.entry.startsAt.toLocal()) == day).toList();
                  });
                  final multiple = items.map((a) => a.providerName).toSet().length > 1;
                  return LayoutBuilder(
                    builder: (context, constraints) => constraints.maxWidth >= _weekColumnsMinWidth
                        ? _WeekColumns(days: [for (var i = 0; i < 7; i++) _day(i)], byDay: byDay, today: _today, multiple: multiple)
                        : _DayStripAndList(
                            days: [for (var i = 0; i < 7; i++) _day(i)],
                            byDay: byDay,
                            today: _today,
                            selected: _selectedDay,
                            multiple: multiple,
                            onSelect: (i) => setState(() => _selectedDay = i),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayStripAndList extends StatelessWidget {
  const _DayStripAndList({
    required this.days,
    required this.byDay,
    required this.today,
    required this.selected,
    required this.multiple,
    required this.onSelect,
  });

  final List<DateTime> days;
  final List<List<AgendaItem>> byDay;
  final DateTime today;
  final int selected;
  final bool multiple;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final items = byDay[selected];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(FactorySpacing.space3),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    child: InkWell(
                      borderRadius: FactoryRadius.mdRadius,
                      onTap: () => onSelect(i),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 64),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i == selected ? colors.primary : colors.surface,
                          borderRadius: FactoryRadius.mdRadius,
                          border: Border.all(
                            color: i == selected
                                ? colors.primary
                                : (days[i] == today ? colors.primary.withValues(alpha: 0.6) : colors.border),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat.E(locale).format(days[i]),
                              style: textTheme.labelSmall?.copyWith(
                                color: i == selected ? colors.onPrimary : colors.textSecondary,
                              ),
                            ),
                            Text(
                              '${days[i].day}',
                              style: FactoryTypography.mono(size: 16, color: i == selected ? colors.onPrimary : colors.text),
                            ),
                            Text(
                              byDay[i].isEmpty ? '' : '${byDay[i].length}',
                              style: FactoryTypography.mono(
                                size: 11,
                                weight: FontWeight.w500,
                                color: i == selected ? colors.onPrimary : colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(l10n.calendarDayEmpty, style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(FactorySpacing.space4),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Divider(height: FactorySpacing.space4, color: colors.border),
                  itemBuilder: (context, i) => AgendaRow(item: items[i], showProvider: multiple),
                ),
        ),
      ],
    );
  }
}

class _WeekColumns extends StatelessWidget {
  const _WeekColumns({required this.days, required this.byDay, required this.today, required this.multiple});

  final List<DateTime> days;
  final List<List<AgendaItem>> byDay;
  final DateTime today;
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(FactorySpacing.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.all(FactorySpacing.space2),
                constraints: const BoxConstraints(minHeight: 240),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: context.factoryProfileOrNull?.cardBorderRadius ?? FactoryRadius.lgRadius,
                  border: Border.all(color: days[i] == today ? colors.primary : colors.border, width: days[i] == today ? 1.5 : 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat.E(locale).format(days[i]), style: textTheme.labelSmall?.copyWith(color: colors.textSecondary)),
                    Text('${days[i].day}', style: FactoryTypography.mono(size: 18, color: colors.text)),
                    const SizedBox(height: FactorySpacing.space2),
                    if (byDay[i].isEmpty)
                      Text(l10n.calendarDayEmpty, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary))
                    else
                      for (final item in byDay[i])
                        Padding(
                          padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                          child: AgendaRow(item: item, showProvider: multiple, compact: true),
                        ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
