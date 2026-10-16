import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/booking/data/booking_api.dart';
import 'package:zairo/features/booking/data/booking_exception.dart';
import 'package:zairo/features/booking/data/models/booking.dart';
import 'package:zairo/features/booking/data/models/reschedule_option.dart';
import 'package:zairo/features/booking/presentation/providers/booking_providers.dart';
import 'package:zairo/features/booking/presentation/screens/my_bookings_screen.dart';
import 'package:zairo/features/payments/data/models/payment.dart';
import 'package:zairo/features/payments/data/payments_api.dart';
import 'package:zairo/features/payments/presentation/providers/payments_providers.dart';
import 'package:zairo/features/reviews/data/models/review.dart';
import 'package:zairo/features/reviews/data/reviews_api.dart';
import 'package:zairo/features/reviews/presentation/providers/reviews_providers.dart';
import 'package:zairo/l10n/app_localizations.dart';

import '../../helpers/fake_http.dart';

class _FakeBookingApi extends BookingApi {
  _FakeBookingApi(this.bookings, {List<RescheduleOption>? options}) : options = options ?? [], super(DioClient(Dio()));

  List<Booking> bookings;
  List<RescheduleOption> options;
  Object? optionsError;
  Object? moveError;
  final List<String> moves = [];
  int optionsCalls = 0;

  @override
  Future<List<Booking>> listMyBookings(String userId) async => bookings;

  @override
  Future<List<RescheduleOption>> rescheduleOptions(String bookingId) async {
    optionsCalls++;
    if (optionsError != null) throw optionsError!;
    return options;
  }

  @override
  Future<Booking> reschedule(String bookingId, String slotId) async {
    if (moveError != null) {
      final error = moveError!;
      // A failed move (a taken time) comes with a fresher list.
      options = options.where((o) => o.slotId != slotId).toList();
      throw error;
    }
    moves.add(slotId);
    final option = options.firstWhere((o) => o.slotId == slotId);
    final old = bookings.single;
    bookings = [
      Booking(
        id: old.id,
        userId: old.userId,
        serviceId: old.serviceId,
        availabilitySlotId: slotId,
        status: old.status,
        totalPrice: old.totalPrice,
        createdAt: old.createdAt,
        providerId: old.providerId,
        startsAt: option.startsAt,
        endsAt: option.endsAt,
      ),
    ];
    return bookings.single;
  }
}

class _FakeReviewsApi extends ReviewsApi {
  _FakeReviewsApi() : super(DioClient(Dio()));

  @override
  Future<Review?> getReview(String bookingId) async => null;
}

class _FakePaymentsApi extends PaymentsApi {
  _FakePaymentsApi() : super(DioClient(Dio()));

  @override
  Future<Payment?> getPayment(String bookingId) async => null;
}

class _LoggedIn extends AuthController {
  @override
  Future<UserSummary?> build() async =>
      const UserSummary(id: 'user-1', email: 'a@example.com', displayName: 'A', role: 'CUSTOMER');
}

Booking _booking({String status = 'CONFIRMED', DateTime? startsAt}) => Booking(
  id: 'b1',
  userId: 'user-1',
  serviceId: 's1',
  availabilitySlotId: 'slot-old',
  status: status,
  totalPrice: 20,
  createdAt: DateTime(2026, 1, 1),
  providerId: 'p1',
  providerName: 'Glow Salon',
  startsAt: startsAt ?? DateTime.now().add(const Duration(days: 2)),
  endsAt: (startsAt ?? DateTime.now().add(const Duration(days: 2))).add(const Duration(hours: 1)),
);

RescheduleOption _option(String id, DateTime start) =>
    RescheduleOption(slotId: id, startsAt: start, endsAt: start.add(const Duration(hours: 1)));

