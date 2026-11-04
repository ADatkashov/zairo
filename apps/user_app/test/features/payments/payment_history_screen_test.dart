import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/core/share/share_launcher.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/booking/data/booking_api.dart';
import 'package:zairo/features/booking/data/models/booking.dart';
import 'package:zairo/features/booking/presentation/providers/booking_providers.dart';
import 'package:zairo/features/payments/data/models/payment.dart';
import 'package:zairo/features/payments/data/payments_api.dart';
import 'package:zairo/features/payments/presentation/providers/payments_providers.dart';
import 'package:zairo/features/payments/presentation/screens/payment_history_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

import '../../helpers/fake_http.dart';

class _FakePaymentsApi extends PaymentsApi {
  _FakePaymentsApi(this.payments, {this.fail = false}) : super(DioClient(Dio()));

  final List<Payment> payments;
  bool fail;

  @override
  Future<List<Payment>> listMyPayments() async {
    if (fail) throw StateError('boom');
    return payments;
  }
}

class _FakeBookingApi extends BookingApi {
  _FakeBookingApi(this.bookings, {this.fail = false}) : super(DioClient(Dio()));

  final List<Booking> bookings;
  final bool fail;

  @override
  Future<List<Booking>> listMyBookings(String userId) async {
    if (fail) throw StateError('no bookings');
    return bookings;
  }
}

class _LoggedIn extends AuthController {
  @override
  Future<UserSummary?> build() async =>
      const UserSummary(id: 'user-1', email: 'a@example.com', displayName: 'A', role: 'CUSTOMER');
}

class _LoggedOut extends AuthController {
  @override
  Future<UserSummary?> build() async => null;
}

Payment _payment(String id, String bookingId, String status, {double amount = 5000, String? type}) => Payment(
  id: id,
  bookingId: bookingId,
  amount: amount,
  currency: 'KZT',
  status: status,
  paymentType: type,
  createdAt: DateTime(2026, 11, 3, 10, 30),
);

final _booking = Booking(
  id: 'b1',
  userId: 'user-1',
  serviceId: 's1',
  availabilitySlotId: 'slot1',
  status: 'CONFIRMED',
  totalPrice: 5000,
  createdAt: DateTime(2026, 11, 1),
  serviceTitle: 'Haircut',
  providerName: 'Glow Salon',
  startsAt: DateTime(2026, 11, 10, 14),
);

