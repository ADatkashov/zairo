import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/loyalty/data/api/loyalty_api.dart';
import 'package:zairo/features/loyalty/data/loyalty_exception.dart';
import 'package:zairo/features/loyalty/data/models/loyalty.dart';
import 'package:zairo/features/loyalty/presentation/providers/loyalty_providers.dart';
import 'package:zairo/features/loyalty/presentation/screens/business_loyalty_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

LoyaltyBusinessDetail _detail({
  bool enabled = true,
  String? tier,
  int expiring = 0,
  List<String> ways = const [],
  NextMilestone? milestone,
}) => LoyaltyBusinessDetail(
  providerId: 'p1',
  providerName: 'Glow Salon',
  programEnabled: enabled,
  pointsBalance: 120,
  lifetimeEarned: 300,
  lifetimeRedeemed: 180,
  completedVisits: 7,
  tierName: tier,
  pointsExpiringSoon30d: expiring,
  waysToEarn: ways,
  nextMilestone: milestone,
  availableRewardsCount: 1,
);

LoyaltyReward _reward(
  String id,
  String name, {
  LoyaltyRewardType type = LoyaltyRewardType.custom,
  bool affordable = true,
  double? amount,
  double? percent,
  String? description,
  String? terms,
  DateTime? endsAt,
}) => LoyaltyReward(
  id: id,
  name: name,
  description: description,
  type: type,
  pointsCost: 50,
  discountAmount: amount,
  discountCurrency: amount == null ? null : 'KZT',
  discountPercentage: percent,
  endsAt: endsAt,
  terms: terms,
  affordable: affordable,
);

class _LoggedInAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async =>
      const UserSummary(id: 'user-1', email: 'a@example.com', displayName: 'A', role: 'CUSTOMER');
}

class _LoggedOutAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async => null;
}

class _FakeApi extends LoyaltyApi {
  _FakeApi({required this.detail, this.rewardList = const [], this.rewardsFail = false}) : super(DioClient(Dio()));

  final LoyaltyBusinessDetail detail;
  final List<LoyaltyReward> rewardList;
  final bool rewardsFail;
  Object? redeemError;
  final List<String> redeemed = [];
  int detailRequests = 0;

  @override
  Future<LoyaltyBusinessDetail> businessLoyalty(String providerId) async {
    detailRequests++;
    return detail;
  }

  @override
  Future<List<LoyaltyReward>> rewards(String providerId) async {
    if (rewardsFail) throw Exception('offline');
    return rewardList;
  }

  @override
  Future<LoyaltyRedemption> redeem(String rewardId) async {
    if (redeemError != null) throw redeemError!;
    redeemed.add(rewardId);
    return LoyaltyRedemption(
      id: 'r1',
      providerId: 'p1',
      rewardId: rewardId,
      rewardName: 'Reward',
      rewardType: LoyaltyRewardType.custom,
      pointsSpent: 50,
      code: 'ABC-123',
      status: LoyaltyRedemptionStatus.active,
      createdAt: DateTime(2026, 10, 1),
    );
  }
}

