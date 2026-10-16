import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/city/data/models/city.dart';
import 'package:business_admin/features/city/presentation/providers/city_providers.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/beauty/data/beauty_admin_api.dart';
import 'package:business_admin/features/beauty/data/models/admin_master.dart';
import 'package:business_admin/features/beauty/presentation/providers/beauty_admin_providers.dart';
import 'package:business_admin/features/billing/data/billing_api.dart';
import 'package:business_admin/features/billing/data/models/subscription.dart';
import 'package:business_admin/features/billing/presentation/providers/billing_providers.dart';
import 'package:business_admin/features/campaigns/data/api/campaign_center_api.dart';
import 'package:business_admin/features/campaigns/data/models/campaign.dart';
import 'package:business_admin/features/campaigns/presentation/providers/campaign_providers.dart';
import 'package:business_admin/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:business_admin/features/salon/data/models/admin_booking.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/models/admin_service.dart';
import 'package:business_admin/features/salon/data/models/admin_slot.dart';
import 'package:business_admin/features/salon/data/models/dashboard_metrics.dart';
import 'package:business_admin/features/salon/data/models/schedule_entry.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/features/salon/presentation/screens/week_calendar_screen.dart';
import 'package:business_admin/features/salon/presentation/widgets/add_service_dialog.dart';
import 'package:business_admin/features/salon/presentation/widgets/recurring_schedule_dialog.dart';
import 'package:business_admin/features/staff_owner/data/models/needs_attention.dart';
import 'package:business_admin/features/staff_owner/data/staff_owner_api.dart';
import 'package:business_admin/features/staff_owner/presentation/providers/staff_owner_providers.dart';
import 'package:business_admin/l10n/app_localizations.dart';

class _FakeSalonAdminApi extends SalonAdminApi {
  _FakeSalonAdminApi(this._providers, {Map<String, DashboardMetrics>? metricsByProviderId})
      : _metricsByProviderId = metricsByProviderId ?? const {},
        super(DioClient(Dio()));

  final List<AdminProvider> _providers;
  final Map<String, DashboardMetrics> _metricsByProviderId;
  Map<String, dynamic>? lastCreateCall;

  /// When set, creating a business fails with it (a network error, say).
  Object? createError;

  /// Null = the schedule endpoint "fails" (the card stays hidden, as on a
  /// real error), so tests that aren't about the agenda are unaffected.
  List<ScheduleEntry>? schedule;

  @override
  Future<List<AdminProvider>> listMyProviders(String ownerUserId) async => _providers;

  @override
  Future<DashboardMetrics> fetchDashboardMetrics(String providerId) async =>
      _metricsByProviderId[providerId] ??
      const DashboardMetrics(
        totalBookings: 0,
        completedBookings: 0,
        cancelledBookings: 0,
        cancellationRate: 0,
        totalCustomers: 0,
        totalRevenue: 0,
        topServices: [],
      );

  @override
  Future<AdminProvider> createProvider({
    required String ownerUserId,
    required String name,
    required String vertical,
    required String cityCode,
  }) async {
    if (createError != null) throw createError!;
    lastCreateCall = {'ownerUserId': ownerUserId, 'name': name, 'vertical': vertical, 'cityCode': cityCode};
    final created = AdminProvider(id: 'p-new', ownerUserId: ownerUserId, name: name, vertical: vertical, status: 'PENDING');
    _providers.add(created);
    return created;
  }

  @override
  Future<List<ScheduleEntry>> fetchSchedule(String providerId, {required DateTime from, required DateTime to}) async =>
      schedule ?? (throw StateError('no schedule in this test'));

  @override
  Future<List<AdminService>> listServices(String providerId, {bool includeInactive = false}) async => [
        const AdminService(
          id: 's1',
          providerId: 'p1',
          title: 'Gel manicure',
          durationMinutes: 75,
          price: 8500,
          currency: 'KZT',
          active: true,
        ),
      ];

  @override
  Future<List<AdminSlot>> listSlots(String providerId) async => const [];

  @override
  Future<List<AdminBooking>> listBookings(String providerId) async => const [];
}

class _FakeCampaignCenterApi extends CampaignCenterApi {
  _FakeCampaignCenterApi() : super(DioClient(Dio()));

