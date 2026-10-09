import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zairo/app/router/app_routes.dart';
import 'package:zairo/features/booking/data/booking_api.dart';
import 'package:zairo/features/booking/data/models/booking.dart';
import 'package:zairo/features/booking/presentation/providers/booking_providers.dart';
import 'package:zairo/features/booking/presentation/screens/payment_result_screen.dart';
import 'package:zairo/features/payments/data/models/payment.dart';
import 'package:zairo/features/payments/data/payments_api.dart';
import 'package:zairo/features/payments/presentation/providers/payments_providers.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeBookingApi extends BookingApi {
  _FakeBookingApi({this.fail = false}) : super(DioClient(Dio()));

  final bool fail;
  String status = 'PENDING_PAYMENT';

  @override
  Future<Booking> getBooking(String bookingId) async {
    if (fail) throw DioException(requestOptions: RequestOptions(path: '/bookings/$bookingId'));
    return Booking(
      id: bookingId,
      userId: 'user-1',
      serviceId: 'service-1',
      availabilitySlotId: 'slot-1',
      status: status,
      totalPrice: 30,
      createdAt: DateTime(2026, 1, 1, 9),
    );
  }
}

class _FakePaymentsApi extends PaymentsApi {
  _FakePaymentsApi(this.payment) : super(DioClient(Dio()));

  Payment? payment;
  int createCalls = 0;

  @override
  Future<Payment?> getPayment(String bookingId) async => payment;

  @override
  Future<Payment> createPayment(String bookingId) async {
    createCalls++;
    throw StateError('must not start a payment when coming back');
  }
}

Payment _payment(String status) => Payment(
  id: 'payment-1',
  bookingId: 'booking-1',
  amount: 30,
  currency: 'KZT',
  status: status,
  checkoutUrl: status == 'PENDING' ? 'https://pay.example/checkout/p1' : null,
  createdAt: DateTime(2026, 1, 1, 9),
);

Future<void> _pump(
  WidgetTester tester, {
  required _FakeBookingApi bookingApi,
  required _FakePaymentsApi paymentsApi,
  List<Uri>? opened,
}) async {
  final router = GoRouter(
    initialLocation: '${AppRoutes.paymentResult}?status=success&booking=booking-1',
    routes: [
      GoRoute(
        path: AppRoutes.paymentResult,
        builder: (context, state) => PaymentResultScreen(bookingId: state.uri.queryParameters['booking']!),
      ),
      GoRoute(path: AppRoutes.bookings, builder: (context, state) => const Text('BOOKINGS PAGE')),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookingApiProvider.overrideWithValue(bookingApi),
        paymentsApiProvider.overrideWithValue(paymentsApi),
        checkoutLauncherProvider.overrideWithValue((uri) async {
          opened?.add(uri);
          return true;
        }),
        paymentPollIntervalProvider.overrideWithValue(const Duration(seconds: 1)),
      ],
      child: MaterialApp.router(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('the deep link loads the booking and waits for the server to confirm the payment', (tester) async {
    final bookingApi = _FakeBookingApi();
    final paymentsApi = _FakePaymentsApi(_payment('PENDING'));
    final opened = <Uri>[];
    await _pump(tester, bookingApi: bookingApi, paymentsApi: paymentsApi, opened: opened);

    expect(find.text('Waiting for payment'), findsOneWidget);
    expect(opened, isEmpty);
    expect(paymentsApi.createCalls, 0);

    bookingApi.status = 'CONFIRMED';
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('BOOKINGS PAGE'), findsOneWidget);
  });

  testWidgets('a booking that cannot be loaded offers a retry and a way out', (tester) async {
    await _pump(tester, bookingApi: _FakeBookingApi(fail: true), paymentsApi: _FakePaymentsApi(null));

    expect(find.text("Couldn't start the payment. Please try again."), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('BOOKINGS PAGE'), findsOneWidget);
  });
}
