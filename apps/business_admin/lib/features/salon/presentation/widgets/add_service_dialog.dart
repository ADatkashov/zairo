import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/salon_providers.dart';

/// Returns true via Navigator.pop when a service was created — the caller
/// invalidates providerServicesProvider in response, same pattern as
/// apps/user_app's _LeaveReviewDialog.
class AddServiceDialog extends ConsumerStatefulWidget {
  final String providerId;

  const AddServiceDialog({super.key, required this.providerId});

  @override
  ConsumerState<AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends ConsumerState<AddServiceDialog> {
  final _titleController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _priceController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a service'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            enabled: !_isSubmitting,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: _durationController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Duration (minutes)'),
          ),
          TextField(
            controller: _priceController,
            enabled: !_isSubmitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Price (USD)'),
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
    final title = _titleController.text.trim();
    final duration = int.tryParse(_durationController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    if (title.isEmpty || duration == null || duration <= 0 || price == null || price < 0) {
      setState(() => _error = 'Enter a title, a positive duration, and a valid price');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(salonAdminApiProvider).createService(
            providerId: widget.providerId,
            title: title,
            durationMinutes: duration,
            price: price,
            currency: 'USD',
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'Failed to add service: $e';
        _isSubmitting = false;
      });
    }
  }
}
