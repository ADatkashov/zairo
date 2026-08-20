import 'package:core_network/core_network.dart';
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
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/features/salon/presentation/screens/salon_detail_screen.dart';

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
  String? lastDeactivatedServiceId;
  String? lastDeletedSlotId;
  String? lastCompletedBookingId;

  @override
  Future<List<AdminService>> listServices(String providerId) async => _services;

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
    _services.removeWhere((s) => s.id == serviceId);
  }

  @override
  Future<List<AdminSlot>> listSlots(String providerId) async => _slots;

  @override
  Future<void> deleteSlot(String slotId) async {
    lastDeletedSlotId = slotId;
    _slots.removeWhere((s) => s.id == slotId);
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

  @override
  Future<List<AdminMaster>> listMasters(String providerId) async => _masters;

  @override
  Future<void> deactivateMaster(String masterId) async {
    lastDeactivatedMasterId = masterId;
    _masters.removeWhere((m) => m.id == masterId);
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
        child: const MaterialApp(home: SalonDetailScreen(provider: _provider)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No services yet.'), findsOneWidget);

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
        child: const MaterialApp(home: SalonDetailScreen(provider: _provider)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
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
        child: const MaterialApp(home: SalonDetailScreen(provider: _provider)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Haircut'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(fakeApi.lastDeactivatedServiceId, 's1');
    expect(find.text('No services yet.'), findsOneWidget);

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
        child: const MaterialApp(home: SalonDetailScreen(provider: _provider)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mark complete'), findsOneWidget);

    await tester.tap(find.text('Mark complete'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastCompletedBookingId, 'b1');
    expect(find.text('\$25.00 — COMPLETED'), findsOneWidget);
  });
}
