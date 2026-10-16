import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/loyalty/data/api/loyalty_admin_api.dart';
import 'package:business_admin/features/loyalty/data/loyalty_admin_exception.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_reward.dart';
import 'package:business_admin/features/loyalty/presentation/providers/loyalty_admin_providers.dart';
import 'package:business_admin/features/loyalty/presentation/screens/loyalty_reward_form_screen.dart';
import 'package:business_admin/features/salon/data/models/admin_service.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/l10n/app_localizations.dart';

const _providerId = 'provider-1';

class _RecordingLoyaltyApi extends LoyaltyAdminApi {
  _RecordingLoyaltyApi() : super(DioClient(Dio()));

  final List<LoyaltyReward> created = [];
  final List<(String, LoyaltyReward)> updated = [];
  Object? error;

  @override
  Future<LoyaltyReward> createReward(String providerId, LoyaltyReward draft) async {
    if (error != null) throw error!;
    created.add(draft);
    return draft;
  }

  @override
  Future<LoyaltyReward> updateReward(String providerId, String rewardId, LoyaltyReward draft) async {
    if (error != null) throw error!;
    updated.add((rewardId, draft));
    return draft;
  }
}

const _haircut = AdminService(
  id: 'svc1',
  providerId: _providerId,
  title: 'Haircut',
  durationMinutes: 60,
  price: 25,
  currency: 'USD',
  active: true,
);

