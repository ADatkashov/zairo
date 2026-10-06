import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/worker_schedule.dart';
import '../providers/staff_owner_providers.dart';

/// One person's weekly hours (set once; their bookable times are generated automatically) and their days off.
/// Only the owner can change these — the person themselves can only close their own availability.
class WorkerScheduleScreen extends ConsumerStatefulWidget {
  const WorkerScheduleScreen({super.key, required this.providerId, required this.worker});

  final String providerId;
  final WorkerSummary worker;

  @override
  ConsumerState<WorkerScheduleScreen> createState() => _WorkerScheduleScreenState();
}

typedef _Interval = ({TimeOfDay start, TimeOfDay end});

class _WorkerScheduleScreenState extends ConsumerState<WorkerScheduleScreen> {
  static const _slotOptions = [15, 20, 30, 45, 60, 90, 120];
  static const _breakOptions = [0, 5, 10, 15, 30];

  /// 1 = Monday .. 7 = Sunday.
  final Map<int, List<_Interval>> _days = {for (var d = 1; d <= 7; d++) d: <_Interval>[]};
  int _slotMinutes = 60;
  int _breakMinutes = 0;
  bool _loaded = false;
  bool _saving = false;

  void _load(WorkerScheduleData data) {
    if (_loaded) return;
    _loaded = true;
    if (data.configured) {
      _slotMinutes = _slotOptions.contains(data.slotMinutes) ? data.slotMinutes : 60;
      _breakMinutes = _breakOptions.contains(data.breakMinutes) ? data.breakMinutes : 0;
      for (final h in data.hours) {
        _days[h.dayOfWeek]!.add((start: h.start, end: h.end));
      }
    } else {
      // A new schedule starts from the most common week so the owner only has to adjust, not build from nothing.
      for (var d = 1; d <= 5; d++) {
        _days[d]!.add((start: const TimeOfDay(hour: 9, minute: 0), end: const TimeOfDay(hour: 18, minute: 0)));
      }
    }
  }

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _editInterval(int day, int? index) async {
    final existing = index == null ? null : _days[day]![index];
    final start = await showTimePicker(
      context: context,
      initialTime: existing?.start ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: existing?.end ?? TimeOfDay(hour: (start.hour + 4).clamp(0, 23), minute: start.minute),
    );
    if (end == null || !mounted) return;
    if (_minutes(end) <= _minutes(start)) return; // an empty or backwards interval is ignored, not saved
    setState(() {
      final list = _days[day]!;
      if (index == null) {
        list.add((start: start, end: end));
      } else {
        list[index] = (start: start, end: end);
      }
      list.sort((a, b) => _minutes(a.start).compareTo(_minutes(b.start)));
    });
  }

