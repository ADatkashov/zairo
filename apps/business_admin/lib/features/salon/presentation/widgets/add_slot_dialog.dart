import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/salon_providers.dart';

/// Returns true via Navigator.pop when a slot was created.
class AddSlotDialog extends ConsumerStatefulWidget {
  final String providerId;

  const AddSlotDialog({super.key, required this.providerId});

  @override
  ConsumerState<AddSlotDialog> createState() => _AddSlotDialogState();
}

class _AddSlotDialogState extends ConsumerState<AddSlotDialog> {
  final _durationController = TextEditingController(text: '30');
  DateTime? _date;
  TimeOfDay? _time;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.addSlotDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_date == null ? l10n.pickDateLabel : '${_date!.year}-${_date!.month}-${_date!.day}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _isSubmitting ? null : _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_time == null ? l10n.pickTimeLabel : _time!.format(context)),
            trailing: const Icon(Icons.access_time),
            onTap: _isSubmitting ? null : _pickTime,
          ),
          TextField(
            controller: _durationController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.durationMinutesLabel),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: FactorySpacing.space2),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final duration = int.tryParse(_durationController.text.trim());
    if (_date == null || _time == null || duration == null || duration <= 0) {
      setState(() => _error = l10n.validationSlotFields);
      return;
    }
    final startsAt = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    final endsAt = startsAt.add(Duration(minutes: duration));

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(salonAdminApiProvider).createSlot(
            providerId: widget.providerId,
            startsAt: startsAt,
            endsAt: endsAt,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = l10n.errorAddSlotFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }
}
