import 'dart:typed_data';

import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/core/image/pick_and_crop_image.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/profile/presentation/widgets/change_avatar_dialog.dart';
import 'package:zairo/features/storage/data/storage_api.dart';
import 'package:zairo/features/storage/data/uploaded_file.dart';
import 'package:zairo/features/storage/presentation/providers/storage_providers.dart';
import 'package:zairo/l10n/app_localizations.dart';

/// A 1x1 transparent PNG, so the preview can really decode it.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00,
  0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakeStorage extends StorageApi {
  _FakeStorage({this.fail = false}) : super(DioClient(Dio()));

  final bool fail;
  final List<String> uploaded = [];

  @override
  Future<UploadedFile> uploadBytes(Uint8List bytes, String filename) async {
    if (fail) throw Exception('offline');
    uploaded.add(filename);
    return const UploadedFile(key: 'k', url: 'https://cdn.example/avatar.png');
  }
}

class _FakeAuth extends AuthController {
  _FakeAuth({this.failUpdate = false});

  final bool failUpdate;
  final List<String?> avatars = [];

  @override
  Future<UserSummary?> build() async =>
      const UserSummary(id: 'u1', email: 'a@example.com', displayName: 'A', role: 'CUSTOMER');

  @override
  Future<void> updateAvatar(String? avatarUrl) async {
    if (failUpdate) throw Exception('offline');
    avatars.add(avatarUrl);
  }
}

Future<void> _open(
  WidgetTester tester, {
  required _FakeAuth auth,
  required _FakeStorage storage,
  required PickPhoto pick,
  bool hasAvatar = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => auth),
        storageApiProvider.overrideWithValue(storage),
        pickPhotoProvider.overrideWithValue(pick),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showChangeAvatarDialog(context, hasCurrentAvatar: hasAvatar),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<PickedCroppedImage?> _picks(BuildContext context, {required String cropTitle}) async =>
    PickedCroppedImage(bytes: _png, name: 'me.png');

void main() {
  testWidgets('Save is off until a photo is chosen; choosing shows a preview; saving uploads, sets it and closes',
      (tester) async {
    final auth = _FakeAuth();
    final storage = _FakeStorage();
    await _open(tester, auth: auth, storage: storage, pick: _picks);

    expect(find.byType(CircleAvatar), findsNothing);
    expect(tester.widget<FactoryButton>(find.widgetWithText(FactoryButton, 'Save')).onPressed, isNull);

    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();
    expect(find.byType(CircleAvatar), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(storage.uploaded, ['me.png']);
    expect(auth.avatars, ['https://cdn.example/avatar.png']);
    expect(find.text('Change avatar'), findsNothing);
  });

  testWidgets('backing out of the picker changes nothing', (tester) async {
    await _open(tester, auth: _FakeAuth(), storage: _FakeStorage(), pick: (context, {required cropTitle}) async => null);

    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();

    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.text('Failed to read file'), findsNothing);
  });

  testWidgets('a picker that fails says the file could not be read', (tester) async {
    await _open(
      tester,
      auth: _FakeAuth(),
      storage: _FakeStorage(),
      pick: (context, {required cropTitle}) async => throw Exception('no camera'),
    );

    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to read file'), findsOneWidget);
  });

  testWidgets('a failed upload keeps the dialog open with an error', (tester) async {
    final auth = _FakeAuth();
    await _open(tester, auth: auth, storage: _FakeStorage(fail: true), pick: _picks);
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to update avatar'), findsOneWidget);
    expect(find.text('Change avatar'), findsOneWidget);
    expect(auth.avatars, isEmpty);
  });

  testWidgets('"Remove photo" is offered only with a current avatar, clears it and closes', (tester) async {
    final without = _FakeAuth();
    await _open(tester, auth: without, storage: _FakeStorage(), pick: _picks);
    expect(find.text('Remove photo'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Change avatar'), findsNothing);

    final auth = _FakeAuth();
    await _open(tester, auth: auth, storage: _FakeStorage(), pick: _picks, hasAvatar: true);
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();

    expect(auth.avatars, [null]);
    expect(find.text('Change avatar'), findsNothing);
  });

  testWidgets('a failed removal says so and keeps the dialog', (tester) async {
    await _open(
      tester,
      auth: _FakeAuth(failUpdate: true),
      storage: _FakeStorage(),
      pick: _picks,
      hasAvatar: true,
    );

    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to update avatar'), findsOneWidget);
    expect(find.text('Change avatar'), findsOneWidget);
  });
}
