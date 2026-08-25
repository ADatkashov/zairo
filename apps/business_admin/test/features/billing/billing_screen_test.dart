import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/billing/data/billing_api.dart';
import 'package:business_admin/features/billing/data/models/subscription.dart';
import 'package:business_admin/features/billing/presentation/providers/billing_providers.dart';
import 'package:business_admin/features/billing/presentation/screens/billing_screen.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/l10n/app_localizations.dart';

class _FakeBillingApi extends BillingApi {
  _FakeBillingApi(this._subscription) : super(DioClient(Dio()));

  Subscription _subscription;
  bool upgradeCalled = false;

  @override
  Future<Subscription> getMine() async => _subscription;

  @override
  Future<Subscription> upgradeToPro() async {
    upgradeCalled = true;
    _subscription = _free.copyWith(plan: 'PRO');
    return _subscription;
  }
}

final _free = Subscription(
  id: 'sub-1',
  ownerUserId: 'owner-1',
  plan: 'FREE',
  status: 'ACTIVE',
  limits: PlanLimits(maxProviders: 1, maxStaffPerProvider: 3, maxBookingsPerMonth: 30, recurringScheduleAllowed: false),
  currentPeriodStart: _periodStart,
  currentPeriodEnd: _periodEnd,
  cancelAtPeriodEnd: false,
);

final _periodStart = DateTime(2026, 1, 1);
final _periodEnd = DateTime(2026, 2, 1);

extension on Subscription {
  Subscription copyWith({String? plan}) => Subscription(
        id: id,
        ownerUserId: ownerUserId,
        plan: plan ?? this.plan,
        status: status,
        limits: plan == 'PRO'
            ? const PlanLimits(
                maxProviders: 5, maxStaffPerProvider: 20, maxBookingsPerMonth: 2147483647, recurringScheduleAllowed: true)
            : limits,
        currentPeriodStart: currentPeriodStart,
        currentPeriodEnd: currentPeriodEnd,
        cancelAtPeriodEnd: cancelAtPeriodEnd,
      );
}

class _FakeSalonAdminApi extends SalonAdminApi {
  _FakeSalonAdminApi() : super(DioClient(Dio()));

  @override
  Future<List<AdminProvider>> listMyProviders(String ownerUserId) async => const [];
}

class _LoggedInOwnerController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(id: 'owner-1', email: 'owner@example.com', displayName: 'Jamie Owner', role: 'PROVIDER_OWNER');
  }
}

void main() {
  testWidgets('shows the FREE plan, its limits, and an upgrade button', (tester) async {
    final fakeApi = _FakeBillingApi(_free);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingApiProvider.overrideWithValue(fakeApi),
          authControllerProvider.overrideWith(_LoggedInOwnerController.new),
          salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi()),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BillingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FREE plan'), findsOneWidget);
    expect(find.text('0 / 1'), findsOneWidget);
    expect(find.text('up to 3'), findsOneWidget);
    expect(find.text('up to 30'), findsOneWidget);
    expect(find.text('PRO only'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Upgrade to PRO'), findsOneWidget);
  });

  testWidgets('tapping upgrade calls the API and refreshes to show PRO', (tester) async {
    final fakeApi = _FakeBillingApi(_free);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingApiProvider.overrideWithValue(fakeApi),
          authControllerProvider.overrideWith(_LoggedInOwnerController.new),
          salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi()),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BillingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Upgrade to PRO'));
    await tester.pumpAndSettle();

    expect(fakeApi.upgradeCalled, isTrue);
    expect(find.text('PRO plan'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Downgrade to FREE'), findsOneWidget);
  });
}
