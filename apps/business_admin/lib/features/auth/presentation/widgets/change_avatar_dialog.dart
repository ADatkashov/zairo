import 'dart:typed_data';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/image/pick_and_crop_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../storage/presentation/providers/storage_providers.dart';
import '../providers/auth_providers.dart';

/// Picks a photo (camera or gallery), lets the user crop/zoom/rotate it,
/// uploads it through backend's storage module, then PATCHes it onto the
/// current owner's account. Callers just watch authControllerProvider,
/// which this already updates.
Future<void> showChangeAvatarDialog(BuildContext context, {required bool hasCurrentAvatar}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ChangeAvatarDialog(hasCurrentAvatar: hasCurrentAvatar),
  );
}

class _ChangeAvatarDialog extends ConsumerStatefulWidget {
  const _ChangeAvatarDialog({required this.hasCurrentAvatar});

  final bool hasCurrentAvatar;

  @override
  ConsumerState<_ChangeAvatarDialog> createState() => _ChangeAvatarDialogState();
}

class _ChangeAvatarDialogState extends ConsumerState<_ChangeAvatarDialog> {
  Uint8List? _pickedBytes;
  String? _pickedName;
  bool _isSubmitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pickedBytes = _pickedBytes;
    return FactoryDialog(
      title: l10n.changeAvatarDialogTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (pickedBytes != null) ...[
            CircleAvatar(radius: 48, backgroundImage: MemoryImage(pickedBytes)),
            const SizedBox(height: FactorySpacing.space3),
          ],
          FactoryButton(
            icon: Icons.image_outlined,
            label: l10n.choosePhotoLabel,
            variant: FactoryButtonVariant.secondary,
            onPressed: _isSubmitting ? null : _pickPhoto,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: FactorySpacing.space2),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        if (widget.hasCurrentAvatar)
          FactoryButton(
            label: l10n.changeAvatarRemoveButton,
            variant: FactoryButtonVariant.text,
            onPressed: _isSubmitting ? null : _removePhoto,
          ),
        FactoryButton(
          label: l10n.cancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        FactoryButton(
          label: l10n.saveButton,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting || _pickedBytes == null ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await pickAndCropImage(context, cropTitle: AppLocalizations.of(context)!.changeAvatarDialogTitle);
      if (picked == null) return;
      setState(() {
        _pickedBytes = picked.bytes;
        _pickedName = picked.name;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context)!.errorReadFileFailed(e.toString()));
    }
  }

  Future<void> _removePhoto() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).updateAvatar(null);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.errorAvatarUpdateFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }

  Future<void> _submit() async {
    final bytes = _pickedBytes;
    final name = _pickedName;
    if (bytes == null || name == null) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final uploaded = await ref.read(storageApiProvider).uploadBytes(bytes, name);
      await ref.read(authControllerProvider.notifier).updateAvatar(uploaded.url);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.errorAvatarUpdateFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }
}
