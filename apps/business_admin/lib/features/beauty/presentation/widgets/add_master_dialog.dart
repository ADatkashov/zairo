import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../billing/data/billing_exception.dart';
import '../providers/beauty_admin_providers.dart';

/// Returns true via Navigator.pop when a master was created.
class AddMasterDialog extends ConsumerStatefulWidget {
  final String providerId;

  const AddMasterDialog({super.key, required this.providerId});

  @override
  ConsumerState<AddMasterDialog> createState() => _AddMasterDialogState();
}

class _AddMasterDialogState extends ConsumerState<AddMasterDialog> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.addMasterDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            enabled: !_isSubmitting,
            decoration: InputDecoration(labelText: l10n.masterNameLabel),
          ),
          TextField(
            controller: _bioController,
            enabled: !_isSubmitting,
            decoration: InputDecoration(labelText: l10n.bioOptionalLabel),
            maxLines: 2,
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

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.validationMasterNameRequired);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final bio = _bioController.text.trim();
      await ref.read(beautyAdminApiProvider).createMaster(
            providerId: widget.providerId,
            displayName: name,
            bio: bio.isEmpty ? null : bio,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is BillingException ? e.localizedMessage(l10n) : l10n.errorAddMasterFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }
}
