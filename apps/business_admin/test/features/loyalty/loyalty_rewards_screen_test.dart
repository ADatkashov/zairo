import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/loyalty/data/api/loyalty_admin_api.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_reward.dart';
import 'package:business_admin/features/loyalty/presentation/providers/loyalty_admin_providers.dart';
import 'package:business_admin/features/loyalty/presentation/screens/loyalty_rewards_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';

const _providerId = 'provider-1';

class _FakeLoyaltyAdminApi extends LoyaltyAdminApi {
  _FakeLoyaltyAdminApi(this._rewards) : super(DioClient(Dio()));

  List<LoyaltyReward> _rewards;
  String? lastDeactivatedRewardId;
  String? lastDeletedRewardId;

  @override
  Future<List<LoyaltyReward>> fetchRewards(String providerId) async => _rewards;

  @override
  Future<LoyaltyReward> deactivateReward(String providerId, String rewardId) async {
    lastDeactivatedRewardId = rewardId;
    _rewards = [
      for (final r in _rewards) if (r.id == rewardId) LoyaltyReward(id: r.id, name: r.name, type: r.type, pointsCost: r.pointsCost, redemptionsCount: r.redemptionsCount, active: false) else r,
    ];
    return _rewards.firstWhere((r) => r.id == rewardId);
  }

  @override
  Future<void> deleteReward(String providerId, String rewardId) async {
    lastDeletedRewardId = rewardId;
    _rewards = _rewards.where((r) => r.id != rewardId).toList();
  }
}

const _freshReward = LoyaltyReward(
  id: 'r1',
  name: '5% off next visit',
  type: LoyaltyRewardType.percentageDiscount,
  pointsCost: 300,
  discountPercentage: 5,
  active: true,
);

const _redeemedReward = LoyaltyReward(
  id: 'r2',
  name: 'Free manicure',
  type: LoyaltyRewardType.freeService,
  pointsCost: 800,
  serviceId: 's1',
  redemptionsCount: 4,
  active: true,
);

Widget _wrap(_FakeLoyaltyAdminApi api) => ProviderScope(
      overrides: [loyaltyAdminApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoyaltyRewardsScreen(providerId: _providerId),
      ),
    );

void main() {
  testWidgets('shows the empty state when there are no rewards', (tester) async {
    final api = _FakeLoyaltyAdminApi([]);
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    expect(find.text('No rewards yet'), findsOneWidget);
    expect(find.text('Add reward'), findsWidgets);
  });

  testWidgets('lists rewards with their active/inactive badge', (tester) async {
    final api = _FakeLoyaltyAdminApi([_freshReward, _redeemedReward]);
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    expect(find.text('5% off next visit'), findsOneWidget);
    expect(find.text('Free manicure'), findsOneWidget);
    expect(find.text('Active'), findsNWidgets(2));
  });

  testWidgets('deleting a never-redeemed reward calls the API directly', (tester) async {
    final api = _FakeLoyaltyAdminApi([_freshReward]);
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    // Confirm dialog.
    await tester.tap(find.widgetWithText(FactoryButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(api.lastDeletedRewardId, 'r1');
  });

  testWidgets('deleting a redeemed reward offers Deactivate instead', (tester) async {
    final api = _FakeLoyaltyAdminApi([_redeemedReward]);
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text("Can't delete this reward"), findsOneWidget);
    expect(api.lastDeletedRewardId, isNull);

    await tester.tap(find.widgetWithText(FactoryButton, 'Deactivate'));
    await tester.pumpAndSettle();

    expect(api.lastDeactivatedRewardId, 'r2');
  });
}
