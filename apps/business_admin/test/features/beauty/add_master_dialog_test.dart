import 'package:business_admin/features/beauty/data/beauty_admin_api.dart';
import 'package:business_admin/features/beauty/data/models/admin_master.dart';
import 'package:business_admin/features/beauty/data/models/user_lookup.dart';
import 'package:business_admin/features/beauty/presentation/providers/beauty_admin_providers.dart';
import 'package:business_admin/features/beauty/presentation/widgets/add_master_dialog.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBeautyAdminApi extends BeautyAdminApi {
  _FakeBeautyAdminApi() : super(DioClient(Dio()));

  Map<String, dynamic>? created;

  @override
  Future<UserLookup?> lookupUserByPhone(String phone) async =>
      phone == '+77001234567' ? const UserLookup(id: 'u-1', displayName: 'Aigerim Bekova') : null;

  @override
  Future<AdminMaster> createMasterFromUser({required String providerId, required String userId}) async {
    created = {'providerId': providerId, 'userId': userId};
    return AdminMaster(id: 'm-1', providerId: providerId, displayName: 'Aigerim Bekova', active: true);
  }
}

Widget _app(_FakeBeautyAdminApi api) {
  return ProviderScope(
    overrides: [beautyAdminApiProvider.overrideWithValue(api)],
    child: MaterialApp(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: AddMasterDialog(providerId: 'p1')),
    ),
  );
}

void main() {
  testWidgets('a master is found by phone and added from the profile, with no name typed', (tester) async {
    final api = _FakeBeautyAdminApi();
    await tester.pumpWidget(_app(api));

    expect(find.widgetWithText(TextField, 'Name'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Phone of a registered user'), '+77001234567');
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();
    expect(find.text('Aigerim Bekova'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(api.created, {'providerId': 'p1', 'userId': 'u-1'});
  });

  testWidgets('an unknown phone shows an error and cannot be added', (tester) async {
    final api = _FakeBeautyAdminApi();
    await tester.pumpWidget(_app(api));

    await tester.enterText(find.widgetWithText(TextField, 'Phone of a registered user'), '+70000000000');
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();

    expect(find.text('Nobody is registered with this phone'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Add')).onPressed, isNull);
    expect(api.created, isNull);
  });
}
