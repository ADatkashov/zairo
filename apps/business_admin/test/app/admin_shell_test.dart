import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/app/admin_shell.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/billing/data/billing_api.dart';
import 'package:business_admin/features/billing/data/models/subscription.dart';
import 'package:business_admin/features/billing/presentation/providers/billing_providers.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/l10n/app_localizations.dart';

class _FakeSalonAdminApi extends SalonAdminApi {
  _FakeSalonAdminApi() : super(DioClient(Dio()));

  @override
  Future<List<AdminProvider>> listMyProviders(String ownerUserId) async => const [];
}

class _FakeBillingApi extends BillingApi {
  _FakeBillingApi() : super(DioClient(Dio()));

  @override
  Future<Subscription> getMine() async => Subscription(
        id: 'sub-1',
        ownerUserId: 'owner-1',
        plan: 'PRO',
        status: 'ACTIVE',
        limits: const PlanLimits(
          maxProviders: 5,
          maxStaffPerProvider: 20,
          maxBookingsPerMonth: 2147483647,
          recurringScheduleAllowed: true,
        ),
        currentPeriodStart: DateTime(2026, 1, 1),
        currentPeriodEnd: DateTime(2026, 2, 1),
        cancelAtPeriodEnd: false,
      );
}

class _LoggedInOwnerController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(id: 'owner-1', email: 'owner@example.com', displayName: 'Jamie Owner', role: 'PROVIDER_OWNER');
  }
}

Widget _wrap() => ProviderScope(
      overrides: [
        salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi()),
        billingApiProvider.overrideWithValue(_FakeBillingApi()),
        authControllerProvider.overrideWith(_LoggedInOwnerController.new),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ResponsiveOwnerHome(),
      ),
    );

void main() {
  testWidgets('shows a persistent sidebar and switches destinations at desktop width', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byType(AdminSidebar), findsOneWidget);
    expect(find.text('You have no businesses yet'), findsOneWidget);
    expect(find.text('Jamie Owner'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);

    await tester.tap(find.text('Subscription'));
    await tester.pumpAndSettle();

    expect(find.text('PRO plan'), findsOneWidget);
  });

  testWidgets('falls back to plain DashboardScreen below desktop width', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byType(AdminSidebar), findsNothing);
    expect(find.text('You have no businesses yet'), findsOneWidget);
  });
}