  @override
  Future<SmartActionsResponse> fetchSmartActions(String providerId) async =>
      SmartActionsResponse(providerId: providerId, items: const []);
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
        limits: _plan == 'FREE'
            ? const PlanLimits(maxProviders: 1, maxStaffPerProvider: 3, maxBookingsPerMonth: 30,
                recurringScheduleAllowed: false)
            : const PlanLimits(
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

/// How many appointments per business wait for the owner's decision.
class _FakeStaffOwnerApi extends StaffOwnerApi {
  _FakeStaffOwnerApi(this.counts) : super(DioClient(Dio()));

  final Map<String, int> counts;

  @override
  Future<List<NeedsAttentionItem>> needsAttention(String providerId) async => [
        for (var i = 0; i < (counts[providerId] ?? 0); i++)
          NeedsAttentionItem(
            bookingId: 'b$i',
            status: 'CONFIRMED',
            startsAt: DateTime(2026, 10, 20, 10),
            endsAt: DateTime(2026, 10, 20, 11),
            serviceTitle: 'Haircut',
            customerName: 'Aisha',
            customerPhone: null,
            totalPrice: 10,
            currency: 'KZT',
            workerId: 'w1',
            workerKind: 'MASTER',
            workerName: 'Aigerim',
            reason: 'WORKER_CANNOT_ATTEND',
            workerNote: null,
            requestedAt: null,
          ),
      ];
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
          campaignCenterApiProvider.overrideWithValue(_FakeCampaignCenterApi()),
          authControllerProvider.overrideWith(_LoggedInOwnerController.new),
          activeCitiesProvider.overrideWith(
            (ref) async => [
              City(code: 'almaty', name: 'Almaty', countryCode: 'KZ', timezone: 'Asia/Almaty', currency: 'KZT', active: true),
            ],
          ),
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

    expect(fakeApi.lastCreateCall, {'ownerUserId': 'owner-1', 'name': 'Glow Salon', 'vertical': 'beauty', 'cityCode': 'almaty'});
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
          campaignCenterApiProvider.overrideWithValue(_FakeCampaignCenterApi()),
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

  testWidgets('shows a disabled upgrade notice instead of "Add another business" once the FREE limit is reached',
      (tester) async {
    final fakeApi = _FakeSalonAdminApi([
      const AdminProvider(id: 'p1', ownerUserId: 'owner-1', name: 'Glow Salon', vertical: 'beauty', status: 'ACTIVE'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(fakeApi),
          beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
          billingApiProvider.overrideWithValue(_FakeBillingApi('FREE')),
          campaignCenterApiProvider.overrideWithValue(_FakeCampaignCenterApi()),
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

    expect(find.text('Your plan allows 1 business(es). Tap to upgrade.'), findsOneWidget);
    final disabledButton = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Add another business'));
    expect(disabledButton.onPressed, isNull);

    await tester.tap(find.text('Your plan allows 1 business(es). Tap to upgrade.'));
    await tester.pumpAndSettle();

    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('FREE plan'), findsOneWidget);
  });

  testWidgets('overview hero sums dashboard metrics across every business the owner manages', (tester) async {
    final fakeApi = _FakeSalonAdminApi(
      [
        const AdminProvider(id: 'p1', ownerUserId: 'owner-1', name: 'Glow Salon', vertical: 'beauty', status: 'ACTIVE'),
        const AdminProvider(id: 'p2', ownerUserId: 'owner-1', name: 'Central Garage', vertical: 'auto', status: 'ACTIVE'),
      ],
      metricsByProviderId: {
        'p1': const DashboardMetrics(
          totalBookings: 5,
          completedBookings: 4,
          cancelledBookings: 1,
          cancellationRate: 0.2,
          totalCustomers: 3,
          totalRevenue: 15000,
          topServices: [],
        ),
        'p2': const DashboardMetrics(
          totalBookings: 2,
          completedBookings: 2,
          cancelledBookings: 0,
          cancellationRate: 0,
          totalCustomers: 2,
          totalRevenue: 9000,
          topServices: [],
        ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(fakeApi),
          beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
          billingApiProvider.overrideWithValue(_FakeBillingApi()),
          campaignCenterApiProvider.overrideWithValue(_FakeCampaignCenterApi()),
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

    // 2 businesses, 7 bookings, 5 customers, 24 000 ₸ revenue — summed
    // across both providers, not just the first.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.textContaining('24'), findsWidgets);
  });

  Future<void> pumpDashboard(WidgetTester tester, List<AdminProvider> providers) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi(providers)),
          beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
          billingApiProvider.overrideWithValue(_FakeBillingApi()),
          campaignCenterApiProvider.overrideWithValue(_FakeCampaignCenterApi()),
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
  }

  testWidgets('quick actions with one business open the schedule dialog straight away', (tester) async {
    await pumpDashboard(tester, [
      const AdminProvider(id: 'p1', ownerUserId: 'owner-1', name: 'Glow Salon', vertical: 'beauty', status: 'ACTIVE'),
    ]);

    await tester.tap(find.text('Set schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Which business?'), findsNothing);
    expect(find.byType(RecurringScheduleDialog), findsOneWidget);
  });

  testWidgets('quick actions with several businesses ask which one first', (tester) async {
    await pumpDashboard(tester, [
      const AdminProvider(id: 'p1', ownerUserId: 'owner-1', name: 'Glow Salon', vertical: 'beauty', status: 'ACTIVE'),
      const AdminProvider(id: 'p2', ownerUserId: 'owner-1', name: 'Speedy Workshop', vertical: 'auto', status: 'ACTIVE'),
    ]);

    await tester.tap(find.text('Add service'));
    await tester.pumpAndSettle();
    expect(find.text('Which business?'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Speedy Workshop')));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AddServiceDialog>(find.byType(AddServiceDialog));
    expect(dialog.providerId, 'p2');
  });

  testWidgets("shows today's bookings with time, service and status, leaving cancelled ones out", (tester) async {
    final now = DateTime.now();
    final noon = DateTime(now.year, now.month, now.day, 12);
    ScheduleEntry entry(String id, String status, DateTime at) => ScheduleEntry(
          bookingId: id,
          serviceId: 's1',
          availabilitySlotId: 'slot-$id',
          status: status,
          startsAt: at.toUtc(),
          endsAt: at.add(const Duration(minutes: 75)).toUtc(),
          totalPrice: 8500,
          currency: 'KZT',
        );
    final fakeApi = _FakeSalonAdminApi([
      const AdminProvider(id: 'p1', ownerUserId: 'owner-1', name: 'Glow Salon', vertical: 'beauty', status: 'ACTIVE'),
    ])
      ..schedule = [entry('b1', 'CONFIRMED', noon), entry('b2', 'CANCELLED', noon.add(const Duration(hours: 1)))];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(fakeApi),
          beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
          billingApiProvider.overrideWithValue(_FakeBillingApi()),
          campaignCenterApiProvider.overrideWithValue(_FakeCampaignCenterApi()),
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

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Gel manicure'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    // The cancelled booking is not listed.
    expect(find.text('13:00'), findsNothing);
  });

  testWidgets('week calendar groups bookings by day and steps to the next week', (tester) async {
    ScheduleEntry entry(String id, String status, DateTime at) => ScheduleEntry(
          bookingId: id,
          serviceId: 's1',
          availabilitySlotId: 'slot-$id',
          status: status,
          startsAt: at.toUtc(),
          endsAt: at.add(const Duration(minutes: 75)).toUtc(),
          totalPrice: 8500,
          currency: 'KZT',
        );
    // Wed 7 Oct 2026: that week runs Mon 5 – Sun 11.
    final fakeApi = _FakeSalonAdminApi([
      const AdminProvider(id: 'p1', ownerUserId: 'owner-1', name: 'Glow Salon', vertical: 'beauty', status: 'ACTIVE'),
    ])
      ..schedule = [
        entry('b1', 'CONFIRMED', DateTime(2026, 10, 7, 12)),
        entry('b2', 'PENDING_PAYMENT', DateTime(2026, 10, 8, 10)),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(fakeApi),
          authControllerProvider.overrideWith(_LoggedInOwnerController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WeekCalendarScreen(ownerUserId: 'owner-1', today: DateTime(2026, 10, 7)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gel manicure'), findsNWidgets(2));
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Awaiting payment'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('This week'), findsNothing);

    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    // The fake returns the same two bookings, but none fall in the next week.
    expect(find.text('Gel manicure'), findsNothing);
    expect(find.text('No bookings'), findsNWidgets(7));
    expect(find.text('This week'), findsOneWidget);
  });

  group('the "Add another business" dialog', () {
    Future<_FakeSalonAdminApi> openDialog(WidgetTester tester) async {
      final fakeApi = _FakeSalonAdminApi([
        const AdminProvider(id: 'p1', ownerUserId: 'owner-1', name: 'Glow Salon', vertical: 'beauty', status: 'ACTIVE'),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salonAdminApiProvider.overrideWithValue(fakeApi),
            beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
            billingApiProvider.overrideWithValue(_FakeBillingApi()),
            campaignCenterApiProvider.overrideWithValue(_FakeCampaignCenterApi()),
            authControllerProvider.overrideWith(_LoggedInOwnerController.new),
            activeCitiesProvider.overrideWith(
              (ref) async => [
                City(code: 'almaty', name: 'Almaty', countryCode: 'KZ', timezone: 'Asia/Almaty', currency: 'KZT', active: true),
              ],
            ),
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
      final add = find.widgetWithText(OutlinedButton, 'Add another business');
      await tester.scrollUntilVisible(add, 200);
      await tester.tap(add);
      await tester.pumpAndSettle();
      return fakeApi;
    }

    testWidgets('the city list shows up on the first opening (it used to stay a spinner)', (tester) async {
      await openDialog(tester);

      expect(find.byType(DropdownButtonFormField<String>), findsWidgets);
      expect(find.text('Almaty'), findsOneWidget);
    });

    testWidgets('an empty name says what is wrong instead of silently doing nothing', (tester) async {
      final fakeApi = await openDialog(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a business name'), findsOneWidget);
      expect(fakeApi.lastCreateCall, isNull);
      expect(find.text('Add a business'), findsOneWidget, reason: 'the dialog stays open');

      // Typing again clears the message.
      await tester.enterText(find.byType(TextField), 'G');
      await tester.pump();
      expect(find.text('Enter a business name'), findsNothing);
    });

    testWidgets('a failed request is reported in the dialog and can be retried', (tester) async {
      final fakeApi = await openDialog(tester);
      fakeApi.createError = StateError('offline');

      await tester.enterText(find.byType(TextField), 'Second Salon');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to create business'), findsOneWidget);
      expect(find.text('Add a business'), findsOneWidget);

      fakeApi.createError = null;
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(fakeApi.lastCreateCall?['name'], 'Second Salon');
      expect(find.text('Add a business'), findsNothing, reason: 'the dialog closes on success');
    });
  });

  Future<void> pumpDashboardWithDecisions(
    WidgetTester tester,
    List<AdminProvider> providers,
    Map<String, int> decisions,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi(providers)),
          beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
          billingApiProvider.overrideWithValue(_FakeBillingApi()),
          campaignCenterApiProvider.overrideWithValue(_FakeCampaignCenterApi()),
          staffOwnerApiProvider.overrideWithValue(_FakeStaffOwnerApi(decisions)),
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
  }

  testWidgets('appointments waiting for the owner\'s decision are the first thing on the dashboard', (tester) async {
    await pumpDashboardWithDecisions(
      tester,
      [const AdminProvider(id: 'p1', ownerUserId: 'owner-1', name: 'Glow Salon', vertical: 'beauty', status: 'ACTIVE')],
      {'p1': 2},
    );

    expect(find.text('2 appointments need your decision'), findsOneWidget);
    expect(find.text('All caught up — nothing needs attention today.'), findsNothing);

    // One tap goes to the business, where the decisions are made.
    await tester.tap(find.text('2 appointments need your decision'));
    await tester.pumpAndSettle();
    expect(find.text('Needs your decision'), findsWidgets);
  });

  testWidgets('with several businesses each one reports its own count by name, and one with none stays quiet', (tester) async {
    await pumpDashboardWithDecisions(
      tester,
      [
        const AdminProvider(id: 'p1', ownerUserId: 'owner-1', name: 'Glow Salon', vertical: 'beauty', status: 'ACTIVE'),
        const AdminProvider(id: 'p2', ownerUserId: 'owner-1', name: 'Fast Garage', vertical: 'auto', status: 'ACTIVE'),
        const AdminProvider(id: 'p3', ownerUserId: 'owner-1', name: 'Quiet Clinic', vertical: 'beauty', status: 'ACTIVE'),
      ],
      {'p1': 1, 'p2': 3},
    );

    expect(find.text('1 appointment needs your decision · Glow Salon'), findsOneWidget);
    expect(find.text('3 appointments need your decision · Fast Garage'), findsOneWidget);
    // The business with nothing waiting is never named in a decision line.
    expect(find.textContaining('need your decision · Quiet Clinic'), findsNothing);
  });

  testWidgets('no decisions waiting means no decision line', (tester) async {
    await pumpDashboardWithDecisions(
      tester,
      [const AdminProvider(id: 'p1', ownerUserId: 'owner-1', name: 'Glow Salon', vertical: 'beauty', status: 'ACTIVE')],
      {},
    );

    expect(find.textContaining('need your decision'), findsNothing);
    expect(find.text('All caught up — nothing needs attention today.'), findsOneWidget);
  });
}
