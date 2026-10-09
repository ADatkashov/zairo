import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/app/admin_routes.dart';
import 'package:business_admin/app/admin_shell.dart';
import 'package:business_admin/features/auth/presentation/screens/login_screen.dart';
import 'admin_test_harness.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/billing/data/billing_api.dart';
import 'package:business_admin/features/billing/data/models/subscription.dart';
import 'package:business_admin/features/billing/presentation/providers/billing_providers.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';

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

class _LoggedOutController extends AuthController {
  @override
  Future<UserSummary?> build() async => null;
}

List<Override> _ownerOverrides() => [
      salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi()),
      billingApiProvider.overrideWithValue(_FakeBillingApi()),
      authControllerProvider.overrideWith(_LoggedInOwnerController.new),
    ];

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('desktop: a persistent sidebar switches areas', (tester) async {
    _size(tester, const Size(1400, 900));
    await pumpAdminApp(tester, overrides: _ownerOverrides());

    expect(find.byType(AdminSidebar), findsOneWidget);
    expect(find.text('You have no businesses yet'), findsOneWidget);
    expect(find.text('Jamie Owner'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);

    await tester.tap(find.text('Subscription'));
    await tester.pumpAndSettle();

    expect(find.text('PRO plan'), findsOneWidget);
  });

  testWidgets('tablet: an icon-only rail instead of the full sidebar or a bottom bar', (tester) async {
    _size(tester, const Size(900, 900));
    await pumpAdminApp(tester, overrides: _ownerOverrides());

    expect(find.byType(AdminSidebar), findsOneWidget);
    expect(tester.widget<AdminSidebar>(find.byType(AdminSidebar)).compact, isTrue);
    expect(find.text('Jamie Owner'), findsNothing); // labels are tooltips on the rail
    expect(find.text('More'), findsNothing); // no phone bottom bar

    await tester.tap(find.byTooltip('Subscription'));
    await tester.pumpAndSettle();

    expect(find.text('PRO plan'), findsOneWidget);
  });

  testWidgets('phone: a bottom bar replaces the AppBar icons, More lists the rest, back returns to Dashboard', (
    tester,
  ) async {
    _size(tester, const Size(400, 800));
    await pumpAdminApp(tester, overrides: _ownerOverrides());

    expect(find.byType(AdminSidebar), findsNothing);
    for (final label in ['Dashboard', 'Messages', 'Campaigns', 'Loyalty', 'More']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    // The six unlabeled shortcut icons are gone; only log out is left.
    expect(find.byIcon(Icons.campaign_outlined), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    expect(find.byIcon(Icons.logout), findsOneWidget);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('You have no businesses yet'), findsNothing);

    // System back leaves More for the Dashboard instead of closing the app.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('You have no businesses yet'), findsOneWidget);
  });

  testWidgets('a link straight to an area opens it, and More stays highlighted on a phone', (tester) async {
    _size(tester, const Size(400, 800));
    await pumpAdminApp(tester, overrides: _ownerOverrides(), location: AdminRoutes.billing);

    expect(find.text('PRO plan'), findsOneWidget);
    expect(find.text('You have no businesses yet'), findsNothing);
  });

  testWidgets('opening an area while signed out shows the login screen, not the area', (tester) async {
    _size(tester, const Size(400, 800));
    await pumpAdminApp(
      tester,
      overrides: [authControllerProvider.overrideWith(_LoggedOutController.new)],
      location: AdminRoutes.billing,
    );

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('PRO plan'), findsNothing);
  });

  testWidgets('unknown paths land on the dashboard', (tester) async {
    _size(tester, const Size(400, 800));
    await pumpAdminApp(tester, overrides: _ownerOverrides(), location: '/no/such/page');

    expect(find.text('You have no businesses yet'), findsOneWidget);
  });
}
