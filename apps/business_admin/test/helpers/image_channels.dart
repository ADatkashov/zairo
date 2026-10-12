import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A valid 1x1 PNG, small enough to embed.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Stands in for the camera/gallery picker and the cropper, which are native
/// plugins: the picker "returns" a file called [pickedName] and the cropper
/// "returns" [tinyPng]. Pass [cropCancelled] to simulate backing out of the
/// cropper, or [pickerFails] to make the picker itself throw.
///
/// Must be called inside a test; it restores the real channels afterwards.
Future<void> mockImagePickAndCrop(
  WidgetTester tester, {
  String pickedName = 'photo.png',
  bool cropCancelled = false,
  bool pickerFails = false,
}) async {
  final dir = await tester.runAsync(() => Directory.systemTemp.createTemp('image_mock'));
  final pickedPath = '${dir!.path}/$pickedName';
  final croppedPath = '${dir.path}/cropped.png';
  await tester.runAsync(() async {
    await File(pickedPath).writeAsBytes(tinyPng);
    await File(croppedPath).writeAsBytes(tinyPng);
  });

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
  const cropperChannel = MethodChannel('plugins.hunghd.vn/image_cropper');
  messenger.setMockMethodCallHandler(pickerChannel, (call) async {
    if (pickerFails) throw PlatformException(code: 'denied');
    return call.method == 'pickImage' ? pickedPath : null;
  });
  messenger.setMockMethodCallHandler(cropperChannel, (call) async {
    return call.method == 'cropImage' && !cropCancelled ? croppedPath : null;
  });
  addTearDown(() async {
    messenger.setMockMethodCallHandler(pickerChannel, null);
    messenger.setMockMethodCallHandler(cropperChannel, null);
    await dir.delete(recursive: true).catchError((_) => dir);
  });
}

/// Lets the file reads inside the picker/cropper finish. `testWidgets` runs on
/// fake time, but `File` I/O completes on the real event loop, and the picking
/// code touches files twice in a row (exists, then read), so each step needs a
/// short real wait followed by a pump to run the continuation.
Future<void> settleRealIo(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
