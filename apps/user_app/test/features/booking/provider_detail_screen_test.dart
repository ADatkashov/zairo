import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/booking/data/booking_api.dart';
import 'package:zairo/features/booking/data/models/availability_slot.dart';
import 'package:zairo/features/booking/data/models/booking.dart';
import 'package:zairo/features/booking/presentation/providers/booking_providers.dart';
import 'package:zairo/features/booking/presentation/screens/provider_detail_screen.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/data/models/service_summary.dart';
import 'package:zairo/features/payments/data/models/payment.dart';
import 'package:zairo/features/payments/data/payments_api.dart';
import 'package:zairo/features/payments/presentation/providers/payments_providers.dart';

class _FakeBookingApi extends BookingApi {
  _FakeBookingApi(this._slots) : super(DioClient(Dio()));

  final List<AvailabilitySlot> _slots;
  Map<String, dynamic>? lastBookingCall;

  @override
  Future<List<AvailabilitySlot>> listAvailabilitySlots(String providerId) async => _slots;

  @override
  Future<Booking> createBooking({
    required String userId,
    required String serviceId,
    required String availabilitySlotId,
    required double totalPrice,
  }) async {
    lastBookingCall = {
      'userId': userId,
      'serviceId': serviceId,
      'availabilitySlotId': availabilitySlotId,
      'totalPrice': totalPrice,
    };
    return Booking(
      id: 'booking-1',
      userId: userId,
      serviceId: serviceId,
      availabilitySlotId: availabilitySlotId,
      status: 'CONFIRMED',
      totalPrice: totalPrice,
      createdAt: DateTime.now(),
    );
  }
}

class _FakePaymentsApi extends PaymentsApi {
  _FakePaymentsApi() : super(DioClient(Dio()));

  String? lastChargedBookingId;

  @override
  Future<Payment> createPayment(String bookingId) async {
    lastChargedBookingId = bookingId;
    return Payment(
      id: 'payment-1',
      bookingId: bookingId,
      amount: 30,
      currency: 'USD',
      status: 'SUCCEEDED',
      createdAt: DateTime.now(),
    );
  }
}

class _LoggedInAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(id: 'user-1', email: 'a@example.com', displayName: 'A', role: 'CUSTOMER');
  }
}

void main() {
  testWidgets('selecting a service and slot enables booking and submits the right data', (tester) async {
    final slot = AvailabilitySlot(
      id: 'slot-1',
      providerId: 'provider-1',
      startsAt: DateTime(2026, 1, 1, 10, 0),
      endsAt: DateTime(2026, 1, 1, 10, 30),
      status: 'OPEN',
    );
    final fakeApi = _FakeBookingApi([slot]);
    final fakePaymentsApi = _FakePaymentsApi();
    const provider = ProviderSearchResult(
      id: 'provider-1',
      name: 'Test Salon',
      vertical: 'beauty',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      minPrice: 30,
      services: [
        ServiceSummary(id: 'service-1', title: 'Haircut', durationMinutes: 30, price: 30, currency: 'USD'),
      ],
    );

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(fakeApi),
          paymentsApiProvider.overrideWithValue(fakePaymentsApi),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(navigatorKey: navigatorKey, home: const Scaffold(body: SizedBox())),
      ),
    );
    navigatorKey.currentState!
        .push(MaterialPageRoute(builder: (_) => const ProviderDetailScreen(provider: provider)));
    await tester.pumpAndSettle();

    final bookButtonFinder = find.widgetWithText(FilledButton, 'Book');
    expect(tester.widget<FilledButton>(bookButtonFinder).onPressed, isNull);

    await tester.tap(find.text('Haircut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jan 1, 10:00'));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(bookButtonFinder).onPressed, isNotNull);

    await tester.tap(bookButtonFinder);
    await tester.pumpAndSettle();

    expect(fakeApi.lastBookingCall, {
      'userId': 'user-1',
      'serviceId': 'service-1',
      'availabilitySlotId': 'slot-1',
      'totalPrice': 30.0,
    });
    expect(fakePaymentsApi.lastChargedBookingId, 'booking-1');
    expect(find.text('Booking confirmed and paid!'), findsOneWidget);
  });

  testWidgets('shows a message when there are no open slots', (tester) async {
    final fakeApi = _FakeBookingApi(const []);
    const provider = ProviderSearchResult(
      id: 'provider-2',
      name: 'Empty Salon',
      vertical: 'beauty',
      status: 'ACTIVE',
      hasOpenAvailability: false,
      minPrice: null,
      services: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(fakeApi),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: const MaterialApp(home: ProviderDetailScreen(provider: provider)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No open time slots right now.'), findsOneWidget);
  });
}