/// Opens the form from a button so the `Navigator.pop(true)` result can be observed.
Widget _wrap(
  _RecordingLoyaltyApi api, {
  LoyaltyReward? existing,
  List<AdminService> services = const [_haircut],
  void Function(bool?)? onResult,
}) {
  return ProviderScope(
    overrides: [
      loyaltyAdminApiProvider.overrideWithValue(api),
      providerServicesProvider.overrideWith((ref, key) async => services),
    ],
    child: MaterialApp(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
                builder: (_) => LoyaltyRewardFormScreen(providerId: _providerId, existing: existing),
              ));
              onResult?.call(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester, Widget app) async {
  // Tall enough that the whole form is built: a ListView only builds what is on screen.
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _save(WidgetTester tester, {String label = 'Create'}) async {
  await tester.tap(find.widgetWithText(FactoryButton, label));
  await tester.pumpAndSettle();
}

Future<void> _pickType(WidgetTester tester, String chipLabel) async {
  await tester.tap(find.text(chipLabel));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the add form starts as a fixed discount with the regional currency', (tester) async {
    await _open(tester, _wrap(_RecordingLoyaltyApi()));

    expect(find.text('Add reward'), findsOneWidget);
    expect(_field('Discount amount'), findsOneWidget);
    expect(_field('Discount percentage'), findsNothing);
    expect(find.widgetWithText(FactoryButton, 'Create'), findsOneWidget);
    expect(tester.widget<TextField>(_field('Currency')).controller!.text, RegionDefaults.country.currency);
  });

  testWidgets('each reward type shows only the fields that type needs', (tester) async {
    await _open(tester, _wrap(_RecordingLoyaltyApi()));

    await _pickType(tester, 'Percentage discount');
    expect(_field('Discount percentage'), findsOneWidget);
    expect(_field('Discount amount'), findsNothing);

    await _pickType(tester, 'Free service');
    expect(find.text('Service'), findsOneWidget);
    expect(_field('Discount percentage'), findsNothing);

    await _pickType(tester, 'Custom');
    expect(find.textContaining('nothing else to configure'), findsOneWidget);
    expect(_field('Discount amount'), findsNothing);
  });

  testWidgets('an empty name or a non-positive points cost is rejected without calling the API', (tester) async {
    final api = _RecordingLoyaltyApi();
    await _open(tester, _wrap(api));

    await _save(tester);
    expect(find.text('Enter a name and a positive points cost.'), findsOneWidget);

    await tester.enterText(_field('Reward name'), 'Free coffee');
    await tester.enterText(_field('Points cost'), '0');
    await _save(tester);
    expect(find.text('Enter a name and a positive points cost.'), findsOneWidget);

    await tester.enterText(_field('Points cost'), 'abc');
    await _save(tester);
    expect(find.text('Enter a name and a positive points cost.'), findsOneWidget);
    expect(api.created, isEmpty);
  });

  testWidgets('a fixed discount needs a positive amount and a 3-letter currency', (tester) async {
    final api = _RecordingLoyaltyApi();
    await _open(tester, _wrap(api));
    await tester.enterText(_field('Reward name'), '1000 off');
    await tester.enterText(_field('Points cost'), '500');

    await _save(tester); // no amount yet
    expect(find.text('Enter a positive discount amount and a 3-letter currency code.'), findsOneWidget);

    await tester.enterText(_field('Discount amount'), '-5');
    await _save(tester);
    expect(find.text('Enter a positive discount amount and a 3-letter currency code.'), findsOneWidget);

    await tester.enterText(_field('Discount amount'), '1000');
    await tester.enterText(_field('Currency'), 'KZ');
    await _save(tester);
    expect(find.text('Enter a positive discount amount and a 3-letter currency code.'), findsOneWidget);
    expect(api.created, isEmpty);
  });

  testWidgets('a valid fixed discount is created with an upper-cased currency and trimmed text', (tester) async {
    final api = _RecordingLoyaltyApi();
    bool? result;
    await _open(tester, _wrap(api, onResult: (r) => result = r));

    await tester.enterText(_field('Reward name'), '  1000 off  ');
    await tester.enterText(_field('Points cost'), ' 500 ');
    await tester.enterText(_field('Discount amount'), '1000');
    await tester.enterText(_field('Currency'), 'kzt');
    await _save(tester);

    final draft = api.created.single;
    expect(draft.name, '1000 off');
    expect(draft.type, LoyaltyRewardType.fixedDiscount);
    expect(draft.pointsCost, 500);
    expect(draft.discountAmount, 1000);
    expect(draft.discountCurrency, 'KZT');
    expect(draft.discountPercentage, isNull);
    expect(draft.description, isNull);
    expect(draft.terms, isNull);
    expect(result, isTrue);
    expect(find.text('Add reward'), findsNothing); // the form closed
  });

  testWidgets('a percentage must be above 0 and at most 100', (tester) async {
    final api = _RecordingLoyaltyApi();
    await _open(tester, _wrap(api));
    await tester.enterText(_field('Reward name'), '10% off');
    await tester.enterText(_field('Points cost'), '300');
    await _pickType(tester, 'Percentage discount');

    for (final bad in ['0', '101', 'ten']) {
      await tester.enterText(_field('Discount percentage'), bad);
      await _save(tester);
      expect(find.text('Enter a discount percentage between 0 and 100.'), findsOneWidget, reason: bad);
    }
    expect(api.created, isEmpty);

    await tester.enterText(_field('Discount percentage'), '100');
    await _save(tester);
    expect(api.created.single.discountPercentage, 100);
    expect(api.created.single.discountAmount, isNull);
  });

  testWidgets('a free-service reward cannot be saved before a service is picked', (tester) async {
    final api = _RecordingLoyaltyApi();
    await _open(tester, _wrap(api));
    await tester.enterText(_field('Reward name'), 'Free haircut');
    await tester.enterText(_field('Points cost'), '800');
    await _pickType(tester, 'Free service');

    await _save(tester);
    expect(find.text('Pick which service this reward gives for free.'), findsOneWidget);
    expect(api.created, isEmpty);

    await tester.tap(find.text('Service'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haircut').last);
    await tester.pumpAndSettle();
    await _save(tester);

    expect(api.created.single.type, LoyaltyRewardType.freeService);
    expect(api.created.single.serviceId, 'svc1');
  });

  testWidgets('with no services the free-service type explains why nothing can be picked', (tester) async {
    await _open(tester, _wrap(_RecordingLoyaltyApi(), services: const []));
    await _pickType(tester, 'Free service');

    expect(find.text('Add a service first to offer it as a reward.'), findsOneWidget);
  });

  testWidgets('a custom reward needs only a name and a points cost', (tester) async {
    final api = _RecordingLoyaltyApi();
    await _open(tester, _wrap(api));
    await tester.enterText(_field('Reward name'), 'Surprise gift');
    await tester.enterText(_field('Points cost'), '1200');
    await _pickType(tester, 'Custom');

    await _save(tester);

    final draft = api.created.single;
    expect(draft.type, LoyaltyRewardType.custom);
    expect(draft.discountAmount, isNull);
    expect(draft.discountPercentage, isNull);
    expect(draft.serviceId, isNull);
  });

  testWidgets('optional fields are sent when filled in', (tester) async {
    final api = _RecordingLoyaltyApi();
    await _open(tester, _wrap(api));
    await tester.enterText(_field('Reward name'), 'Surprise gift');
    await tester.enterText(find.widgetWithText(TextField, 'Description'), ' A small gift ');
    await tester.enterText(_field('Points cost'), '1200');
    await tester.enterText(find.widgetWithText(TextField, 'Max redemptions (optional)'), '20');
    await tester.enterText(find.widgetWithText(TextField, 'Terms'), ' One per visit ');
    await _pickType(tester, 'Custom');

    await _save(tester);

    final draft = api.created.single;
    expect(draft.description, 'A small gift');
    expect(draft.maxRedemptions, 20);
    expect(draft.terms, 'One per visit');
  });

  testWidgets('editing prefills the form and saves through update, not create', (tester) async {
    final api = _RecordingLoyaltyApi();
    const existing = LoyaltyReward(
      id: 'r1',
      name: '5% off',
      type: LoyaltyRewardType.percentageDiscount,
      pointsCost: 300,
      discountPercentage: 5,
    );
    await _open(tester, _wrap(api, existing: existing));

    expect(find.text('Edit reward'), findsOneWidget);
    expect(tester.widget<TextField>(_field('Reward name')).controller!.text, '5% off');
    expect(tester.widget<TextField>(_field('Points cost')).controller!.text, '300');
    expect(tester.widget<TextField>(_field('Discount percentage')).controller!.text, '5.0');

    await tester.enterText(_field('Discount percentage'), '7');
    await _save(tester, label: 'Save');

    expect(api.created, isEmpty);
    expect(api.updated.single.$1, 'r1');
    expect(api.updated.single.$2.discountPercentage, 7);
    expect(api.updated.single.$2.id, 'r1');
  });

  testWidgets('a server rejection is shown on the form, which stays open and usable', (tester) async {
    final api = _RecordingLoyaltyApi()
      ..error = const LoyaltyAdminException(statusCode: 400, serverMessage: 'Reward name already exists');
    bool? result;
    await _open(tester, _wrap(api, onResult: (r) => result = r));
    await tester.enterText(_field('Reward name'), 'Duplicate');
    await tester.enterText(_field('Points cost'), '100');
    await tester.enterText(_field('Discount amount'), '100');

    await _save(tester);

    expect(find.text('Reward name already exists'), findsOneWidget);
    expect(find.text('Add reward'), findsOneWidget);
    expect(result, isNull);
    expect(tester.widget<TextField>(_field('Reward name')).enabled, isTrue);
  });

  testWidgets('an unknown failure shows the generic message', (tester) async {
    final api = _RecordingLoyaltyApi()..error = StateError('boom');
    await _open(tester, _wrap(api));
    await tester.enterText(_field('Reward name'), 'X');
    await tester.enterText(_field('Points cost'), '100');
    await tester.enterText(_field('Discount amount'), '100');

    await _save(tester);

    expect(find.text('Something went wrong'), findsOneWidget);
  });
}
