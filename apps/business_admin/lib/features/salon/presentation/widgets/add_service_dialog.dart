import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/admin_service.dart';
import '../providers/salon_providers.dart';

/// Add-or-edit: pass [existing] to edit that service in place instead of
/// creating a new one. Returns true via Navigator.pop on success — the
/// caller invalidates providerServicesProvider in response, same pattern
/// as apps/user_app's _LeaveReviewDialog.
class AddServiceDialog extends ConsumerStatefulWidget {
  final String providerId;
  final AdminService? existing;

  const AddServiceDialog({super.key, required this.providerId, this.existing});

  @override
  ConsumerState<AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends ConsumerState<AddServiceDialog> {
  late final _titleController = TextEditingController(text: widget.existing?.title ?? '');
  late final _durationController =
      TextEditingController(text: (widget.existing?.durationMinutes ?? 30).toString());
  late final _priceController = TextEditingController(text: widget.existing?.price.toString() ?? '');
  bool _isSubmitting = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(_isEditing ? l10n.editServiceDialogTitle : l10n.addServiceDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            enabled: !_isSubmitting,
            decoration: InputDecoration(labelText: l10n.titleLabel),
          ),
          TextField(
            controller: _durationController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.durationMinutesLabel),
          ),
          TextField(
            controller: _priceController,
            enabled: !_isSubmitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.priceUsdLabel),
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
              : Text(_isEditing ? l10n.saveButton : l10n.addButton),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    final duration = int.tryParse(_durationController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    if (title.isEmpty || duration == null || duration <= 0 || price == null || price < 0) {
      setState(() => _error = l10n.validationServiceFields);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final api = ref.read(salonAdminApiProvider);
      if (_isEditing) {
        await api.updateService(
          serviceId: widget.existing!.id,
          title: title,
          durationMinutes: duration,
          price: price,
          currency: widget.existing!.currency,
        );
      } else {
        await api.createService(
          providerId: widget.providerId,
          title: title,
          durationMinutes: duration,
          price: price,
          currency: 'USD',
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = _isEditing ? l10n.errorServiceSaveFailed(e.toString()) : l10n.errorServiceAddFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }
}
