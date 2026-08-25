import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/beauty/data/beauty_admin_api.dart';
import 'package:business_admin/features/beauty/data/models/admin_master.dart';
import 'package:business_admin/features/beauty/presentation/providers/beauty_admin_providers.dart';
import 'package:business_admin/features/billing/data/billing_api.dart';
import 'package:business_admin/features/billing/data/models/subscription.dart';
import 'package:business_admin/features/billing/presentation/providers/billing_providers.dart';
import 'package:business_admin/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:business_admin/features/salon/data/models/admin_booking.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/models/admin_service.dart';
import 'package:business_admin/features/salon/data/models/admin_slot.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/l10n/app_localizations.dart';

class _FakeSalonAdminApi extends SalonAdminApi {
  _FakeSalonAdminApi(this._providers) : super(DioClient(Dio()));

  final List<AdminProvider> _providers;
  Map<String, dynamic>? lastCreateCall;

  @override
  Future<List<AdminProvider>> listMyProviders(String ownerUserId) async => _providers;

  @override
  Future<AdminProvider> createProvider({
    required String ownerUserId,
    required String name,
    required String vertical,
  }) async {
    lastCreateCall = {'ownerUserId': ownerUserId, 'name': name, 'vertical': vertical};
    final created = AdminProvider(id: 'p-new', ownerUserId: ownerUserId, name: name, vertical: vertical, status: 'PENDING');
    _providers.add(created);
    return created;
  }

  @override
  Future<List<AdminService>> listServices(String providerId, {bool includeInactive = false}) async => const [];

  @override
  Future<List<AdminSlot>> listSlots(String providerId) async => const [];

  @override
  Future<List<AdminBooking>> listBookings(String providerId) async => const [];
}

class _FakeBeautyAdminApi extends BeautyAdminApi {
  _FakeBeautyAdminApi() : super(DioClient(Dio()));

  @override
  Future<List<AdminMaster>> listMasters(String providerId, {bool includeInactive = false}) async => const [];
}

class _FakeBillingApi extends BillingApi {
  _FakeBillingApi([this._plan = 'PRO']) : super(DioClient(Dio()));

  final String _plan;

  @override
  Future<Subscription> getMine() async => Subscription(
        id: 'sub-1',
        ownerUserId: 'owner-1',
        plan: _plan,
        status: 'ACTIVE',
        // PRO-shaped limits so these dashboard tests (about the create-salon
        // flow itself, not plan gating) never hit a disabled/limit-reached
        // UI — see SubscriptionApiTests (backend) for the FREE-limit tests.
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

void main() {
  testWidgets('shows a create-salon form when the owner has no salons yet', (tester) async {
    final fakeApi = _FakeSalonAdminApi([]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(fakeApi),
          billingApiProvider.overrideWithValue(_FakeBillingApi()),
          authControllerProvider.overrideWith(_LoggedInOwnerController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You have no businesses yet'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Glow Salon');
    await tester.tap(find.widgetWithText(FilledButton, 'Create business'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastCreateCall, {'ownerUserId': 'owner-1', 'name': 'Glow Salon', 'vertical': 'beauty'});
  });

  testWidgets('lists existing salons and opens the salon detail screen on tap', (tester) async {
    final fakeApi = _FakeSalonAdminApi([
      const AdminProvider(id: 'p1', ownerUserId: 'owner-1', name: 'Glow Salon', vertical: 'beauty', status: 'ACTIVE'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(fakeApi),
          beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
          billingApiProvider.overrideWithValue(_FakeBillingApi()),
          authControllerProvider.overrideWith(_LoggedInOwnerController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Glow Salon'), findsOneWidget);

    await tester.tap(find.text('Glow Salon'));
    await tester.pumpAndSettle();

    expect(find.text('Beauty'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });
}
