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
import 'package:zairo/features/booking/presentation/screens/booking_confirmation_screen.dart';
import 'package:zairo/features/booking/presentation/screens/booking_payment_screen.dart';
import 'package:zairo/features/discovery/data/models/service_summary.dart';
import 'package:zairo/features/payments/data/models/payment.dart';
import 'package:zairo/features/payments/data/payments_api.dart';
import 'package:zairo/features/payments/presentation/providers/payments_providers.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeBookingApi extends BookingApi {
  _FakeBookingApi() : super(DioClient(Dio()));

  String status = 'PENDING_PAYMENT';
  int getBookingCalls = 0;

  @override
  Future<Booking> getBooking(String bookingId) async {
    getBookingCalls++;
    return _booking(status: status);
  }
}

class _FakePaymentsApi extends PaymentsApi {
  _FakePaymentsApi() : super(DioClient(Dio()));

  Payment? existing;
  Payment onCreate = _payment('PENDING', url: 'https://pay.example/checkout/p1');
  int createCalls = 0;

  @override
  Future<Payment?> getPayment(String bookingId) async => existing;

  @override
  Future<Payment> createPayment(String bookingId) async {
    createCalls++;
    existing = onCreate;
    return onCreate;
  }
}

Booking _booking({String status = 'PENDING_PAYMENT'}) => Booking(
  id: 'booking-1',
  userId: 'user-1',
  serviceId: 'service-1',
  availabilitySlotId: 'slot-1',
  status: status,
  totalPrice: 30,
  createdAt: DateTime(2026, 1, 1, 9),
);

Payment _payment(String status, {String? url}) => Payment(
  id: 'payment-1',
  bookingId: 'booking-1',
  amount: 30,
  currency: 'KZT',
  status: status,
  checkoutUrl: url,
  createdAt: DateTime(2026, 1, 1, 9),
);

const _service = ServiceSummary(id: 'service-1', title: 'Haircut', durationMinutes: 30, price: 30, currency: 'KZT');

BookingConfirmationArgs _confirmation() => BookingConfirmationArgs(
  booking: _booking(),
  providerId: 'provider-1',
  providerName: 'Test Salon',
  providerVertical: 'beauty',
  service: _service,
  slotStartsAt: DateTime(2026, 1, 2, 10),
);

