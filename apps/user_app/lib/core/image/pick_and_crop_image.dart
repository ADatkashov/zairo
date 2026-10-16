import 'dart:typed_data';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';

/// How a screen asks the person for a cropped photo. A provider so tests can answer without the camera/gallery and the
/// native crop screen, which only exist on a device.
typedef PickPhoto = Future<PickedCroppedImage?> Function(BuildContext context, {required String cropTitle});

final pickPhotoProvider = Provider<PickPhoto>(
  (ref) =>
      (context, {required cropTitle}) => pickAndCropImage(context, cropTitle: cropTitle),
);

class PickedCroppedImage {
  final Uint8List bytes;
  final String name;

  const PickedCroppedImage({required this.bytes, required this.name});
}

/// Camera-or-gallery bottom sheet, then the native crop screen (drag/zoom/
/// rotate). Defaults to a square lock — the standard pattern for a profile
/// photo — but a caller with a differently-shaped target (a wide cover
/// photo, a freeform portfolio shot) can pass its own [aspectRatio], or
/// null for an unlocked, freeform crop. Returns null if the user backs out
/// at any step. Mirrors apps/business_admin's identical helper.
///
/// [compressQuality] (0-100, re-encoded on crop) keeps output size bounded
/// regardless of source resolution — a raw phone-camera photo can exceed
/// the backend's 10MB upload limit (`spring.servlet.multipart.max-file-size`)
/// before cropping; this is what actually keeps a cropped upload under it.
Future<PickedCroppedImage?> pickAndCropImage(
  BuildContext context, {
  required String cropTitle,
  CropAspectRatio? aspectRatio = const CropAspectRatio(ratioX: 1, ratioY: 1),
  int compressQuality = 85,
}) async {
  final source = await _chooseImageSource(context);
  if (source == null) return null;

  final XFile? picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
  if (picked == null) return null;
  if (!context.mounted) return null;

  final CroppedFile? cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatio: aspectRatio,
    compressQuality: compressQuality,
    uiSettings: [
      AndroidUiSettings(toolbarTitle: cropTitle, lockAspectRatio: aspectRatio != null),
      IOSUiSettings(title: cropTitle, aspectRatioLockEnabled: aspectRatio != null),
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
