import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return AlertDialog(
      title: const Text('Add a master'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            enabled: !_isSubmitting,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: _bioController,
            enabled: !_isSubmitting,
            decoration: const InputDecoration(labelText: 'Bio (optional)'),
            maxLines: 2,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
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
        _error = 'Failed to add master: $e';
        _isSubmitting = false;
      });
    }
  }
}