Future<void> _pump(WidgetTester tester, LoyaltyApi api, {String? name = 'Glow Salon', bool loggedIn = true}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        loyaltyApiProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(loggedIn ? _LoggedInAuthController.new : _LoggedOutAuthController.new),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BusinessLoyaltyScreen(providerId: 'p1', providerName: name),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a guest is invited to log in, with no error and no request for points', (tester) async {
    final api = _FakeApi(detail: _detail());
    await _pump(tester, api, loggedIn: false);

    expect(find.text('Glow Salon'), findsOneWidget);
    expect(find.text('Log in to see your points and rewards at this business'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(api.detailRequests, 0);
  });

  testWidgets('shows the balance, tier, ways to earn, the next milestone and expiring points', (tester) async {
    await _pump(
      tester,
      _FakeApi(
        detail: _detail(
          tier: 'Gold',
          expiring: 30,
          ways: const ['1 point per 100 KZT spent'],
          milestone: const NextMilestone(label: '10th visit', visitsRequired: 10, visitsRemaining: 3, pointsAwarded: 100),
        ),
      ),
    );

    expect(find.text('Glow Salon'), findsOneWidget);
    expect(find.text('Gold'), findsOneWidget);
    expect(find.text('300'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('1 point per 100 KZT spent'), findsOneWidget);
    expect(find.text('10th visit'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Ways to earn points'), findsOneWidget);
  });

  testWidgets('a program that is switched off says so; a milestone with no target does not divide by zero', (tester) async {
    await _pump(
      tester,
      _FakeApi(
        detail: _detail(
          enabled: false,
          milestone: const NextMilestone(label: 'None', visitsRequired: 0, visitsRemaining: 0, pointsAwarded: 0),
        ),
      ),
    );

    expect(find.text("This business doesn't have an active rewards program right now."), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0);
  });

  testWidgets('without a name the title falls back to the generic one', (tester) async {
    await _pump(tester, _FakeApi(detail: _detail()), name: null);

    expect(find.text('Glow Salon'), findsNothing);
  });

  testWidgets('rewards: each kind of discount reads in words and an unaffordable one is locked', (tester) async {
    await _pump(
      tester,
      _FakeApi(
        detail: _detail(),
        rewardList: [
          _reward('1', 'Fixed', type: LoyaltyRewardType.fixedDiscount, amount: 500, description: 'On any service'),
          _reward('2', 'Percent', type: LoyaltyRewardType.percentageDiscount, percent: 10, terms: 'Weekdays only'),
          _reward('3', 'Half', type: LoyaltyRewardType.percentageDiscount, percent: 7.5, endsAt: DateTime(2027, 1, 1)),
          _reward('4', 'Free', type: LoyaltyRewardType.freeService, affordable: false),
          _reward('5', 'Gift'),
        ],
      ),
    );

    expect(find.text('500 KZT off'), findsOneWidget);
    expect(find.text('10% off'), findsOneWidget);
    expect(find.text('7.5% off'), findsOneWidget);
    expect(find.text('Free service'), findsOneWidget);
    expect(find.text('On any service'), findsOneWidget);
    expect(find.text('Terms: Weekdays only'), findsOneWidget);
    expect(find.textContaining('Ends'), findsOneWidget);
    expect(find.text('Not enough points'), findsOneWidget);
    expect(find.text('Redeem'), findsNWidgets(4));
  });

  testWidgets('no rewards shows an empty note; a failed rewards load offers a retry', (tester) async {
    await _pump(tester, _FakeApi(detail: _detail()));
    expect(find.text('No rewards available'), findsOneWidget);

    await _pump(tester, _FakeApi(detail: _detail(), rewardsFail: true));
    expect(find.byType(FactoryErrorState), findsOneWidget);
  });

  testWidgets('redeeming asks first, then shows the code; cancelling spends nothing', (tester) async {
    final api = _FakeApi(detail: _detail(), rewardList: [_reward('1', 'Gift')]);
    await _pump(tester, api);

    await tester.tap(find.text('Redeem'));
    await tester.pumpAndSettle();
    expect(find.text('Redeem this reward?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.redeemed, isEmpty);

    await tester.tap(find.text('Redeem'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(FactoryButton, 'Redeem')));
    // The card's own spinner keeps animating behind the code dialog, so settle by hand.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(api.redeemed, ['1']);
    expect(find.text('ABC-123'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('ABC-123'), findsNothing);
  });

  testWidgets('a refused redeem shows the server\'s reason, any other failure a general message', (tester) async {
    final api = _FakeApi(detail: _detail(), rewardList: [_reward('1', 'Gift')])
      ..redeemError = const LoyaltyException('Not enough points');
    await _pump(tester, api);

    await tester.tap(find.text('Redeem'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(FactoryButton, 'Redeem')));
    await tester.pumpAndSettle();
    expect(find.text('Not enough points'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6)); // the first message goes away

    api.redeemError = Exception('offline');
    await tester.tap(find.text('Redeem'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(FactoryButton, 'Redeem')));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't redeem this reward"), findsOneWidget);
  });

  testWidgets('"History" opens the points history', (tester) async {
    await _pump(tester, _FakeApi(detail: _detail()));

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Points history'), findsOneWidget);
  });
}
