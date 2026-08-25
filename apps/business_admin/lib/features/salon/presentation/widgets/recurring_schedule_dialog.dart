import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../billing/data/billing_exception.dart';
import '../providers/salon_providers.dart';

/// Returns true via Navigator.pop when a schedule was generated (even if
/// every candidate slot was skipped as a conflict — the caller still
/// refreshes the slot list either way).
class RecurringScheduleDialog extends ConsumerStatefulWidget {
  final String providerId;

  const RecurringScheduleDialog({super.key, required this.providerId});

  @override
  ConsumerState<RecurringScheduleDialog> createState() => _RecurringScheduleDialogState();
}

class _RecurringScheduleDialogState extends ConsumerState<RecurringScheduleDialog> {
  final Set<int> _selectedDays = {};
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _durationController = TextEditingController(text: '30');
  final _breakController = TextEditingController(text: '10');
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  final List<DateTime> _holidays = [];
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _durationController.dispose();
    _breakController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weekdayLabels = [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];

    return AlertDialog(
      title: Text(l10n.recurringScheduleDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.recurringScheduleDaysLabel, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: FactorySpacing.space2),
            Wrap(
              spacing: FactorySpacing.space2,
              runSpacing: FactorySpacing.space2,
              children: List.generate(7, (i) {
                final weekday = i + 1;
                return FactoryChip(
                  label: weekdayLabels[i],
                  selected: _selectedDays.contains(weekday),
                  onTap: _isSubmitting
                      ? null
                      : () => setState(() {
                          if (!_selectedDays.remove(weekday)) _selectedDays.add(weekday);
                        }),
                );
              }),
            ),
            const SizedBox(height: FactorySpacing.space4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_startTime == null
                  ? l10n.recurringScheduleStartTimeLabel
                  : '${l10n.recurringScheduleStartTimeLabel}: ${_startTime!.format(context)}'),
              trailing: const Icon(Icons.access_time),
              onTap: _isSubmitting ? null : () => _pickTime(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_endTime == null
                  ? l10n.recurringScheduleEndTimeLabel
                  : '${l10n.recurringScheduleEndTimeLabel}: ${_endTime!.format(context)}'),
              trailing: const Icon(Icons.access_time),
              onTap: _isSubmitting ? null : () => _pickTime(isStart: false),
            ),
            TextField(
              controller: _durationController,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.durationMinutesLabel),
            ),
            const SizedBox(height: FactorySpacing.space2),
            TextField(
              controller: _breakController,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.recurringScheduleBreakMinutesLabel),
            ),
            const SizedBox(height: FactorySpacing.space2),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_rangeStart == null
                  ? l10n.recurringScheduleRangeStartLabel
                  : '${l10n.recurringScheduleRangeStartLabel}: ${_formatDate(_rangeStart!)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _isSubmitting ? null : () => _pickRangeDate(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_rangeEnd == null
                  ? l10n.recurringScheduleRangeEndLabel
                  : '${l10n.recurringScheduleRangeEndLabel}: ${_formatDate(_rangeEnd!)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _isSubmitting ? null : () => _pickRangeDate(isStart: false),
            ),
            const SizedBox(height: FactorySpacing.space2),
            Text(l10n.recurringScheduleHolidaysLabel, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: FactorySpacing.space2),
            Wrap(
              spacing: FactorySpacing.space2,
              runSpacing: FactorySpacing.space2,
              children: [
                for (final holiday in _holidays)
                  InputChip(
                    label: Text(_formatDate(holiday)),
                    onDeleted: _isSubmitting ? null : () => setState(() => _holidays.remove(holiday)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(l10n.recurringScheduleAddHolidayButton),
                  onPressed: _isSubmitting ? null : _pickHoliday,
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: FactorySpacing.space2),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.addButton),
        ),
      ],
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _pickRangeDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _rangeStart : _rangeEnd) ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _rangeStart = picked;
      } else {
        _rangeEnd = picked;
      }
    });
  }

  Future<void> _pickHoliday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _rangeStart ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && !_holidays.any((d) => _isSameDate(d, picked))) {
      setState(() => _holidays.add(picked));
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final duration = int.tryParse(_durationController.text.trim());
    final breakMinutes = int.tryParse(_breakController.text.trim());
    if (_selectedDays.isEmpty ||
        _startTime == null ||
        _endTime == null ||
        _rangeStart == null ||
        _rangeEnd == null ||
        duration == null ||
        duration <= 0 ||
        breakMinutes == null ||
        breakMinutes < 0 ||
        _rangeEnd!.isBefore(_rangeStart!)) {
      setState(() => _error = l10n.recurringScheduleValidationError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(salonAdminApiProvider).createRecurringSchedule(
            providerId: widget.providerId,
            daysOfWeek: _selectedDays.toList(),
            startHour: _startTime!.hour,
            startMinute: _startTime!.minute,
            endHour: _endTime!.hour,
            endMinute: _endTime!.minute,
            slotDurationMinutes: duration,
            breakMinutes: breakMinutes,
            rangeStart: _rangeStart!,
            rangeEnd: _rangeEnd!,
            holidays: _holidays,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.recurringScheduleSuccessMessage(result.createdCount, result.skippedConflictCount)),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e is BillingException ? e.localizedMessage(l10n) : l10n.errorRecurringScheduleFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
