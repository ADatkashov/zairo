import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// A chosen picture, read into memory.
typedef PickedImage = ({Uint8List bytes, String name});

/// Asks the person for a picture from their device; null when they back out.
/// A provider so widget tests can answer without the platform's picker.
final pickImageProvider = Provider<Future<PickedImage?> Function()>((ref) {
  return () async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
    if (picked == null) return null;
    return (bytes: await picked.readAsBytes(), name: picked.name);
  };
});
