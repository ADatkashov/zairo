import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/loyalty/data/api/loyalty_api.dart';
import 'package:zairo/features/loyalty/data/models/loyalty.dart';
import 'package:zairo/features/loyalty/presentation/providers/loyalty_providers.dart';
import 'package:zairo/features/loyalty/presentation/screens/my_rewards_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeLoyaltyApi extends LoyaltyApi {
  _FakeLoyaltyApi(this._businesses) : super(DioClient(Dio()));

  final List<LoyaltyBusinessSummary> _businesses;

  @override
  Future<List<LoyaltyBusinessSummary>> myLoyalty() async => _businesses;
}

class _LoggedInAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(id: 'user-1', email: 'a@example.com', displayName: 'A', role: 'CUSTOMER');
  }
}

class _LoggedOutAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async => null;
}

Widget _wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('shows a login gate when logged out', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MyRewardsScreen(),
        overrides: [
          loyaltyApiProvider.overrideWithValue(_FakeLoyaltyApi(const [])),
          authControllerProvider.overrideWith(_LoggedOutAuthController.new),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log in to see your rewards across every business'), findsOneWidget);
  });

  testWidgets('shows an empty state with no loyalty accounts yet', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MyRewardsScreen(),
        overrides: [
          loyaltyApiProvider.overrideWithValue(_FakeLoyaltyApi(const [])),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No rewards yet'), findsOneWidget);
  });

  testWidgets('lists each business with its points balance', (tester) async {
    final businesses = [
      const LoyaltyBusinessSummary(
        providerId: 'provider-1',
        providerName: 'Glow Salon',
        programEnabled: true,
        pointsBalance: 120,
        lifetimeEarned: 500,
        tierName: 'Gold',
        pointsExpiringSoon30d: 30,
      ),
      const LoyaltyBusinessSummary(
        providerId: 'provider-2',
        providerName: 'Quick Wash',
        programEnabled: false,
        pointsBalance: 0,
        lifetimeEarned: 0,
        tierName: null,
        pointsExpiringSoon30d: 0,
      ),
    ];

    await tester.pumpWidget(
      _wrap(
        const MyRewardsScreen(),
        overrides: [
          loyaltyApiProvider.overrideWithValue(_FakeLoyaltyApi(businesses)),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Glow Salon'), findsOneWidget);
    expect(find.text('Quick Wash'), findsOneWidget);
    expect(find.text('Gold'), findsOneWidget);
    expect(find.text('No active program'), findsOneWidget);
    // pointsExpiringSoon30d banner only renders for the first business.
    expect(find.text('30 points expiring within 30 days'), findsOneWidget);
  });
}
