import 'dart:typed_data';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';

class PickedCroppedImage {
  final Uint8List bytes;
  final String name;

  const PickedCroppedImage({required this.bytes, required this.name});
}

/// Camera-or-gallery bottom sheet, then the native crop screen (drag/zoom/
/// rotate, locked to a square) — the standard pattern most apps use for a
/// profile photo. Returns null if the user backs out at any step.
Future<PickedCroppedImage?> pickAndCropImage(BuildContext context, {required String cropTitle}) async {
  final source = await _chooseImageSource(context);
  if (source == null) return null;

  final XFile? picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
  if (picked == null) return null;
  if (!context.mounted) return null;

  final CroppedFile? cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    uiSettings: [
      AndroidUiSettings(toolbarTitle: cropTitle, lockAspectRatio: true),
      IOSUiSettings(title: cropTitle, aspectRatioLockEnabled: true),
      WebUiSettings(context: context),
    ],
  );
  if (cropped == null) return null;

  return PickedCroppedImage(bytes: await cropped.readAsBytes(), name: picked.name);
}

Future<ImageSource?> _chooseImageSource(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.imagePickerCameraLabel),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.imagePickerGalleryLabel),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
          const SizedBox(height: FactorySpacing.space2),
        ],
      ),
    ),
  );
}
