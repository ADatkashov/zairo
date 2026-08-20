import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/beauty_admin_providers.dart';

/// Returns true via Navigator.pop when a portfolio photo was added. Takes
/// an image URL rather than a file upload — there's no asset storage
/// (S3/MinIO) wired into any admin flow yet, same scope cut as the rest of
/// this MVP; owners paste a hosted image URL for now.
class AddPortfolioItemDialog extends ConsumerStatefulWidget {
  final String masterId;

  const AddPortfolioItemDialog({super.key, required this.masterId});

  @override
  ConsumerState<AddPortfolioItemDialog> createState() => _AddPortfolioItemDialogState();
}

class _AddPortfolioItemDialogState extends ConsumerState<AddPortfolioItemDialog> {
  final _urlController = TextEditingController();
  final _captionController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a portfolio photo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlController,
            enabled: !_isSubmitting,
            decoration: const InputDecoration(labelText: 'Image URL'),
          ),
          TextField(
            controller: _captionController,
            enabled: !_isSubmitting,
            decoration: const InputDecoration(labelText: 'Caption (optional)'),
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
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Enter an image URL');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final caption = _captionController.text.trim();
      await ref.read(beautyAdminApiProvider).addPortfolioItem(
            masterId: widget.masterId,
            imageUrl: url,
            caption: caption.isEmpty ? null : caption,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'Failed to add photo: $e';
        _isSubmitting = false;
      });
    }
  }
}
