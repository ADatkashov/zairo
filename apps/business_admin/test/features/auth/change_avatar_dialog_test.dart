import 'package:business_admin/features/auth/presentation/widgets/change_avatar_dialog.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/image_channels.dart';
import '../../helpers/pump_app.dart';

class _MemoryStorage extends SecureStorageService {
  _MemoryStorage() : super(const FlutterSecureStorage());
  final Map<String, String> _store = {};
  @override
  Future<void> write(String key, String value) async => _store[key] = value;
  @override
  Future<String?> read(String key) async => _store[key];
  @override
  Future<void> delete(String key) async => _store.remove(key);
  @override
  Future<void> deleteAll() async => _store.clear();
}

const _user = {'id': 'u1', 'email': 'owner@example.com', 'displayName': 'Aigerim', 'role': 'PROVIDER_OWNER'};

FakeHttp _backend() {
  final http = FakeHttp();
  http.reply('POST', '/uploads', {'key': 'avatars/1.png', 'url': 'https://cdn.example/avatars/1.png'});
  http.reply('PATCH', '/auth/me/avatar', {..._user, 'avatarUrl': 'https://cdn.example/avatars/1.png'});
  return http;
}

Future<void> _open(WidgetTester tester, FakeHttp http, {required bool hasAvatar}) async {
  useTallScreen(tester);
  await tester.pumpWidget(appOn(
    http,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showChangeAvatarDialog(context, hasCurrentAvatar: hasAvatar),
          child: const Text('open'),
        ),
      ),
    ),
    overrides: [secureStorageServiceProvider.overrideWithValue(_MemoryStorage())],
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder get _choose => find.widgetWithText(FactoryButton, en.choosePhotoLabel);
Finder get _save => find.widgetWithText(FactoryButton, en.saveButton);
Finder get _remove => find.widgetWithText(FactoryButton, en.changeAvatarRemoveButton);

Future<void> _pickFromGallery(WidgetTester tester) async {
  await tester.tap(_choose);
  await tester.pumpAndSettle();
  await tester.tap(find.text(en.imagePickerGalleryLabel));
  await settleRealIo(tester); // the cropper checks and then reads real files
}

void main() {
  testWidgets('starts with nothing chosen: saving is not possible yet', (tester) async {
    await _open(tester, _backend(), hasAvatar: false);

    expect(find.text(en.changeAvatarDialogTitle), findsOneWidget);
    expect(tester.widget<FactoryButton>(_save).onPressed, isNull);
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('the remove button exists only when there is an avatar to remove', (tester) async {
    await _open(tester, _backend(), hasAvatar: false);
    expect(_remove, findsNothing);
  });

  testWidgets('cancel closes the dialog without calling the backend', (tester) async {
    final http = _backend();
    await _open(tester, http, hasAvatar: true);

    await tester.tap(find.widgetWithText(FactoryButton, en.cancelButton));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(http.requests, isEmpty);
  });

  group('removing the current photo', () {
    testWidgets('clears the avatar and closes the dialog', (tester) async {
      final http = _backend();
      http.reply('PATCH', '/auth/me/avatar', {..._user, 'avatarUrl': null});
      await _open(tester, http, hasAvatar: true);

      await tester.tap(_remove);
      await tester.pumpAndSettle();

      expect(http.bodyOf('PATCH', '/auth/me/avatar'), {'avatarUrl': null});
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('a failure is reported and the dialog stays open and usable', (tester) async {
      final http = _backend();
      http.fail('PATCH', '/auth/me/avatar', 500);
      await _open(tester, http, hasAvatar: true);

      await tester.tap(_remove);
      await tester.pumpAndSettle();

      expect(find.text(en.errorAvatarUpdateFailed), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.widget<FactoryButton>(_remove).onPressed, isNotNull);
    });
  });

  group('choosing a new photo', () {
    testWidgets('the source sheet offers the camera and the gallery', (tester) async {
      await _open(tester, _backend(), hasAvatar: false);

      await tester.tap(_choose);
      await tester.pumpAndSettle();

      expect(find.text(en.imagePickerCameraLabel), findsOneWidget);
      expect(find.text(en.imagePickerGalleryLabel), findsOneWidget);
    });

    testWidgets('dismissing the sheet changes nothing', (tester) async {
      await _open(tester, _backend(), hasAvatar: false);

      await tester.tap(_choose);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // the barrier
      await tester.pumpAndSettle();

      expect(find.byType(CircleAvatar), findsNothing);
      expect(tester.widget<FactoryButton>(_save).onPressed, isNull);
    });

    testWidgets('a photo that is picked and cropped is previewed and can then be saved', (tester) async {
      await mockImagePickAndCrop(tester);
      await _open(tester, _backend(), hasAvatar: false);

      await _pickFromGallery(tester);

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(tester.widget<FactoryButton>(_save).onPressed, isNotNull);
    });

    testWidgets('backing out of the cropper leaves nothing chosen', (tester) async {
      await mockImagePickAndCrop(tester, cropCancelled: true);
      await _open(tester, _backend(), hasAvatar: false);

      await _pickFromGallery(tester);

      expect(find.byType(CircleAvatar), findsNothing);
      expect(tester.widget<FactoryButton>(_save).onPressed, isNull);
    });

    testWidgets('a picker that fails shows "failed to read file"', (tester) async {
      await mockImagePickAndCrop(tester, pickerFails: true);
      await _open(tester, _backend(), hasAvatar: false);

      await _pickFromGallery(tester);

      expect(find.text(en.errorReadFileFailed), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNothing);
    });
  });

  group('saving the new photo', () {
    testWidgets('uploads the image, sets it as the avatar and closes the dialog', (tester) async {
      await mockImagePickAndCrop(tester, pickedName: 'me.png');
      final http = _backend();
      await _open(tester, http, hasAvatar: false);
      await _pickFromGallery(tester);

      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(http.calls('POST', '/uploads'), hasLength(1));
      expect(http.bodyOf('PATCH', '/auth/me/avatar'), {'avatarUrl': 'https://cdn.example/avatars/1.png'});
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('a failed upload is reported and the dialog stays open, ready to retry', (tester) async {
      await mockImagePickAndCrop(tester);
      final http = _backend();
      http.fail('POST', '/uploads', 500);
      await _open(tester, http, hasAvatar: false);
      await _pickFromGallery(tester);

      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(find.text(en.errorAvatarUpdateFailed), findsOneWidget);
      expect(http.calls('PATCH', '/auth/me/avatar'), isEmpty);
      expect(tester.widget<FactoryButton>(_save).onPressed, isNotNull);
    });
  });
}