Future<void> _pump(
  WidgetTester tester,
  _FakePaymentsApi payments, {
  _FakeBookingApi? bookings,
  bool loggedIn = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        paymentsApiProvider.overrideWithValue(payments),
        bookingApiProvider.overrideWithValue(bookings ?? _FakeBookingApi([_booking])),
        authControllerProvider.overrideWith(loggedIn ? _LoggedIn.new : _LoggedOut.new),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const PaymentHistoryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists each payment with its service, business and status', (tester) async {
    await _pump(tester, _FakePaymentsApi([_payment('aaaaaaaa-1', 'b1', 'SUCCEEDED')]));

    expect(find.text('Haircut'), findsOneWidget);
    expect(find.textContaining('Glow Salon'), findsOneWidget);
    expect(find.text('Succeeded'), findsOneWidget);
  });

  testWidgets('a payment whose booking is unknown still shows, under a generic title', (tester) async {
    await _pump(tester, _FakePaymentsApi([_payment('aaaaaaaa-1', 'gone', 'REFUNDED')]));

    expect(find.text('Booking'), findsOneWidget);
    expect(find.text('Refunded'), findsOneWidget);
  });

  testWidgets('the list survives bookings failing to load, and logged out has no bookings to join', (tester) async {
    await _pump(
      tester,
      _FakePaymentsApi([_payment('aaaaaaaa-1', 'b1', 'REFUND_PENDING')]),
      bookings: _FakeBookingApi(const [], fail: true),
    );
    expect(find.text('Booking'), findsOneWidget);
    expect(find.text('Refund pending'), findsOneWidget);

    await _pump(tester, _FakePaymentsApi([_payment('aaaaaaaa-2', 'b1', 'REFUND_FAILED')]), loggedIn: false);
    expect(find.text('Refund failed'), findsOneWidget);
  });

  testWidgets('tapping a row opens the receipt with the visit, amount and payment number', (tester) async {
    await _pump(tester, _FakePaymentsApi([_payment('abcd1234-1', 'b1', 'SUCCEEDED', type: 'DEPOSIT')]));

    await tester.tap(find.text('Haircut'));
    await tester.pumpAndSettle();

    expect(find.text('Receipt'), findsOneWidget);
    expect(find.text('Glow Salon'), findsOneWidget); // the receipt's own line (the row's is joined with the date)
    expect(find.text('ABCD1234'), findsOneWidget);
    expect(find.textContaining('Deposit'), findsOneWidget);
    expect(find.text('Visit'), findsOneWidget);
  });

  testWidgets('the receipt leaves out what it does not know and names each payment type', (tester) async {
    await _pump(tester, _FakePaymentsApi([_payment('abcd1234-1', 'gone', 'SUCCEEDED', type: 'FULL')]));
    await tester.tap(find.text('Booking'));
    await tester.pumpAndSettle();
    expect(find.text('Service'), findsNothing);
    expect(find.text('Visit'), findsNothing);
    expect(find.textContaining('Full payment'), findsOneWidget);

    Navigator.of(tester.element(find.text('Receipt'))).pop();
    await tester.pumpAndSettle();
    await _pump(tester, _FakePaymentsApi([_payment('abcd1234-2', 'gone', 'SUCCEEDED', type: 'REMAINING')]));
    await tester.tap(find.text('Booking'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Remaining'), findsOneWidget);
  });

  testWidgets('Share receipt sends the receipt as plain text', (tester) async {
    final shared = <(String, String?)>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentsApiProvider.overrideWithValue(
            _FakePaymentsApi([_payment('abcd1234-1', 'b1', 'SUCCEEDED', type: 'DEPOSIT')]),
          ),
          bookingApiProvider.overrideWithValue(_FakeBookingApi([_booking])),
          authControllerProvider.overrideWith(_LoggedIn.new),
          shareLauncherProvider.overrideWithValue((text, {subject}) async => shared.add((text, subject))),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const PaymentHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haircut'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share receipt'));
    await tester.pump();

    expect(shared, hasLength(1));
    expect(shared.single.$2, 'Receipt');
    final lines = shared.single.$1.split('\n');
    expect(lines.first, 'Receipt');
    expect(lines, contains('Service: Haircut'));
    expect(lines, contains('Business: Glow Salon'));
    expect(lines, contains('Payment no.: ABCD1234'));
  });

  testWidgets('while loading, the list shows placeholders instead of a spinner', (tester) async {
    final gate = Completer<List<Payment>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPaymentsProvider.overrideWith((ref) => gate.future),
          bookingApiProvider.overrideWithValue(_FakeBookingApi([_booking])),
          authControllerProvider.overrideWith(_LoggedIn.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const PaymentHistoryScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(FactoryListSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    gate.complete([_payment('aaaaaaaa-1', 'b1', 'SUCCEEDED')]);
    await tester.pumpAndSettle();
    expect(find.byType(FactoryListSkeleton), findsNothing);
    expect(find.text('Haircut'), findsOneWidget);
  });

  testWidgets('no payments yet says so', (tester) async {
    await _pump(tester, _FakePaymentsApi(const []));
    expect(find.text('No payments yet'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry that loads again', (tester) async {
    final api = _FakePaymentsApi([_payment('aaaaaaaa-1', 'b1', 'SUCCEEDED')], fail: true);
    await _pump(tester, api);
    expect(find.text('Could not load your payments.'), findsOneWidget);

    api.fail = false;
    await tester.tap(find.byType(FactoryButton));
    await tester.pumpAndSettle();
    expect(find.text('Haircut'), findsOneWidget);
  });

  test('paymentStatusLabel covers every status and falls back to the raw one', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(paymentStatusLabel(l10n, 'FAILED'), 'Failed');
    expect(paymentStatusLabel(l10n, 'PENDING'), 'Pending');
    expect(paymentStatusLabel(l10n, 'WHATEVER'), 'WHATEVER');
  });

  test('PaymentsApi.listMyPayments parses the list', () async {
    final http = FakeHttp();
    http.reply('GET', '/me/payments', [
      {
        'id': 'p1',
        'bookingId': 'b1',
        'amount': 35.0,
        'currency': 'USD',
        'status': 'SUCCEEDED',
        'createdAt': '2026-11-03T10:30:00Z',
      },
    ]);
    final list = await PaymentsApi(http.client()).listMyPayments();
    expect(list.single.bookingId, 'b1');
    expect(list.single.amount, 35.0);
  });
}
