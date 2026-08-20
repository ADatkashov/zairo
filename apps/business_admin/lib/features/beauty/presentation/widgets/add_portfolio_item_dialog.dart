import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../storage/presentation/providers/storage_providers.dart';
import '../providers/beauty_admin_providers.dart';

/// Returns true via Navigator.pop when a portfolio photo was added. Picks a
/// local image file and uploads it through backend's storage module
/// (backend/storage) rather than asking for a hosted URL — MinIO from
/// infrastructure/docker-compose.yml is wired in end to end now.
class AddPortfolioItemDialog extends ConsumerStatefulWidget {
  final String masterId;

  const AddPortfolioItemDialog({super.key, required this.masterId});

  @override
  ConsumerState<AddPortfolioItemDialog> createState() => _AddPortfolioItemDialogState();
}

class _AddPortfolioItemDialogState extends ConsumerState<AddPortfolioItemDialog> {
  final _captionController = TextEditingController();
  Uint8List? _pickedBytes;
  String? _pickedName;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a portfolio photo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.image_outlined),
            label: Text(_pickedName ?? 'Choose photo'),
            onPressed: _isSubmitting ? null : _pickFile,
          ),
          const SizedBox(height: 8),
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

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
      final file = result?.files.singleOrNull;
      if (file?.bytes == null) return;
      setState(() {
        _pickedBytes = file!.bytes;
        _pickedName = file.name;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Failed to read file: $e');
    }
  }

  Future<void> _submit() async {
    final bytes = _pickedBytes;
    final name = _pickedName;
    if (bytes == null || name == null) {
      setState(() => _error = 'Choose a photo first');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final uploaded = await ref.read(storageApiProvider).uploadBytes(bytes, name);
      final caption = _captionController.text.trim();
      await ref.read(beautyAdminApiProvider).addPortfolioItem(
            masterId: widget.masterId,
            imageUrl: uploaded.url,
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
