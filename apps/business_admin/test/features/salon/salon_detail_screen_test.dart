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
    List<AdminBooking>? bookings,
  })  : _services = services ?? [],
        _bookings = bookings ?? [],
        super(DioClient(Dio()));

  final List<AdminService> _services;
  final List<AdminBooking> _bookings;
  Map<String, dynamic>? lastCreateServiceCall;
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
  Future<List<AdminSlot>> listSlots(String providerId) async => const [];

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
  _FakeBeautyAdminApi([this._masters = const []]) : super(DioClient(Dio()));

  final List<AdminMaster> _masters;

  @override
  Future<List<AdminMaster>> listMasters(String providerId) async => _masters;
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
