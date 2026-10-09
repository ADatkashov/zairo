import 'dart:typed_data';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/image/pick_and_crop_image.dart';
import '../../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: l10n.addPortfolioDialogTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pickedBytes != null) ...[
            ClipRRect(
              borderRadius: FactoryRadius.mdRadius,
              child: Image.memory(_pickedBytes!, height: 160, fit: BoxFit.cover),
            ),
            const SizedBox(height: FactorySpacing.space3),
          ],
          FactoryButton(
            icon: Icons.image_outlined,
            label: _pickedName ?? l10n.choosePhotoLabel,
            variant: FactoryButtonVariant.secondary,
            onPressed: _isSubmitting ? null : _pickFile,
          ),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(
            controller: _captionController,
            enabled: !_isSubmitting,
            label: l10n.captionOptionalLabel,
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

  Future<void> _pickFile() async {
    try {
      // Freeform (null aspectRatio) — a before/after or work-sample shot
      // isn't always square like an avatar, so don't force one.
      final picked = await pickAndCropImage(
        context,
        cropTitle: AppLocalizations.of(context)!.addPortfolioDialogTitle,
        aspectRatio: null,
      );
      if (picked == null) return;
      setState(() {
        _pickedBytes = picked.bytes;
        _pickedName = picked.name;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context)!.errorReadFileFailed);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final bytes = _pickedBytes;
    final name = _pickedName;
    if (bytes == null || name == null) {
      setState(() => _error = l10n.validationChoosePhoto);
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
        _error = l10n.errorAddPhotoFailed;
        _isSubmitting = false;
      });
    }
  }
}
