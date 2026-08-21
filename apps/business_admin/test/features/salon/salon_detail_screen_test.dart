import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/beauty/data/beauty_admin_api.dart';
import 'package:business_admin/features/beauty/data/models/admin_master.dart';
import 'package:business_admin/features/beauty/presentation/providers/beauty_admin_providers.dart';
import 'package:business_admin/features/salon/data/models/admin_booking.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/models/admin_service.dart';
import 'package:business_admin/features/salon/data/models/admin_slot.dart';
import 'package:business_admin/features/salon/data/models/recurring_schedule_result.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/features/salon/presentation/screens/salon_detail_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';

const _provider = AdminProvider(
  id: 'p1',
  ownerUserId: 'owner-1',
  name: 'Glow Salon',
  vertical: 'beauty',
  status: 'ACTIVE',
);

class _FakeSalonAdminApi extends SalonAdminApi {
  _FakeSalonAdminApi({
    List<AdminService>? services,
    List<AdminSlot>? slots,
    List<AdminBooking>? bookings,
  })  : _services = services ?? [],
        _slots = slots ?? [],
        _bookings = bookings ?? [],
        super(DioClient(Dio()));

  final List<AdminService> _services;
  final List<AdminSlot> _slots;
  final List<AdminBooking> _bookings;
  Map<String, dynamic>? lastCreateServiceCall;
  Map<String, dynamic>? lastUpdateServiceCall;
  Map<String, dynamic>? lastUpdateProviderCall;
  String? lastDeactivatedServiceId;
  String? lastReactivatedServiceId;
  String? lastDeletedSlotId;
  String? lastCompletedBookingId;
  Map<String, dynamic>? lastRecurringScheduleCall;

  @override
  Future<List<AdminService>> listServices(String providerId, {bool includeInactive = false}) async {
    return includeInactive ? _services : _services.where((s) => s.active).toList();
  }