Future<void> _pump(
  WidgetTester tester,
  _FakeBookingApi api, {
  Size size = const Size(800, 1600),
  double textScale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        bookingApiProvider.overrideWithValue(api),
        reviewsApiProvider.overrideWithValue(_FakeReviewsApi()),
        paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
        authControllerProvider.overrideWith(_LoggedIn.new),
      ],
      child: MaterialApp(
        theme: dark ? factoryDarkTheme() : factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const MyBookingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final day = DateTime.now().add(const Duration(days: 4));
  final tenAm = DateTime(day.year, day.month, day.day, 10);

  testWidgets('an upcoming active booking can be rescheduled; a finished or started one cannot', (tester) async {
    await _pump(tester, _FakeBookingApi([_booking()]));
    expect(find.text('Reschedule'), findsOneWidget);

    await _pump(tester, _FakeBookingApi([_booking(startsAt: DateTime.now().subtract(const Duration(hours: 1)))]));
    expect(find.text('Reschedule'), findsNothing);

    await _pump(tester, _FakeBookingApi([_booking(status: 'COMPLETED')]));
    expect(find.text('Reschedule'), findsNothing);
  });

  testWidgets('one tap on a free time moves the booking and says when', (tester) async {
    final api = _FakeBookingApi(
      [_booking()],
      options: [_option('o1', tenAm), _option('o2', tenAm.add(const Duration(hours: 1))), _option('o3', tenAm.add(const Duration(days: 1)))],
    );
    await _pump(tester, api);

    await tester.tap(find.text('Reschedule'));
    await tester.pumpAndSettle();
    expect(find.text('Move to another time'), findsOneWidget);
    // Times are grouped by day: two on the first day, one on the next.
    expect(find.text('10:00'), findsNWidgets(2));
    expect(find.text('11:00'), findsOneWidget);

    await tester.tap(find.text('11:00'));
    await tester.pumpAndSettle();

    expect(api.moves, ['o2']);
    expect(find.text('Move to another time'), findsNothing);
    expect(find.textContaining('Moved to'), findsOneWidget);
  });

  testWidgets('with no other free time it says so', (tester) async {
    await _pump(tester, _FakeBookingApi([_booking()]));

    await tester.tap(find.text('Reschedule'));
    await tester.pumpAndSettle();

    expect(find.text('No other free times right now. Check back later.'), findsOneWidget);
  });

  testWidgets('a time taken meanwhile is reported and drops off the list; the person can pick another', (tester) async {
    final api = _FakeBookingApi([_booking()], options: [_option('o1', tenAm), _option('o2', tenAm.add(const Duration(hours: 1)))])
      ..moveError = const BookingException(BookingErrorKey.slotTaken);
    await _pump(tester, api);

    await tester.tap(find.text('Reschedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10:00'));
    await tester.pumpAndSettle();

    expect(find.text('This time slot was just booked by someone else. Please pick another one.'), findsOneWidget);
    expect(find.text('10:00'), findsNothing);
    expect(find.text('11:00'), findsOneWidget);

    api.moveError = null;
    await tester.tap(find.text('11:00'));
    await tester.pumpAndSettle();
    expect(api.moves, ['o2']);
  });

  testWidgets('any other failure shows a general message and keeps the sheet', (tester) async {
    final api = _FakeBookingApi([_booking()], options: [_option('o1', tenAm)])..moveError = Exception('offline');
    await _pump(tester, api);

    await tester.tap(find.text('Reschedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10:00'));
    await tester.pumpAndSettle();

    expect(find.text('Booking failed'), findsOneWidget);
    expect(find.text('Move to another time'), findsOneWidget);
  });

  testWidgets('a failed load of the times offers a retry', (tester) async {
    final api = _FakeBookingApi([_booking()], options: [_option('o1', tenAm)])..optionsError = Exception('offline');
    await _pump(tester, api);

    await tester.tap(find.text('Reschedule'));
    await tester.pumpAndSettle();
    expect(find.byType(FactoryErrorState), findsOneWidget);

    api.optionsError = null;
    await tester.tap(find.byType(FactoryButton).last);
    await tester.pumpAndSettle();
    expect(find.text('10:00'), findsOneWidget);
  });

  testWidgets('the reschedule sheet fits a 320 px phone with a large font in the dark theme', (tester) async {
    final api = _FakeBookingApi(
      [_booking()],
      options: [
        for (var i = 0; i < 12; i++) _option('o$i', tenAm.add(Duration(hours: i))),
        _option('n1', tenAm.add(const Duration(days: 1))),
      ],
    );
    await _pump(tester, api, size: const Size(320, 640), textScale: 2, dark: true);

    await tester.ensureVisible(find.text('Reschedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reschedule'));
    await tester.pumpAndSettle();

    expect(find.text('Move to another time'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My bookings fits a 320 px phone with a large font in the dark theme, every status', (tester) async {
    final soon = DateTime.now().add(const Duration(days: 2));
    Booking b(String id, String status, {double? deposit}) => Booking(
      id: id,
      userId: 'user-1',
      serviceId: 's$id',
      availabilitySlotId: 'slot-$id',
      status: status,
      totalPrice: 12000,
      depositAmount: deposit,
      remainingAmount: deposit == null ? null : 12000 - deposit,
      createdAt: DateTime(2026, 1, 1),
      serviceTitle: 'Long colouring with toning and a deep care treatment',
      providerId: 'p1',
      providerName: 'A Salon With A Rather Long Name',
      startsAt: status == 'COMPLETED' || status == 'CANCELLED' ? DateTime(2026, 1, 5) : soon,
      endsAt: soon.add(const Duration(hours: 1)),
    );
    await _pump(
      tester,
      _FakeBookingApi([b('1', 'CONFIRMED', deposit: 3000), b('2', 'PENDING_PAYMENT'), b('3', 'COMPLETED'), b('4', 'CANCELLED')]),
      size: const Size(320, 640),
      textScale: 2,
      dark: true,
    );
    expect(tester.takeException(), isNull);

    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  group('BookingApi reschedule', () {
    test('reads the options', () async {
      final http = FakeHttp()
        ..reply('GET', '/bookings/b1/reschedule-options', [
          {'slotId': 'o1', 'startsAt': '2026-10-20T10:00:00Z', 'endsAt': '2026-10-20T11:00:00Z'},
        ]);

      final options = await BookingApi(http.client()).rescheduleOptions('b1');

      expect(options.single.slotId, 'o1');
      expect(options.single.startsAt, DateTime.utc(2026, 10, 20, 10));
      expect(options.single.endsAt, DateTime.utc(2026, 10, 20, 11));
    });

    test('moves with the chosen slot and maps 409/403 to booking errors', () async {
      final http = FakeHttp()
        ..reply('POST', '/bookings/b1/reschedule', {
          'id': 'b1',
          'userId': 'u',
          'serviceId': 's',
          'availabilitySlotId': 'o1',
          'status': 'CONFIRMED',
          'totalPrice': 20,
          'createdAt': '2026-10-01T10:00:00Z',
        })
        ..fail('POST', '/bookings/taken/reschedule', 409)
        ..fail('POST', '/bookings/foreign/reschedule', 403)
        ..fail('POST', '/bookings/broken/reschedule', 500);
      final api = BookingApi(http.client());

      final moved = await api.reschedule('b1', 'o1');
      expect(moved.availabilitySlotId, 'o1');
      expect(http.bodyOf('POST', '/bookings/b1/reschedule'), {'slotId': 'o1'});

      await expectLater(
        api.reschedule('taken', 'o1'),
        throwsA(isA<BookingException>().having((e) => e.key, 'key', BookingErrorKey.slotTaken)),
      );
      await expectLater(
        api.reschedule('foreign', 'o1'),
        throwsA(isA<BookingException>().having((e) => e.key, 'key', BookingErrorKey.notYourBooking)),
      );
      await expectLater(api.reschedule('broken', 'o1'), throwsA(isA<DioException>()));
    });
  });
}