  void _copyToWeekdays(int fromDay) {
    setState(() {
      for (var d = 1; d <= 5; d++) {
        if (d != fromDay) _days[d] = List<_Interval>.of(_days[fromDay]!);
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final hours = <HoursInterval>[
      for (final entry in _days.entries)
        for (final i in entry.value) HoursInterval(dayOfWeek: entry.key, start: i.start, end: i.end),
    ];
    if (hours.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.workerScheduleNeedsHours)));
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ref.read(staffOwnerApiProvider).saveSchedule(
            widget.providerId,
            widget.worker.id,
            slotMinutes: _slotMinutes,
            breakMinutes: _breakMinutes,
            hours: hours,
          );
      ref.invalidate(workersProvider(widget.providerId));
      ref.invalidate(workerScheduleProvider((widget.providerId, widget.worker.id)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.workerScheduleSaved(result.slotsCreated, result.slotsRemoved))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.teamScheduleSaveFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeSchedule() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showFactoryDialog<bool>(
      context: context,
      title: l10n.workerScheduleRemoveTitle,
      message: l10n.workerScheduleRemoveMessage,
      actions: [
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.workerScheduleKeep,
            variant: FactoryButtonVariant.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.workerScheduleRemove,
            variant: FactoryButtonVariant.danger,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(staffOwnerApiProvider).deleteSchedule(widget.providerId, widget.worker.id);
      ref.invalidate(workersProvider(widget.providerId));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.teamScheduleSaveFailed)));
      }
    }
  }

  Future<void> _recordTimeOff(DateTime from, DateTime to) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final created = await ref.read(staffOwnerApiProvider).createTimeOff(
            widget.providerId,
            widget.worker.id,
            startsAt: from,
            endsAt: to,
          );
      ref.invalidate(workersProvider(widget.providerId));
      ref.invalidate(workerTimeOffProvider((widget.providerId, widget.worker.id)));
      // Appointments inside the period are not cancelled: tell the owner there are decisions to make.
      ref.invalidate(needsAttentionProvider(widget.providerId));
      if (mounted) {
        final affected = created.affectedAppointments;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(affected > 0 ? l10n.timeOffRecordedAffected(affected) : l10n.timeOffRecorded),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.timeOffFailed)));
      }
    }
  }

  Future<void> _notInToday() {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return _recordTimeOff(now, endOfToday);
  }

  Future<void> _addDaysOff() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    // The picker's end is the last whole day, inclusive.
    final from = picked.start.isBefore(now) ? now : picked.start;
    final to = DateTime(picked.end.year, picked.end.month, picked.end.day).add(const Duration(days: 1));
    await _recordTimeOff(from, to);
  }

  String _dayLabel(AppLocalizations l10n, int day) => switch (day) {
        1 => l10n.weekdayMon,
        2 => l10n.weekdayTue,
        3 => l10n.weekdayWed,
        4 => l10n.weekdayThu,
        5 => l10n.weekdayFri,
        6 => l10n.weekdaySat,
        _ => l10n.weekdaySun,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final key = (widget.providerId, widget.worker.id);
    final schedule = ref.watch(workerScheduleProvider(key));
    final timeOff = ref.watch(workerTimeOffProvider(key));
    schedule.whenData(_load);

    return Scaffold(
      appBar: FactoryAppBar(title: widget.worker.displayName),
      body: schedule.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FactoryErrorState(
            message: l10n.teamScheduleSaveFailed,
            onRetry: () => ref.invalidate(workerScheduleProvider(key)),
          ),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            FactorySectionHeader(title: l10n.workerScheduleTitle),
            const SizedBox(height: FactorySpacing.space2),
            Text(l10n.workerScheduleHint, style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
            const SizedBox(height: FactorySpacing.space3),
            for (var day = 1; day <= 7; day++) _dayRow(l10n, colors, textTheme, day),
            const SizedBox(height: FactorySpacing.space3),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _slotMinutes,
                    decoration: InputDecoration(labelText: l10n.workerScheduleSlotLength),
                    items: [
                      for (final m in _slotOptions)
                        DropdownMenuItem(value: m, child: Text(l10n.workerScheduleMinutes(m))),
                    ],
                    onChanged: (v) => setState(() => _slotMinutes = v ?? _slotMinutes),
                  ),
                ),
                const SizedBox(width: FactorySpacing.space3),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _breakMinutes,
                    decoration: InputDecoration(labelText: l10n.workerScheduleBreak),
                    items: [
                      for (final m in _breakOptions)
                        DropdownMenuItem(value: m, child: Text(l10n.workerScheduleMinutes(m))),
                    ],
                    onChanged: (v) => setState(() => _breakMinutes = v ?? _breakMinutes),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FactorySpacing.space4),
            FactoryButton(
              label: l10n.workerScheduleSave,
              expand: true,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
            if (data.configured)
              Align(
                alignment: Alignment.centerLeft,
                child: FactoryButton(
                  label: l10n.workerScheduleRemove,
                  variant: FactoryButtonVariant.textDanger,
                  onPressed: _removeSchedule,
                ),
              ),
            const SizedBox(height: FactorySpacing.space6),
            FactorySectionHeader(title: l10n.timeOffTitle),
            const SizedBox(height: FactorySpacing.space2),
            Wrap(
              spacing: FactorySpacing.space2,
              children: [
                FactoryButton(
                  label: l10n.timeOffToday,
                  variant: FactoryButtonVariant.secondary,
                  dense: true,
                  onPressed: _notInToday,
                ),
                FactoryButton(
                  label: l10n.timeOffAdd,
                  variant: FactoryButtonVariant.text,
                  dense: true,
                  onPressed: _addDaysOff,
                ),
              ],
            ),
            const SizedBox(height: FactorySpacing.space2),
            timeOff.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: FactorySpacing.space2),
                child: LinearProgressIndicator(),
              ),
              error: (error, stackTrace) => const SizedBox.shrink(),
              data: (items) {
                if (items.isEmpty) {
                  return Text(l10n.timeOffEmpty, style: textTheme.bodyMedium?.copyWith(color: colors.textTertiary));
                }
                return Column(
                  children: [
                    for (final item in items)
                      _TimeOffRow(
                        item: item,
                        onReopen: () async {
                          await ref.read(staffOwnerApiProvider).deleteTimeOff(widget.providerId, item.id);
                          ref.invalidate(workerTimeOffProvider(key));
                          ref.invalidate(workersProvider(widget.providerId));
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayRow(AppLocalizations l10n, FactoryColors colors, TextTheme textTheme, int day) {
    final intervals = _days[day]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 44, child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_dayLabel(l10n, day), style: textTheme.titleSmall),
          )),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (intervals.isEmpty)
                  Text(l10n.workerScheduleDayOff, style: textTheme.bodyMedium?.copyWith(color: colors.textTertiary)),
                for (var i = 0; i < intervals.length; i++)
                  InputChip(
                    key: ValueKey('interval-$day-$i'),
                    label: Text('${_fmt(intervals[i].start)}–${_fmt(intervals[i].end)}'),
                    onPressed: () => _editInterval(day, i),
                    onDeleted: () => setState(() => intervals.removeAt(i)),
                  ),
                IconButton(
                  key: ValueKey('add-$day'),
                  tooltip: l10n.workerScheduleAddInterval,
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _editInterval(day, null),
                ),
                if (intervals.isNotEmpty && day <= 5)
                  TextButton(
                    key: ValueKey('copy-$day'),
                    onPressed: () => _copyToWeekdays(day),
                    child: Text(l10n.workerScheduleCopyWeekdays),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _TimeOffRow extends StatelessWidget {
  const _TimeOffRow({required this.item, required this.onReopen});

  final TimeOffItem item;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space2),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatMonthDayTime(l10n, item.startsAt.toLocal())} – ${formatMonthDayTime(l10n, item.endsAt.toLocal())}',
                  style: textTheme.bodyMedium,
                ),
                if (item.reason != null && item.reason!.isNotEmpty)
                  Text(item.reason!, style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
                if (item.byWorker)
                  Text(l10n.timeOffByWorker, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
              ],
            ),
          ),
          FactoryButton(label: l10n.timeOffReopen, variant: FactoryButtonVariant.text, dense: true, onPressed: onReopen),
        ],
      ),
    );
  }
}