class _Harness {
  final bookingApi = _FakeBookingApi();
  final paymentsApi = _FakePaymentsApi();
  final opened = <Uri>[];
  bool launchSucceeds = true;
  bool? poppedWith;
  late GoRouter router;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required BookingPaymentArgs args,
  void Function(_Harness)? setUp,
  bool pushedFromList = false,
}) async {
  final h = _Harness();
  setUp?.call(h);
  final router = h.router = GoRouter(
    initialLocation: pushedFromList ? '/list' : '/pay',
    initialExtra: pushedFromList ? null : args,
    routes: [
      GoRoute(
        path: '/list',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              child: const Text('open payment'),
              onPressed: () async {
                h.poppedWith = await context.push<bool>('/pay', extra: args);
              },
            ),
          ),
        ),
      ),
      GoRoute(path: '/pay', builder: (context, state) => BookingPaymentScreen(args: state.extra! as BookingPaymentArgs)),
      // A fresh route, like the deep link `zairo://app/payment-result` opens: the old stack is gone.
      GoRoute(
        path: '/return',
        builder: (context, state) => BookingPaymentScreen(
          args: BookingPaymentArgs(booking: _booking(), fromReturn: true),
        ),
      ),
      GoRoute(
        path: AppRoutes.bookingConfirmation,
        builder: (context, state) =>
            Text('CONFIRMED PAGE ${(state.extra! as BookingConfirmationArgs).booking.status}'),
      ),
      GoRoute(path: AppRoutes.bookings, builder: (context, state) => const Scaffold(body: Text('BOOKINGS PAGE'))),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookingApiProvider.overrideWithValue(h.bookingApi),
        paymentsApiProvider.overrideWithValue(h.paymentsApi),
        checkoutLauncherProvider.overrideWithValue((uri) async {
          h.opened.add(uri);
          return h.launchSucceeds;
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
  if (pushedFromList) {
    await tester.tap(find.text('open payment'));
  }
  await tester.pump();
  await tester.pump();
  return h;
}

void main() {
  testWidgets('a pending payment opens the payment page once and waits for the server to confirm', (tester) async {
    final h = await _pump(
      tester,
      args: BookingPaymentArgs(booking: _booking(), confirmation: _confirmation(), payment: _payment('PENDING', url: 'https://pay.example/checkout/p1')),
    );

    expect(h.opened, [Uri.parse('https://pay.example/checkout/p1')]);
    expect(find.text('Waiting for payment'), findsOneWidget);
    expect(find.text('Open payment page'), findsOneWidget);

    // Still unpaid on the server: nothing changes, the page is not opened again.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Waiting for payment'), findsOneWidget);
    expect(h.opened, hasLength(1));

    // The webhook confirmed the booking: the next check lands on the confirmation.
    h.bookingApi.status = 'CONFIRMED';
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('CONFIRMED PAGE CONFIRMED'), findsOneWidget);
  });

  testWidgets('coming back to the app checks the server immediately', (tester) async {
    final h = await _pump(
      tester,
      args: BookingPaymentArgs(booking: _booking(), confirmation: _confirmation(), payment: _payment('PENDING', url: 'https://pay.example/checkout/p1')),
    );
    final before = h.bookingApi.getBookingCalls;

    h.bookingApi.status = 'CONFIRMED';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(h.bookingApi.getBookingCalls, greaterThan(before));
    expect(find.text('CONFIRMED PAGE CONFIRMED'), findsOneWidget);
  });

  testWidgets('"I\'ve paid" asks the server and says so when it is not confirmed yet', (tester) async {
    await _pump(
      tester,
      args: BookingPaymentArgs(booking: _booking(), confirmation: _confirmation(), payment: _payment('PENDING', url: 'https://pay.example/checkout/p1')),
    );

    await tester.tap(find.text("I've paid — check status"));
    await tester.pump();
    await tester.pump();
    expect(find.text('Not confirmed yet — it can take a minute.'), findsOneWidget);
  });

  testWidgets('only an https payment page is ever opened', (tester) async {
    final h = await _pump(
      tester,
      args: BookingPaymentArgs(booking: _booking(), payment: _payment('PENDING', url: 'intent://evil#Intent;end')),
    );

    expect(h.opened, isEmpty);
    expect(find.text("Couldn't open the payment page."), findsOneWidget);
  });

  testWidgets('a failed payment can be retried, which opens the new payment page', (tester) async {
    final h = await _pump(
      tester,
      args: BookingPaymentArgs(booking: _booking(), confirmation: _confirmation(), payment: _payment('FAILED')),
      setUp: (h) => h.paymentsApi.onCreate = _payment('PENDING', url: 'https://pay.example/checkout/retry'),
    );

    expect(find.text("Payment didn't go through"), findsOneWidget);
    expect(h.opened, isEmpty);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(h.paymentsApi.createCalls, 1);
    expect(h.opened, [Uri.parse('https://pay.example/checkout/retry')]);
    expect(find.text('Waiting for payment'), findsOneWidget);
  });

  testWidgets('a payment the provider reports failed while waiting switches to the failed state', (tester) async {
    final h = await _pump(
      tester,
      args: BookingPaymentArgs(booking: _booking(), payment: _payment('PENDING', url: 'https://pay.example/checkout/p1')),
    );
    h.paymentsApi.existing = _payment('FAILED');

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump();

    expect(find.text("Payment didn't go through"), findsOneWidget);
  });

  testWidgets('a booking released by the server (unpaid too long) shows the not-confirmed state', (tester) async {
    final h = await _pump(
      tester,
      args: BookingPaymentArgs(booking: _booking(), payment: _payment('PENDING', url: 'https://pay.example/checkout/p1')),
    );
    h.bookingApi.status = 'CANCELLED';

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump();

    expect(find.text('Payment not confirmed'), findsOneWidget);
  });

  testWidgets('resuming a booking with a payment already waiting reuses it instead of charging again', (tester) async {
    final h = await _pump(
      tester,
      args: BookingPaymentArgs(booking: _booking()),
      setUp: (h) => h.paymentsApi.existing = _payment('PENDING', url: 'https://pay.example/checkout/p1'),
    );

    expect(h.paymentsApi.createCalls, 0);
    expect(h.opened, [Uri.parse('https://pay.example/checkout/p1')]);
  });

  testWidgets('with no payment yet it starts one', (tester) async {
    final h = await _pump(tester, args: BookingPaymentArgs(booking: _booking()));

    expect(h.paymentsApi.createCalls, 1);
    expect(h.opened, [Uri.parse('https://pay.example/checkout/p1')]);
  });

  testWidgets('opened from the bookings list, a confirmed payment pops back with true', (tester) async {
    final h = await _pump(
      tester,
      args: BookingPaymentArgs(booking: _booking(), payment: _payment('PENDING', url: 'https://pay.example/checkout/p1')),
      pushedFromList: true,
    );
    expect(find.text('Waiting for payment'), findsOneWidget);

    h.bookingApi.status = 'CONFIRMED';
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('open payment'), findsOneWidget);
    expect(h.poppedWith, isTrue);
  });

  testWidgets('Close leaves the booking awaiting payment and goes back', (tester) async {
    final h = await _pump(
      tester,
      args: BookingPaymentArgs(booking: _booking(), payment: _payment('PENDING', url: 'https://pay.example/checkout/p1')),
      pushedFromList: true,
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('open payment'), findsOneWidget);
    expect(h.poppedWith, isFalse);
  });

  testWidgets('coming back from the payment page only reads the payment: it neither charges again nor reopens the page', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      args: BookingPaymentArgs(booking: _booking(), fromReturn: true),
      setUp: (h) => h.paymentsApi.existing = _payment('PENDING', url: 'https://pay.example/checkout/p1'),
    );

    expect(h.paymentsApi.createCalls, 0);
    expect(h.opened, isEmpty);
    expect(find.text('Waiting for payment'), findsOneWidget);

    // The webhook lands: the booking is confirmed, and with no confirmation details it ends on the bookings list.
    h.bookingApi.status = 'CONFIRMED';
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('BOOKINGS PAGE'), findsOneWidget);
    expect(find.text('Payment received — your booking is confirmed.'), findsOneWidget);
  });

  testWidgets('coming back after a failed payment shows it as failed without starting a new one', (tester) async {
    final h = await _pump(
      tester,
      args: BookingPaymentArgs(booking: _booking(), fromReturn: true),
      setUp: (h) => h.paymentsApi.existing = _payment('FAILED'),
    );

    expect(find.text("Payment didn't go through"), findsOneWidget);
    expect(h.paymentsApi.createCalls, 0);
    expect(h.opened, isEmpty);
  });

  testWidgets('the booking details survive the deep link replacing the screen, so "Booking confirmed" still shows them', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      args: BookingPaymentArgs(
        booking: _booking(),
        confirmation: _confirmation(),
        payment: _payment('PENDING', url: 'https://pay.example/checkout/p1'),
      ),
    );
    expect(find.text('Waiting for payment'), findsOneWidget);

    // The customer pays; the app is reopened by the deep link, replacing the whole stack.
    h.paymentsApi.existing = _payment('SUCCEEDED');
    h.bookingApi.status = 'CONFIRMED';
    h.router.go('/return');
    await tester.pumpAndSettle();

    expect(find.text('CONFIRMED PAGE CONFIRMED'), findsOneWidget);
  });
}
