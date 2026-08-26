import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../billing/data/billing_exception.dart';
import '../providers/auto_admin_providers.dart';

/// Returns true via Navigator.pop when a mechanic was created.
class AddMechanicDialog extends ConsumerStatefulWidget {
  final String providerId;

  const AddMechanicDialog({super.key, required this.providerId});

  @override
  ConsumerState<AddMechanicDialog> createState() => _AddMechanicDialogState();
}

class _AddMechanicDialogState extends ConsumerState<AddMechanicDialog> {
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
    return FactoryDialog(
      title: l10n.addMechanicDialogTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FactoryTextField(
            controller: _nameController,
            enabled: !_isSubmitting,
            label: l10n.mechanicNameLabel,
          ),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(
            controller: _bioController,
            enabled: !_isSubmitting,
            label: l10n.bioOptionalLabel,
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
        FactoryButton(
          label: l10n.cancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
        ),
        FactoryButton(
          label: l10n.addButton,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.validationMechanicNameRequired);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final bio = _bioController.text.trim();
      await ref.read(autoAdminApiProvider).createMechanic(
            providerId: widget.providerId,
            displayName: name,
            bio: bio.isEmpty ? null : bio,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is BillingException ? e.localizedMessage(l10n) : l10n.errorAddMechanicFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }
}
