import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/loyalty/data/api/loyalty_api.dart';
import 'package:zairo/features/loyalty/data/loyalty_exception.dart';
import 'package:zairo/features/loyalty/data/models/loyalty.dart';
import 'package:zairo/features/loyalty/data/models/page.dart';
import 'package:zairo/features/loyalty/presentation/providers/loyalty_providers.dart';
import 'package:zairo/features/loyalty/presentation/screens/my_redemptions_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

LoyaltyRedemption _r(
  String id,
  LoyaltyRedemptionStatus status, {
  String code = 'CODE',
  String? provider = 'Glow Salon',
  DateTime? appliedAt,
}) => LoyaltyRedemption(
  id: id,
  providerId: 'p1',
  providerName: provider,
  rewardId: 'rw-$id',
  rewardName: 'Reward $id',
  rewardType: LoyaltyRewardType.custom,
  pointsSpent: 50,
  code: code,
  status: status,
  createdAt: DateTime(2026, 10, 1, 10),
  appliedAt: appliedAt,
);

Page<LoyaltyRedemption> _page(List<LoyaltyRedemption> rows, {int number = 0, int totalPages = 1}) => Page(
  content: rows,
  totalElements: rows.length,
  totalPages: totalPages,
  number: number,
  size: 20,
  first: number == 0,
  last: number + 1 >= totalPages,
);

class _FakeApi extends LoyaltyApi {
  _FakeApi() : super(DioClient(Dio()));

  Object? cancelError;
  final List<String> cancelled = [];

  @override
  Future<LoyaltyRedemption> cancelRedemption(String id, {String? reason}) async {
    if (cancelError != null) throw cancelError!;
    cancelled.add(id);
    return _r(id, LoyaltyRedemptionStatus.cancelled);
  }
}

class _LoggedIn extends AuthController {
  @override
  Future<UserSummary?> build() async =>
      const UserSummary(id: 'u1', email: 'a@example.com', displayName: 'A', role: 'CUSTOMER');
}

class _LoggedOut extends AuthController {
  @override
  Future<UserSummary?> build() async => null;
}

Future<void> _pump(WidgetTester tester, List<Override> overrides, {bool loggedIn = true}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [authControllerProvider.overrideWith(loggedIn ? _LoggedIn.new : _LoggedOut.new), ...overrides],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MyRedemptionsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a guest is asked to log in', (tester) async {
    await _pump(tester, const [], loggedIn: false);

    expect(find.text('Log in to see your redemption codes'), findsOneWidget);
  });

  testWidgets('no redemptions yet says so', (tester) async {
    await _pump(tester, [myRedemptionsProvider(0).overrideWith((ref) async => _page(const []))]);

    expect(find.text('No redemptions yet'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    var fail = true;
    await _pump(tester, [
      myRedemptionsProvider(0).overrideWith((ref) async {
        if (fail) throw Exception('offline');
        return _page([_r('1', LoyaltyRedemptionStatus.active, code: 'BACK')]);
      }),
    ]);
    expect(find.byType(FactoryErrorState), findsOneWidget);

    fail = false;
    await tester.tap(find.byType(FactoryButton));
    await tester.pumpAndSettle();

    expect(find.text('BACK'), findsOneWidget);
  });

  testWidgets('each code shows its status; only an active one can be cancelled', (tester) async {
    await _pump(tester, [
      myRedemptionsProvider(0).overrideWith(
        (ref) async => _page([
          _r('1', LoyaltyRedemptionStatus.active, code: 'AAA'),
          _r('2', LoyaltyRedemptionStatus.applied, code: 'BBB', appliedAt: DateTime(2026, 10, 2)),
          _r('3', LoyaltyRedemptionStatus.cancelled, code: 'CCC', provider: null),
          _r('4', LoyaltyRedemptionStatus.expired, code: 'DDD'),
        ]),
      ),
    ]);

    for (final status in ['Active', 'Applied', 'Cancelled', 'Expired']) {
      expect(find.text(status), findsOneWidget);
    }
    expect(find.text('AAA'), findsOneWidget);
    expect(find.textContaining('Applied Oct'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('"Load more" appends the next page', (tester) async {
    await _pump(tester, [
      myRedemptionsProvider(0).overrideWith((ref) async => _page([_r('1', LoyaltyRedemptionStatus.applied)], totalPages: 2)),
      myRedemptionsProvider(1).overrideWith(
        (ref) async => _page([_r('2', LoyaltyRedemptionStatus.applied)], number: 1, totalPages: 2),
      ),
    ]);
    expect(find.text('Reward 1'), findsOneWidget);

    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(find.text('Reward 2'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('cancelling asks first; "Keep it" spends nothing, confirming refunds and marks it cancelled', (tester) async {
    final api = _FakeApi();
    await _pump(tester, [
      loyaltyApiProvider.overrideWithValue(api),
      myRedemptionsProvider(0).overrideWith((ref) async => _page([_r('1', LoyaltyRedemptionStatus.active)])),
    ]);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this redemption?'), findsOneWidget);
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(api.cancelled, isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel redemption'));
    await tester.pumpAndSettle();

    expect(api.cancelled, ['1']);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Redemption cancelled — your points were refunded.'), findsOneWidget);
  });

  testWidgets('a refused cancel shows the server\'s reason, any other failure a general message', (tester) async {
    final api = _FakeApi()..cancelError = const LoyaltyException('Already applied');
    await _pump(tester, [
      loyaltyApiProvider.overrideWithValue(api),
      myRedemptionsProvider(0).overrideWith((ref) async => _page([_r('1', LoyaltyRedemptionStatus.active)])),
    ]);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel redemption'));
    await tester.pumpAndSettle();
    expect(find.text('Already applied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));

    api.cancelError = Exception('offline');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel redemption'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Already applied'), findsNothing);
  });
}