  @override
  Future<AdminProvider> updateProvider({
    required String providerId,
    required String name,
    double? latitude,
    double? longitude,
  }) async {
    lastUpdateProviderCall = {
      'providerId': providerId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
    };
    return AdminProvider(
      id: providerId,
      ownerUserId: _provider.ownerUserId,
      name: name,
      vertical: _provider.vertical,
      status: _provider.status,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<AdminService> createService({
    required String providerId,
    required String title,
    required int durationMinutes,
    required double price,
    required String currency,
  }) async {
    lastCreateServiceCall = {
      'providerId': providerId,
      'title': title,
      'durationMinutes': durationMinutes,
      'price': price,
      'currency': currency,
    };
    final created = AdminService(
      id: 's-new',
      providerId: providerId,
      title: title,
      durationMinutes: durationMinutes,
      price: price,
      currency: currency,
      active: true,
    );
    _services.add(created);
    return created;
  }

  @override
  Future<AdminService> updateService({
    required String serviceId,
    required String title,
    required int durationMinutes,
    required double price,
    required String currency,
  }) async {
    lastUpdateServiceCall = {
      'serviceId': serviceId,
      'title': title,
      'durationMinutes': durationMinutes,
      'price': price,
      'currency': currency,
    };
    final index = _services.indexWhere((s) => s.id == serviceId);
    final updated = AdminService(
      id: serviceId,
      providerId: _services[index].providerId,
      title: title,
      durationMinutes: durationMinutes,
      price: price,
      currency: currency,
      active: true,
    );
    _services[index] = updated;
    return updated;
  }

  @override
  Future<void> deactivateService(String serviceId) async {
    lastDeactivatedServiceId = serviceId;
    final index = _services.indexWhere((s) => s.id == serviceId);
    _services[index] = AdminService(
      id: _services[index].id,
      providerId: _services[index].providerId,
      title: _services[index].title,
      durationMinutes: _services[index].durationMinutes,
      price: _services[index].price,
      currency: _services[index].currency,
      active: false,
    );
  }

  @override
  Future<AdminService> reactivateService(String serviceId) async {
    lastReactivatedServiceId = serviceId;
    final index = _services.indexWhere((s) => s.id == serviceId);
    final reactivated = AdminService(
      id: _services[index].id,
      providerId: _services[index].providerId,
      title: _services[index].title,
      durationMinutes: _services[index].durationMinutes,
      price: _services[index].price,
      currency: _services[index].currency,
      active: true,
    );
    _services[index] = reactivated;
    return reactivated;
  }

  @override
  Future<List<AdminSlot>> listSlots(String providerId) async => _slots;

  @override
  Future<void> deleteSlot(String slotId) async {
    lastDeletedSlotId = slotId;
    _slots.removeWhere((s) => s.id == slotId);
  }

  @override
  Future<RecurringScheduleResult> createRecurringSchedule({
    required String providerId,
    required List<int> daysOfWeek,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required int slotDurationMinutes,
    required int breakMinutes,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    List<DateTime> holidays = const [],
  }) async {
    lastRecurringScheduleCall = {
      'providerId': providerId,
      'daysOfWeek': daysOfWeek,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'slotDurationMinutes': slotDurationMinutes,
      'breakMinutes': breakMinutes,
      'rangeStart': rangeStart,
      'rangeEnd': rangeEnd,
      'holidays': holidays,
    };
    return const RecurringScheduleResult(createdCount: 3, skippedConflictCount: 1);
  }

  @override
  Future<List<AdminBooking>> listBookings(String providerId) async => _bookings;

  @override
  Future<AdminBooking> completeBooking(String bookingId) async {
    lastCompletedBookingId = bookingId;
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    final completed = AdminBooking(
      id: bookingId,
      userId: _bookings[index].userId,
      serviceId: _bookings[index].serviceId,
      availabilitySlotId: _bookings[index].availabilitySlotId,
      status: 'COMPLETED',
      totalPrice: _bookings[index].totalPrice,
      createdAt: _bookings[index].createdAt,
    );
    _bookings[index] = completed;
    return completed;
  }
}

class _FakeBeautyAdminApi extends BeautyAdminApi {
  _FakeBeautyAdminApi([List<AdminMaster>? masters])
      : _masters = masters ?? [],
        super(DioClient(Dio()));

  final List<AdminMaster> _masters;
  String? lastDeactivatedMasterId;
  String? lastReactivatedMasterId;

  @override
  Future<List<AdminMaster>> listMasters(String providerId, {bool includeInactive = false}) async {
    return includeInactive ? _masters : _masters.where((m) => m.active).toList();
  }

  @override
  Future<void> deactivateMaster(String masterId) async {
    lastDeactivatedMasterId = masterId;
    final index = _masters.indexWhere((m) => m.id == masterId);
    _masters[index] = AdminMaster(
      id: _masters[index].id,
      providerId: _masters[index].providerId,
      displayName: _masters[index].displayName,
      bio: _masters[index].bio,
      photoUrl: _masters[index].photoUrl,
      active: false,
    );
  }

  @override
  Future<AdminMaster> reactivateMaster(String masterId) async {
    lastReactivatedMasterId = masterId;
    final index = _masters.indexWhere((m) => m.id == masterId);
    final reactivated = AdminMaster(
      id: _masters[index].id,
      providerId: _masters[index].providerId,
      displayName: _masters[index].displayName,
      bio: _masters[index].bio,
      photoUrl: _masters[index].photoUrl,
      active: true,
    );
    _masters[index] = reactivated;
    return reactivated;
  }
}

void main() {
  testWidgets('shows services and adding one calls the API and refreshes the list', (tester) async {
    final fakeApi = _FakeSalonAdminApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(fakeApi),
          beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SalonDetailScreen(provider: _provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No active services.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Add').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Haircut');
    await tester.enterText(find.widgetWithText(TextField, 'Duration (minutes)'), '30');
    await tester.enterText(find.widgetWithText(TextField, 'Price (USD)'), '25');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastCreateServiceCall, {
      'providerId': 'p1',
      'title': 'Haircut',
      'durationMinutes': 30,
      'price': 25.0,
      'currency': 'USD',
    });
    expect(find.text('Haircut'), findsOneWidget);
  });

  testWidgets('editing a service calls updateService with the new values', (tester) async {
    final fakeApi = _FakeSalonAdminApi(services: [
      const AdminService(
          id: 's1', providerId: 'p1', title: 'Haircut', durationMinutes: 30, price: 25, currency: 'USD',
          active: true),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(fakeApi),
          beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SalonDetailScreen(provider: _provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tooltip 'Edit', not the icon, to disambiguate from the AppBar's
    // 'Edit salon' action which uses the same Icons.edit_outlined.
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Haircut & Style');
    await tester.enterText(find.widgetWithText(TextField, 'Price (USD)'), '35');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastUpdateServiceCall, {
      'serviceId': 's1',
      'title': 'Haircut & Style',
      'durationMinutes': 30,
      'price': 35.0,
      'currency': 'USD',
    });
    expect(find.text('Haircut & Style'), findsOneWidget);
  });

  testWidgets('deleting a service and a slot calls the right APIs and removes them from the list',
      (tester) async {
    final fakeApi = _FakeSalonAdminApi(
      services: [
        const AdminService(
            id: 's1', providerId: 'p1', title: 'Haircut', durationMinutes: 30, price: 25, currency: 'USD',
            active: true),
      ],
      slots: [
        AdminSlot(
            id: 'slot1',
            providerId: 'p1',
            startsAt: DateTime(2026, 1, 1, 10, 0),
            endsAt: DateTime(2026, 1, 1, 10, 30),
            status: 'OPEN'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(fakeApi),
          beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SalonDetailScreen(provider: _provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Haircut'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(fakeApi.lastDeactivatedServiceId, 's1');
    expect(find.text('No active services.'), findsOneWidget);

    expect(find.byType(Chip), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(Chip), matching: find.byIcon(Icons.cancel)));
    await tester.pumpAndSettle();
    expect(fakeApi.lastDeletedSlotId, 'slot1');
    expect(find.text('No time slots yet.'), findsOneWidget);
  });

  testWidgets('marking a confirmed booking complete calls the API', (tester) async {
    final booking = AdminBooking(
      id: 'b1',
      userId: 'u1',
      serviceId: 's1',
      availabilitySlotId: 'slot-1',
      status: 'CONFIRMED',
      totalPrice: 25,
      createdAt: DateTime(2026, 1, 1, 10, 0),
    );
    final fakeApi = _FakeSalonAdminApi(bookings: [booking]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(fakeApi),
          beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SalonDetailScreen(provider: _provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mark complete'), findsOneWidget);

    await tester.tap(find.text('Mark complete'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastCompletedBookingId, 'b1');
    expect(find.text('25 ₸'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('editing the salon calls updateProvider and updates the AppBar title', (tester) async {
    final fakeApi = _FakeSalonAdminApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(fakeApi),
          beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SalonDetailScreen(provider: _provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit salon'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Salon name'), 'Renamed Salon');
    await tester.enterText(find.widgetWithText(TextField, 'Latitude (optional)'), '43.25');
    await tester.enterText(find.widgetWithText(TextField, 'Longitude (optional)'), '76.90');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastUpdateProviderCall, {
      'providerId': 'p1',
      'name': 'Renamed Salon',
      'latitude': 43.25,
      'longitude': 76.90,
    });
    expect(find.text('Renamed Salon'), findsOneWidget);
  });

  testWidgets('a deactivated service is hidden by default and reactivating it brings it back', (tester) async {
    final fakeApi = _FakeSalonAdminApi(services: [
      const AdminService(
          id: 's1', providerId: 'p1', title: 'Haircut', durationMinutes: 30, price: 25, currency: 'USD',
          active: false),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(fakeApi),
          beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SalonDetailScreen(provider: _provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No active services.'), findsOneWidget);
    expect(find.text('Haircut'), findsNothing);

    // .first: this beauty-vertical salon also renders a Masters section
    // with its own "Show removed" toggle, further down the tree.
    await tester.tap(find.widgetWithText(TextButton, 'Show removed').first);
    await tester.pumpAndSettle();

    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('Reactivate'), findsOneWidget);

    await tester.tap(find.text('Reactivate'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastReactivatedServiceId, 's1');
    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('Reactivate'), findsNothing);
  });

  testWidgets('a deactivated master is hidden by default and reactivating it brings it back', (tester) async {
    final fakeApi = _FakeSalonAdminApi();
    final fakeBeautyApi = _FakeBeautyAdminApi([
      const AdminMaster(id: 'm1', providerId: 'p1', displayName: 'Jamie Stylist', active: false),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(fakeApi),
          beautyAdminApiProvider.overrideWithValue(fakeBeautyApi),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SalonDetailScreen(provider: _provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No active masters.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Show removed').last);
    await tester.pumpAndSettle();

    expect(find.text('Jamie Stylist'), findsOneWidget);
    expect(find.text('Reactivate'), findsOneWidget);

    await tester.tap(find.text('Reactivate'));
    await tester.pumpAndSettle();

    expect(fakeBeautyApi.lastReactivatedMasterId, 'm1');
    expect(find.text('Jamie Stylist'), findsOneWidget);
    expect(find.text('Reactivate'), findsNothing);
  });

  testWidgets('recurring schedule dialog opens, toggles a day, and blocks submitting without a time/date range',
      (tester) async {
    final fakeApi = _FakeSalonAdminApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(fakeApi),
          beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SalonDetailScreen(provider: _provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Recurring schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Generate recurring schedule'), findsOneWidget);

    // Toggling a weekday chip doesn't throw and doesn't submit anything.
    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();

    // No time/date picked yet — submitting is rejected client-side, the API is never called.
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(
      find.text('Pick at least one day, a valid time range, a date range, and a positive duration'),
      findsOneWidget,
    );
    expect(fakeApi.lastRecurringScheduleCall, isNull);
  });
}
