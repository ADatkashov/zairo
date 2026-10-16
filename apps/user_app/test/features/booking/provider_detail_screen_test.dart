import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zairo/app/router/app_routes.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/auto/data/auto_api.dart';
import 'package:zairo/features/auto/data/models/mechanic.dart';
import 'package:zairo/features/auto/data/models/vehicle.dart';
import 'package:zairo/features/auto/presentation/providers/auto_providers.dart';
import 'package:zairo/features/beauty/data/beauty_api.dart';
import 'package:zairo/features/beauty/data/models/master.dart';
import 'package:zairo/features/beauty/presentation/providers/beauty_providers.dart';
import 'package:zairo/features/booking/data/booking_api.dart';
import 'package:zairo/features/booking/data/models/availability_slot.dart';
import 'package:zairo/features/booking/data/models/booking.dart';
import 'package:zairo/features/booking/presentation/providers/booking_providers.dart';
import 'package:zairo/features/booking/presentation/screens/booking_confirmation_screen.dart';
import 'package:zairo/features/booking/presentation/screens/booking_payment_screen.dart';
import 'package:zairo/features/booking/presentation/screens/provider_detail_screen.dart';
import 'package:zairo/features/booking/presentation/widgets/booking_stepper.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/data/models/service_summary.dart';
import 'package:zairo/features/payments/data/models/payment.dart';
import 'package:zairo/features/payments/data/models/saved_card.dart';
import 'package:zairo/features/payments/data/payments_api.dart';
import 'package:zairo/features/payments/presentation/providers/payments_providers.dart';
import 'package:zairo/features/staff/data/models/staff.dart';
import 'package:zairo/features/staff/data/staff_api.dart';
import 'package:zairo/features/staff/presentation/providers/staff_providers.dart';
import 'package:zairo/features/workforce/data/models/any_slot.dart';
import 'package:zairo/features/workforce/data/workforce_api.dart';
import 'package:zairo/features/workforce/presentation/providers/workforce_providers.dart';
import 'package:zairo/features/waitlist/data/waitlist_api.dart';
import 'package:zairo/features/waitlist/presentation/providers/waitlist_providers.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeBookingApi extends BookingApi {
  _FakeBookingApi(this._slots) : super(DioClient(Dio()));

  final List<AvailabilitySlot> _slots;
  Map<String, dynamic>? lastBookingCall;

  /// What `GET /bookings/{id}` returns — the full body, including the deposit
  /// the vertical booking endpoints leave out.
  Booking? bookingFromGet;

  @override
  Future<List<AvailabilitySlot>> listAvailabilitySlots(String providerId) async => _slots;

  @override
  Future<Booking> getBooking(String bookingId) async => bookingFromGet ?? (throw StateError('no booking'));

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
      status: 'PENDING_PAYMENT',
      totalPrice: totalPrice,
      createdAt: DateTime.now(),
    );
  }
}

class _FakeWaitlistApi extends WaitlistApi {
  _FakeWaitlistApi() : super(DioClient(Dio()));

  @override
  Future<Set<String>> waitingProviderIds(String userId) async => <String>{};
}

class _FakePaymentsApi extends PaymentsApi {
  _FakePaymentsApi() : super(DioClient(Dio()));

  String? lastChargedBookingId;

  @override
  Future<SavedCards> getSavedCards() async => SavedCards.empty;

  /// What the charge answers — 'PENDING' is a redirect-based provider (Freedom Pay) leaving a checkout page.
  String chargeStatus = 'SUCCEEDED';

  @override
  Future<Payment> createPayment(String bookingId) async {
    lastChargedBookingId = bookingId;
    return Payment(
      id: 'payment-1',
      bookingId: bookingId,
      amount: 30,
      currency: 'USD',
      status: chargeStatus,
      checkoutUrl: chargeStatus == 'PENDING' ? 'https://pay.example/checkout/payment-1' : null,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<Payment?> getPayment(String bookingId) async => lastChargedBookingId == null
      ? null
      : Payment(
          id: 'payment-1',
          bookingId: bookingId,
          amount: 30,
          currency: 'USD',
          status: 'SUCCEEDED',
          createdAt: DateTime.now(),
        );
}

class _FakeBeautyApi extends BeautyApi {
  _FakeBeautyApi([this._masters = const []]) : super(DioClient(Dio()));

  final List<Master> _masters;
  Map<String, dynamic>? lastBeautyBookingCall;

  @override
  Future<List<Master>> listMasters(String providerId) async => _masters;

  @override
  Future<Booking> createBeautyBooking({
    required String userId,
    required String masterId,
    required String serviceId,
    required String availabilitySlotId,
    required double totalPrice,
  }) async {
    lastBeautyBookingCall = {
      'userId': userId,
      'masterId': masterId,
      'serviceId': serviceId,
      'availabilitySlotId': availabilitySlotId,
      'totalPrice': totalPrice,
    };
    return Booking(
      id: 'beauty-booking-1',
      userId: userId,
      serviceId: serviceId,
      availabilitySlotId: availabilitySlotId,
      status: 'PENDING_PAYMENT',
      totalPrice: totalPrice,
      createdAt: DateTime.now(),
    );
  }
}

class _FakeAutoApi extends AutoApi {
  _FakeAutoApi({this._mechanics = const [], this._vehicles = const []}) : super(DioClient(Dio()));

  final List<Mechanic> _mechanics;
  final List<Vehicle> _vehicles;
  Map<String, dynamic>? lastAutoBookingCall;

  @override
  Future<List<Mechanic>> listMechanics(String providerId) async => _mechanics;

  @override
  Future<List<Vehicle>> listVehicles(String userId) async => _vehicles;

  @override
  Future<Booking> createAutoBooking({
    required String userId,
    required String mechanicId,
    required String vehicleId,
    required String serviceId,
    required String availabilitySlotId,
    required double totalPrice,
  }) async {
    lastAutoBookingCall = {
      'userId': userId,
      'mechanicId': mechanicId,
      'vehicleId': vehicleId,
      'serviceId': serviceId,
      'availabilitySlotId': availabilitySlotId,
      'totalPrice': totalPrice,
    };
    return Booking(
      id: 'auto-booking-1',
      userId: userId,
      serviceId: serviceId,
      availabilitySlotId: availabilitySlotId,
      status: 'PENDING_PAYMENT',
      totalPrice: totalPrice,
      createdAt: DateTime.now(),
    );
  }
}

class _FakeStaffApi extends StaffApi {
  _FakeStaffApi([this._staff = const []]) : super(DioClient(Dio()));

  final List<Staff> _staff;
  Map<String, dynamic>? lastStaffBookingCall;

  @override
  Future<List<Staff>> listStaff(String providerId) async => _staff;

  @override
  Future<Booking> createStaffBooking({
    required String userId,
    required String staffId,
    required String serviceId,
    required String availabilitySlotId,
    required double totalPrice,
  }) async {
    lastStaffBookingCall = {
      'userId': userId,
      'staffId': staffId,
      'serviceId': serviceId,
      'availabilitySlotId': availabilitySlotId,
      'totalPrice': totalPrice,
    };
    return Booking(
      id: 'staff-booking-1',
      userId: userId,
      serviceId: serviceId,
      availabilitySlotId: availabilitySlotId,
      status: 'PENDING_PAYMENT',
      totalPrice: totalPrice,
      createdAt: DateTime.now(),
    );
  }
}

/// The per-person availability endpoints. By default a person's times are the business's slots and choosing a
/// person is allowed, so the existing scenarios only differ by *when* the times appear (after picking a person).
class _FakeWorkforceApi extends WorkforceApi {
  _FakeWorkforceApi({
    this.slots = const [],
    this.anySlotList = const [],
    this.allowChoice = true,
    this.workerPrices = const {},
  }) : super(DioClient(Dio()));

  final Map<String, double> workerPrices;

  @override
  Future<Map<String, double>> serviceWorkerPrices(String providerId, String serviceId) async => workerPrices;

  final List<AvailabilitySlot> slots;
  final List<AnySlot> anySlotList;
  final bool allowChoice;
  Map<String, dynamic>? lastAnyCall;

  @override
  Future<bool> allowsWorkerChoice(String providerId) async => allowChoice;

  @override
  Future<List<AvailabilitySlot>> workerSlots(String providerId, String workerId) async => slots;

  @override
  Future<List<AnySlot>> anySlots(String providerId, String serviceId) async => anySlotList;

  @override
  Future<Booking> bookAny({
    required String providerId,
    required String userId,
    required String serviceId,
    required DateTime startsAt,
    String? vehicleId,
  }) async {
    lastAnyCall = {
      'providerId': providerId,
      'userId': userId,
      'serviceId': serviceId,
      'startsAt': startsAt,
      'vehicleId': vehicleId,
    };
    return Booking(
      id: 'any-booking-1',
      userId: userId,
      serviceId: serviceId,
      availabilitySlotId: 'slot-any',
      status: 'PENDING_PAYMENT',
      totalPrice: 40,
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

/// Scrolls [finder] clear of the sticky "Book" bar and the bottom edge before
/// tapping it. `scrollUntilVisible` stops as soon as a widget is merely on
/// screen, which can leave it underneath the bar (a tap there silently misses).
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  // The photo-first header pushes lower sections past the lazily-built part
  // of the list, so scroll a not-yet-built target into existence first.
  if (finder.evaluate().isEmpty) {
    // The page itself is the outermost scrollable; the day picker adds horizontal ones.
    final page = find.byType(Scrollable).first;
    try {
      await tester.scrollUntilVisible(finder, 200, scrollable: page);
    } on StateError {
      await tester.scrollUntilVisible(finder, -200, scrollable: page);
    }
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

/// The detail screen at `/`, plus the confirmation route it replaces itself
/// with after a booking (the real router declares both as root routes).
Widget _routerApp(ProviderSearchResult provider, {double textScale = 1, bool dark = false}) => MaterialApp.router(
      theme: dark ? factoryDarkTheme() : factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => ProviderDetailScreen(provider: provider)),
          GoRoute(
            path: AppRoutes.bookingConfirmation,
            builder: (_, state) =>
                BookingConfirmationScreen.fromArgs(state.extra! as BookingConfirmationArgs),
          ),
          GoRoute(
            path: AppRoutes.bookingPayment,
            builder: (_, state) => BookingPaymentScreen(args: state.extra! as BookingPaymentArgs),
          ),
        ],
      ),
    );

/// Taps "Book", then confirms the pre-payment summary sheet when one opens
/// (a logged-out customer skips it and goes straight to the login gate).
Future<void> bookAndConfirm(WidgetTester tester, Finder book) async {
  await tester.tap(book);
  await tester.pumpAndSettle();
  for (final label in ['Confirm and pay', 'Confirm booking']) {
    final confirm = find.widgetWithText(FactoryButton, label);
    if (confirm.evaluate().isNotEmpty) {
      await tester.tap(confirm);
      return;
    }
  }
}

void main() {
  testWidgets('the pre-payment summary shows the booking; Change creates nothing, Confirm books', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final slot = AvailabilitySlot(
      id: 'slot-1',
      providerId: 'provider-1',
      startsAt: DateTime(2026, 1, 1, 10, 0),
      endsAt: DateTime(2026, 1, 1, 10, 30),
      status: 'OPEN',
    );
    final fakeApi = _FakeBookingApi([slot]);
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(fakeApi),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          beautyApiProvider.overrideWithValue(_FakeBeautyApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: _routerApp(provider),
      ),
    );
    await tester.pumpAndSettle();

    // The progress bar follows the selection: service -> time -> confirm.
    BookingStepper stepper() => tester.widget<BookingStepper>(find.byType(BookingStepper));
    // A single-service salon has nothing to choose: the service is already picked.
    expect(stepper().step, 1);
    await tapVisible(tester, find.widgetWithText(FactoryServiceCard, 'Haircut'));
    await tester.pumpAndSettle();
    expect(stepper().step, 1, reason: 'tapping the picked service keeps it picked');
    await tapVisible(tester, find.text('10:00'));
    await tester.pumpAndSettle();
    expect(stepper().step, 2);

    // "Book" opens the summary instead of booking.
    await tester.tap(find.widgetWithText(FactoryButton, 'Book'));
    await tester.pumpAndSettle();
    expect(find.text('Check your booking'), findsOneWidget);
    expect(find.text('Haircut'), findsWidgets);
    expect(find.text('Test Salon'), findsWidgets);
    expect(fakeApi.lastBookingCall, isNull, reason: 'nothing is created before Confirm');

    // Change: back to the selection, still nothing created, selection kept.
    await tester.tap(find.widgetWithText(FactoryButton, 'Change'));
    await tester.pumpAndSettle();
    expect(find.text('Check your booking'), findsNothing);
    expect(fakeApi.lastBookingCall, isNull);
    expect(stepper().step, 2);

    // Confirm: now it books.
    await tester.tap(find.widgetWithText(FactoryButton, 'Book'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FactoryButton, 'Confirm booking').evaluate().isNotEmpty
        ? find.widgetWithText(FactoryButton, 'Confirm booking')
        : find.widgetWithText(FactoryButton, 'Confirm and pay');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(fakeApi.lastBookingCall, isNotNull);
  });

  testWidgets('the business page fits a 320 px phone with a large font in the dark theme', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final day = DateTime.now().add(const Duration(days: 1));
    final fakeApi = _FakeBookingApi([
      for (var i = 0; i < 6; i++)
        AvailabilitySlot(
          id: 'slot-$i',
          providerId: 'provider-1',
          startsAt: DateTime(day.year, day.month, day.day, 9 + i),
          endsAt: DateTime(day.year, day.month, day.day, 10 + i),
          status: 'OPEN',
        ),
    ]);
    const provider = ProviderSearchResult(
      id: 'provider-1',
      name: 'A Salon With A Rather Long Name That Wraps',
      vertical: 'beauty',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      minPrice: 30,
      services: [
        ServiceSummary(id: 'service-1', title: 'Haircut with a long description', durationMinutes: 30, price: 30, currency: 'USD'),
        ServiceSummary(id: 'service-2', title: 'Colouring', durationMinutes: 120, price: 90, currency: 'USD'),
      ],
      averageRating: 4.2,
      reviewCount: 55,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(fakeApi),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          beautyApiProvider.overrideWithValue(_FakeBeautyApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: _routerApp(provider, textScale: 2, dark: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (var i = 0; i < 10; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('selecting a service and slot enables booking and submits the right data', (tester) async {
    // Tall viewport: the price summary bar would otherwise cover the slot chips.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
      averageRating: 4.2,
      reviewCount: 55,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(fakeApi),
          paymentsApiProvider.overrideWithValue(fakePaymentsApi),
          beautyApiProvider.overrideWithValue(_FakeBeautyApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: _routerApp(provider),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4.2'), findsOneWidget);
    expect(find.text('(55)'), findsOneWidget);
    // The service row shows the service's own currency, not the platform default.
    expect(find.text(r'30 $'), findsWidgets);
    expect(find.text('30 ₸'), findsNothing);

    final bookButtonFinder = find.widgetWithText(FactoryButton, 'Book');
    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNull);

    await tapVisible(tester, find.widgetWithText(FactoryServiceCard, 'Haircut'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('10:00'));
    await tester.pumpAndSettle();

    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNotNull);

    await bookAndConfirm(tester, bookButtonFinder);
    await tester.pumpAndSettle();

    expect(fakeApi.lastBookingCall, {
      'userId': 'user-1',
      'serviceId': 'service-1',
      'availabilitySlotId': 'slot-1',
      'totalPrice': 30.0,
    });
    expect(fakePaymentsApi.lastChargedBookingId, 'booking-1');
    expect(find.text('Booking confirmed!'), findsOneWidget);
    expect(find.text('Your spot at Test Salon is booked.'), findsOneWidget);
  });

  testWidgets(
      'a beauty provider with masters requires picking one and books through the beauty endpoint',
      (tester) async {
    final slot = AvailabilitySlot(
      id: 'slot-1',
      providerId: 'provider-3',
      startsAt: DateTime(2026, 1, 1, 10, 0),
      endsAt: DateTime(2026, 1, 1, 10, 30),
      status: 'OPEN',
    );
    final fakeBookingApi = _FakeBookingApi([slot])
      ..bookingFromGet = Booking(
        id: 'beauty-booking-1',
        userId: 'user-1',
        serviceId: 'service-1',
        availabilitySlotId: 'slot-1',
        status: 'PENDING_PAYMENT',
        totalPrice: 30,
        depositAmount: 3,
        remainingAmount: 30,
        createdAt: DateTime(2026, 1, 1),
      );
    final fakeBeautyApi = _FakeBeautyApi(const [
      Master(id: 'master-1', providerId: 'provider-3', displayName: 'Jamie Stylist', active: true),
    ]);
    final fakePaymentsApi = _FakePaymentsApi();
    const provider = ProviderSearchResult(
      id: 'provider-3',
      name: 'Master Salon',
      vertical: 'beauty',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      minPrice: 30,
      services: [
        ServiceSummary(id: 'service-1', title: 'Haircut', durationMinutes: 30, price: 30, currency: 'USD'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(fakeBookingApi),
          paymentsApiProvider.overrideWithValue(fakePaymentsApi),
          beautyApiProvider.overrideWithValue(fakeBeautyApi),
          workforceApiProvider.overrideWithValue(_FakeWorkforceApi(slots: [slot])),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: _routerApp(provider),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Jamie Stylist'), 200);
    expect(find.text('Jamie Stylist'), findsOneWidget);

    final bookButtonFinder = find.widgetWithText(FactoryButton, 'Book');
    await tapVisible(tester, find.widgetWithText(FactoryServiceCard, 'Haircut'));
    await tester.pumpAndSettle();

    // No times are shown until a person (or "Any master") is chosen -> still disabled.
    expect(find.text('10:00'), findsNothing);
    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNull);

    await tapVisible(tester, find.text('Jamie Stylist'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('10:00'));
    await tester.pumpAndSettle();

    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNotNull);

    await bookAndConfirm(tester, bookButtonFinder);
    await tester.pumpAndSettle();

    expect(fakeBeautyApi.lastBeautyBookingCall, {
      'userId': 'user-1',
      'masterId': 'master-1',
      'serviceId': 'service-1',
      'availabilitySlotId': 'slot-1',
      'totalPrice': 30.0,
    });
    expect(fakeBookingApi.lastBookingCall, isNull);
    expect(fakePaymentsApi.lastChargedBookingId, 'beauty-booking-1');

    // The beauty endpoint's own response has no deposit; the confirmation must
    // still show the real 10% due now, not "0 now".
    expect(find.text('Due now'), findsOneWidget);
    expect(find.text('3 ₸'), findsOneWidget);
    expect(find.text('27 ₸'), findsOneWidget);
  });

  testWidgets(
      'an auto provider with mechanics requires picking a mechanic and vehicle, and books through the auto endpoint',
      (tester) async {
    final slot = AvailabilitySlot(
      id: 'slot-1',
      providerId: 'provider-4',
      startsAt: DateTime(2026, 1, 1, 10, 0),
      endsAt: DateTime(2026, 1, 1, 10, 30),
      status: 'OPEN',
    );
    final fakeBookingApi = _FakeBookingApi([slot]);
    final fakeAutoApi = _FakeAutoApi(
      mechanics: const [
        Mechanic(id: 'mechanic-1', providerId: 'provider-4', displayName: 'Yerlan Mechanic', active: true),
      ],
      vehicles: const [
        Vehicle(id: 'vehicle-1', ownerUserId: 'user-1', make: 'Toyota', model: 'Camry', year: 2019, licensePlate: '777 ABC 02'),
      ],
    );
    final fakePaymentsApi = _FakePaymentsApi();
    const provider = ProviderSearchResult(
      id: 'provider-4',
      name: 'Speedy Workshop',
      vertical: 'auto',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      minPrice: 35,
      services: [
        ServiceSummary(id: 'service-1', title: 'Oil Change', durationMinutes: 30, price: 35, currency: 'USD'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(fakeBookingApi),
          paymentsApiProvider.overrideWithValue(fakePaymentsApi),
          autoApiProvider.overrideWithValue(fakeAutoApi),
          workforceApiProvider.overrideWithValue(_FakeWorkforceApi(slots: [slot])),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderDetailScreen(provider: provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Yerlan Mechanic'), 200);
    expect(find.text('Yerlan Mechanic'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Toyota Camry (2019)'), 200);
    expect(find.text('Toyota Camry (2019)'), findsOneWidget);

    final bookButtonFinder = find.widgetWithText(FactoryButton, 'Book');
    await tapVisible(tester, find.text('Yerlan Mechanic'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Toyota Camry (2019)'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.widgetWithText(FactoryServiceCard, 'Oil Change'));
    await tester.pumpAndSettle();

    // Mechanic + vehicle + service picked, but no slot yet -> still disabled.
    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNull);

    await tapVisible(tester, find.text('10:00'));
    await tester.pumpAndSettle();

    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNotNull);

    await bookAndConfirm(tester, bookButtonFinder);
    await tester.pumpAndSettle();

    expect(fakeAutoApi.lastAutoBookingCall, {
      'userId': 'user-1',
      'mechanicId': 'mechanic-1',
      'vehicleId': 'vehicle-1',
      'serviceId': 'service-1',
      'availabilitySlotId': 'slot-1',
      'totalPrice': 35.0,
    });
    expect(fakeBookingApi.lastBookingCall, isNull);
    expect(fakePaymentsApi.lastChargedBookingId, 'auto-booking-1');
  });

  testWidgets(
      'a provider in a category with no dedicated staff module requires picking a staff member and books '
      'through the generic staff endpoint', (tester) async {
    // Tall viewport: the price summary bar would otherwise cover the slot chips.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final slot = AvailabilitySlot(
      id: 'slot-1',
      providerId: 'provider-5',
      startsAt: DateTime(2026, 1, 1, 10, 0),
      endsAt: DateTime(2026, 1, 1, 10, 30),
      status: 'OPEN',
    );
    final fakeBookingApi = _FakeBookingApi([slot]);
    final fakeStaffApi = _FakeStaffApi(const [
      Staff(id: 'staff-1', providerId: 'provider-5', displayName: 'Dr. Aliya', active: true),
    ]);
    final fakePaymentsApi = _FakePaymentsApi();
    const provider = ProviderSearchResult(
      id: 'provider-5',
      name: 'Downtown Clinic',
      vertical: 'medicine',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      minPrice: 40,
      services: [
        ServiceSummary(id: 'service-1', title: 'Checkup', durationMinutes: 30, price: 40, currency: 'USD'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(fakeBookingApi),
          paymentsApiProvider.overrideWithValue(fakePaymentsApi),
          staffApiProvider.overrideWithValue(fakeStaffApi),
          workforceApiProvider.overrideWithValue(_FakeWorkforceApi(slots: [slot])),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderDetailScreen(provider: provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dr. Aliya'), findsOneWidget);

    final bookButtonFinder = find.widgetWithText(FactoryButton, 'Book');
    await tapVisible(tester, find.widgetWithText(FactoryServiceCard, 'Checkup'));
    await tester.pumpAndSettle();

    // No times are shown until a person is chosen -> still disabled.
    expect(find.text('10:00'), findsNothing);
    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNull);

    await tapVisible(tester, find.text('Dr. Aliya'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('10:00'));
    await tester.pumpAndSettle();

    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNotNull);

    await bookAndConfirm(tester, bookButtonFinder);
    await tester.pumpAndSettle();

    expect(fakeStaffApi.lastStaffBookingCall, {
      'userId': 'user-1',
      'staffId': 'staff-1',
      'serviceId': 'service-1',
      'availabilitySlotId': 'slot-1',
      'totalPrice': 40.0,
    });
    expect(fakeBookingApi.lastBookingCall, isNull);
    expect(fakePaymentsApi.lastChargedBookingId, 'staff-booking-1');
  });

  testWidgets('"Any master" merges the times and books for the picked time without naming a person', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final fakeBookingApi = _FakeBookingApi(const []);
    final fakeWorkforce = _FakeWorkforceApi(
      anySlotList: [
        AnySlot(
          slotId: 'slot-any',
          startsAt: DateTime(2026, 1, 1, 10, 0),
          endsAt: DateTime(2026, 1, 1, 11, 0),
          workerId: 'staff-2',
          workerKind: 'STAFF',
        ),
      ],
    );
    final fakeStaffApi = _FakeStaffApi(const [
      Staff(id: 'staff-1', providerId: 'provider-5', displayName: 'Dr. Aliya', active: true),
      Staff(id: 'staff-2', providerId: 'provider-5', displayName: 'Dr. Bek', active: true),
    ]);
    final fakePaymentsApi = _FakePaymentsApi();
    const provider = ProviderSearchResult(
      id: 'provider-5',
      name: 'Any Clinic',
      vertical: 'medicine',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      minPrice: 40,
      services: [
        ServiceSummary(id: 'service-1', title: 'Checkup', durationMinutes: 30, price: 40, currency: 'USD'),
        ServiceSummary(id: 'service-2', title: 'Consultation', durationMinutes: 15, price: 20, currency: 'USD'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(fakeBookingApi),
          paymentsApiProvider.overrideWithValue(fakePaymentsApi),
          staffApiProvider.overrideWithValue(fakeStaffApi),
          workforceApiProvider.overrideWithValue(fakeWorkforce),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderDetailScreen(provider: provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bookButtonFinder = find.widgetWithText(FactoryButton, 'Book');
    await tapVisible(tester, find.text('Any master'));
    await tester.pumpAndSettle();
    // The times for "Any master" depend on the service.
    expect(find.text('Choose a service first'), findsOneWidget);

    await tapVisible(tester, find.widgetWithText(FactoryServiceCard, 'Checkup'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('10:00'));
    await tester.pumpAndSettle();

    // No person was named, yet booking is enabled.
    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNotNull);
    await bookAndConfirm(tester, bookButtonFinder);
    await tester.pumpAndSettle();

    expect(fakeWorkforce.lastAnyCall?['serviceId'], 'service-1');
    expect(fakeWorkforce.lastAnyCall?['startsAt'], DateTime(2026, 1, 1, 10, 0));
    expect(fakeStaffApi.lastStaffBookingCall, isNull);
    expect(fakeBookingApi.lastBookingCall, isNull);
    expect(fakePaymentsApi.lastChargedBookingId, 'any-booking-1');
  });

  testWidgets('when the owner turns off choosing a person, only "Any master" is offered', (tester) async {
    final fakeWorkforce = _FakeWorkforceApi(
      allowChoice: false,
      anySlotList: [
        AnySlot(
          slotId: 'slot-any',
          startsAt: DateTime(2026, 1, 1, 10, 0),
          endsAt: DateTime(2026, 1, 1, 11, 0),
          workerId: 'staff-1',
          workerKind: 'STAFF',
        ),
      ],
    );
    const provider = ProviderSearchResult(
      id: 'provider-6',
      name: 'Any Only Clinic',
      vertical: 'medicine',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      minPrice: 40,
      services: [
        ServiceSummary(id: 'service-1', title: 'Checkup', durationMinutes: 30, price: 40, currency: 'USD'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(_FakeBookingApi(const [])),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          staffApiProvider.overrideWithValue(_FakeStaffApi(const [
            Staff(id: 'staff-1', providerId: 'provider-6', displayName: 'Dr. Aliya', active: true),
          ])),
          workforceApiProvider.overrideWithValue(fakeWorkforce),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderDetailScreen(provider: provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nobody to choose from: the person is not shown, and there is no "Any master" tile to pick either.
    expect(find.text('Dr. Aliya'), findsNothing);
    expect(find.text('Any master'), findsNothing);

    await tapVisible(tester, find.widgetWithText(FactoryServiceCard, 'Checkup'));
    await tester.pumpAndSettle();
    // Times come straight from the merged list.
    expect(find.text('10:00'), findsOneWidget);
  });

  testWidgets("a chosen master's own price is shown before booking; \"Any master\" keeps the base price",
      (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final slot = AvailabilitySlot(
      id: 'slot-1',
      providerId: 'provider-3',
      startsAt: DateTime(2026, 1, 1, 10, 0),
      endsAt: DateTime(2026, 1, 1, 10, 30),
      status: 'OPEN',
    );
    const provider = ProviderSearchResult(
      id: 'provider-3',
      name: 'Master Salon',
      vertical: 'beauty',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      minPrice: 30,
      services: [
        ServiceSummary(id: 'service-1', title: 'Haircut', durationMinutes: 30, price: 30, currency: 'USD'),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(_FakeBookingApi([slot])),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          beautyApiProvider.overrideWithValue(_FakeBeautyApi(const [
            Master(id: 'master-1', providerId: 'provider-3', displayName: 'Jamie Stylist', active: true),
          ])),
          workforceApiProvider.overrideWithValue(
            _FakeWorkforceApi(slots: [slot], workerPrices: const {'master-1': 45}),
          ),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: _routerApp(provider),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.widgetWithText(FactoryServiceCard, 'Haircut'));
    await tester.pumpAndSettle();
    expect(find.textContaining('45'), findsNothing);

    await tapVisible(tester, find.text('Jamie Stylist'));
    await tester.pumpAndSettle();
    expect(find.textContaining('45'), findsWidgets);
  });

  group('a person picked up front (from their own page)', () {
    const provider = ProviderSearchResult(
      id: 'provider-5',
      name: 'Any Clinic',
      vertical: 'medicine',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      minPrice: 40,
      services: [
        ServiceSummary(id: 'service-1', title: 'Checkup', durationMinutes: 30, price: 40, currency: 'USD'),
      ],
    );

    Future<void> pump(
      WidgetTester tester,
      PreselectedWorker? worker, {
      bool allowChoice = true,
      String? slotId,
      List<AvailabilitySlot> slots = const [],
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingApiProvider.overrideWithValue(_FakeBookingApi(const [])),
            paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
            staffApiProvider.overrideWithValue(
              _FakeStaffApi(const [
                Staff(id: 'staff-1', providerId: 'provider-5', displayName: 'Dr. Aliya', active: true),
                Staff(id: 'staff-2', providerId: 'provider-5', displayName: 'Dr. Bek', active: true),
              ]),
            ),
            workforceApiProvider.overrideWithValue(_FakeWorkforceApi(allowChoice: allowChoice, slots: slots)),
            authControllerProvider.overrideWith(_LoggedInAuthController.new),
          ],
          child: MaterialApp(
            theme: factoryLightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProviderDetailScreen(provider: provider, preselectedWorker: worker, preselectedSlotId: slotId),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    bool selected(WidgetTester tester, String name) =>
        tester.widget<FactorySelectableTile>(find.widgetWithText(FactorySelectableTile, name)).selected;

    testWidgets('is already selected, the others are not', (tester) async {
      await pump(tester, (kind: 'STAFF', id: 'staff-2'));

      expect(selected(tester, 'Dr. Bek'), isTrue);
      expect(selected(tester, 'Dr. Aliya'), isFalse);
    });

    testWidgets('nothing is selected without one, or when they are not among the business\'s people', (tester) async {
      await pump(tester, null);
      expect(selected(tester, 'Dr. Bek'), isFalse);

      await pump(tester, (kind: 'STAFF', id: 'someone-who-left'));
      expect(selected(tester, 'Dr. Bek'), isFalse);
      expect(selected(tester, 'Dr. Aliya'), isFalse);
    });

    final tenOClock = AvailabilitySlot(
      id: 'slot-1',
      providerId: 'provider-5',
      startsAt: DateTime(2026, 1, 1, 10, 0),
      endsAt: DateTime(2026, 1, 1, 10, 30),
      status: 'OPEN',
    );
    FactoryTimeSlotState slotState(WidgetTester tester) =>
        tester.widget<FactoryTimeSlot>(find.widgetWithText(FactoryTimeSlot, '10:00')).state;

    testWidgets('a time tapped on their page is already picked', (tester) async {
      await pump(tester, (kind: 'STAFF', id: 'staff-2'), slotId: 'slot-1', slots: [tenOClock]);
      await tapVisible(tester, find.widgetWithText(FactoryServiceCard, 'Checkup'));
      await tester.pumpAndSettle();

      expect(slotState(tester), FactoryTimeSlotState.selected);
    });

    testWidgets('a time that was booked meanwhile is dropped', (tester) async {
      await pump(tester, (kind: 'STAFF', id: 'staff-2'), slotId: 'booked-meanwhile', slots: [tenOClock]);
      await tapVisible(tester, find.widgetWithText(FactoryServiceCard, 'Checkup'));
      await tester.pumpAndSettle();

      expect(slotState(tester), FactoryTimeSlotState.available);
    });

    testWidgets('a service tapped on their page is already picked; one the business does not offer is ignored', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const twoServices = ProviderSearchResult(
        id: 'provider-5',
        name: 'Any Clinic',
        vertical: 'medicine',
        status: 'ACTIVE',
        hasOpenAvailability: true,
        minPrice: 20,
        services: [
          ServiceSummary(id: 'service-1', title: 'Checkup', durationMinutes: 30, price: 40, currency: 'USD'),
          ServiceSummary(id: 'service-2', title: 'Consultation', durationMinutes: 15, price: 20, currency: 'USD'),
        ],
      );
      Future<void> open(String? serviceId) async {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              bookingApiProvider.overrideWithValue(_FakeBookingApi(const [])),
              paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
              staffApiProvider.overrideWithValue(_FakeStaffApi(const [])),
              workforceApiProvider.overrideWithValue(_FakeWorkforceApi()),
              authControllerProvider.overrideWith(_LoggedInAuthController.new),
            ],
            child: MaterialApp(
              theme: factoryLightTheme(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ProviderDetailScreen(provider: twoServices, preselectedServiceId: serviceId),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      bool selected(String title) =>
          tester.widget<FactoryServiceCard>(find.widgetWithText(FactoryServiceCard, title)).selected;

      await open('service-2');
      expect(selected('Consultation'), isTrue);
      expect(selected('Checkup'), isFalse);

      await open('service-gone');
      expect(selected('Consultation'), isFalse);
      expect(selected('Checkup'), isFalse);
    });

    testWidgets('a time without a person is ignored', (tester) async {
      await pump(tester, null, slotId: 'slot-1', slots: [tenOClock]);

      expect(find.widgetWithText(FactoryTimeSlot, '10:00'), findsNothing);
    });

    testWidgets('a business that only offers "Any master" ignores it', (tester) async {
      await pump(tester, (kind: 'STAFF', id: 'staff-2'), allowChoice: false);

      expect(find.text('Dr. Bek'), findsNothing);
      expect(find.text('Any master'), findsNothing);
    });

    testWidgets('a person from another directory is ignored here', (tester) async {
      await pump(tester, (kind: 'MASTER', id: 'staff-2'));

      expect(selected(tester, 'Dr. Bek'), isFalse);
    });
  });

  testWidgets('opened from a "Book" button it starts at the booking steps, not at the top', (tester) async {
    // A short phone, so the page is longer than the screen and can scroll.
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
    Widget app({required bool startAtBooking}) => ProviderScope(
      overrides: [
        bookingApiProvider.overrideWithValue(_FakeBookingApi(const [])),
        beautyApiProvider.overrideWithValue(_FakeBeautyApi()),
        authControllerProvider.overrideWith(_LoggedInAuthController.new),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // A key per mode: the second pump must build a fresh screen, not update the first.
        home: ProviderDetailScreen(key: ValueKey(startAtBooking), provider: provider, startAtBooking: startAtBooking),
      ),
    );

    // Normally the page opens at the top: the services sit a long way down.
    await tester.pumpWidget(app(startAtBooking: false));
    await tester.pumpAndSettle();
    final normalTop = tester.getTopLeft(find.text('Services')).dy;

    // From the Book button the page has scrolled to the booking steps, so the
    // same section is much nearer the top of the screen.
    await tester.pumpWidget(app(startAtBooking: true));
    await tester.pumpAndSettle();
    final bookTop = tester.getTopLeft(find.text('Services')).dy;

    expect(bookTop, lessThan(normalTop - 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a message when there are no open slots', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
          beautyApiProvider.overrideWithValue(_FakeBeautyApi()),
          waitlistApiProvider.overrideWithValue(_FakeWaitlistApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderDetailScreen(provider: provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No open times'), findsOneWidget);
    // The one thing to do about it is on the spot: ask to be told when a time opens.
    expect(find.text('Notify me'), findsOneWidget);
  });

  testWidgets('a payment that is still pending sends the customer to pay instead of showing "confirmed"', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final slot = AvailabilitySlot(
      id: 'slot-1',
      providerId: 'provider-1',
      startsAt: DateTime(2026, 1, 1, 10, 0),
      endsAt: DateTime(2026, 1, 1, 10, 30),
      status: 'OPEN',
    );
    final fakeApi = _FakeBookingApi([slot])
      ..bookingFromGet = Booking(
        id: 'booking-1',
        userId: 'user-1',
        serviceId: 'service-1',
        availabilitySlotId: 'slot-1',
        status: 'PENDING_PAYMENT',
        totalPrice: 30,
        createdAt: DateTime.now(),
      );
    final fakePaymentsApi = _FakePaymentsApi()..chargeStatus = 'PENDING';
    final opened = <Uri>[];
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(fakeApi),
          paymentsApiProvider.overrideWithValue(fakePaymentsApi),
          beautyApiProvider.overrideWithValue(_FakeBeautyApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
          checkoutLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
        child: _routerApp(provider),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.widgetWithText(FactoryServiceCard, 'Haircut'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('10:00'));
    await tester.pumpAndSettle();
    await bookAndConfirm(tester, find.widgetWithText(FactoryButton, 'Book'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Booking confirmed!'), findsNothing);
    expect(find.text('Waiting for payment'), findsOneWidget);
    expect(opened, [Uri.parse('https://pay.example/checkout/payment-1')]);

    // The webhook confirms the booking: now (and only now) the confirmation appears.
    fakeApi.bookingFromGet = Booking(
      id: 'booking-1',
      userId: 'user-1',
      serviceId: 'service-1',
      availabilitySlotId: 'slot-1',
      status: 'CONFIRMED',
      totalPrice: 30,
      createdAt: DateTime.now(),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Booking confirmed!'), findsOneWidget);
  });

  testWidgets('a booking with nothing due online is confirmed right away, without starting a payment', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final slot = AvailabilitySlot(
      id: 'slot-1',
      providerId: 'provider-1',
      startsAt: DateTime(2026, 1, 1, 10, 0),
      endsAt: DateTime(2026, 1, 1, 10, 30),
      status: 'OPEN',
    );
    // The server confirms a booking with no advance payment on creation.
    final fakeApi = _FakeBookingApi([slot])
      ..bookingFromGet = Booking(
        id: 'booking-1',
        userId: 'user-1',
        serviceId: 'service-1',
        availabilitySlotId: 'slot-1',
        status: 'CONFIRMED',
        totalPrice: 30,
        depositAmount: 0,
        remainingAmount: 30,
        createdAt: DateTime.now(),
      );
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(fakeApi),
          paymentsApiProvider.overrideWithValue(fakePaymentsApi),
          beautyApiProvider.overrideWithValue(_FakeBeautyApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: _routerApp(provider),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.widgetWithText(FactoryServiceCard, 'Haircut'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('10:00'));
    await tester.pumpAndSettle();
    await bookAndConfirm(tester, find.widgetWithText(FactoryButton, 'Book'));
    await tester.pumpAndSettle();

    expect(fakePaymentsApi.lastChargedBookingId, isNull);
    expect(find.text('Waiting for payment'), findsNothing);
    expect(find.text('Booking confirmed!'), findsOneWidget);
  });

  group('the bar above "Book" says what to pick next', () {
    AvailabilitySlot slot() => AvailabilitySlot(
          id: 'slot-1',
          providerId: 'provider-1',
          startsAt: DateTime(2026, 1, 1, 10, 0),
          endsAt: DateTime(2026, 1, 1, 10, 30),
          status: 'OPEN',
        );

    Future<void> pump(WidgetTester tester, ProviderSearchResult provider, {List<Master> masters = const []}) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingApiProvider.overrideWithValue(_FakeBookingApi([slot()])),
            paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
            beautyApiProvider.overrideWithValue(_FakeBeautyApi(masters)),
            authControllerProvider.overrideWith(_LoggedInAuthController.new),
          ],
          child: _routerApp(provider),
        ),
      );
      await tester.pumpAndSettle();
    }

    String? hint(WidgetTester tester) {
      final finder = find.byKey(const Key('bookingNextStepHint'));
      return finder.evaluate().isEmpty ? null : tester.widget<Text>(finder).data;
    }

    ProviderSearchResult salon(List<ServiceSummary> services) => ProviderSearchResult(
          id: 'provider-1',
          name: 'Test Salon',
          vertical: 'beauty',
          status: 'ACTIVE',
          hasOpenAvailability: true,
          minPrice: 30,
          services: services,
        );

    const haircut = ServiceSummary(id: 'service-1', title: 'Haircut', durationMinutes: 30, price: 30, currency: 'USD');
    const colour = ServiceSummary(id: 'service-2', title: 'Colouring', durationMinutes: 60, price: 80, currency: 'USD');

    testWidgets('several services: service first, then time, then nothing once ready', (tester) async {
      await pump(tester, salon([haircut, colour]));

      expect(hint(tester), 'Choose a service');
      await tapVisible(tester, find.widgetWithText(FactoryServiceCard, 'Haircut'));
      await tester.pumpAndSettle();
      expect(hint(tester), 'Choose a time');
      await tapVisible(tester, find.text('10:00'));
      await tester.pumpAndSettle();
      expect(hint(tester), isNull);
      expect(tester.widget<FactoryButton>(find.widgetWithText(FactoryButton, 'Book')).onPressed, isNotNull);
    });

    testWidgets('one service is already picked, so the first thing asked is the time', (tester) async {
      await pump(tester, salon([haircut]));

      expect(hint(tester), 'Choose a time');
      expect(find.byType(BookingStepper), findsOneWidget);
    });

    testWidgets('with masters, the person is asked for before the time', (tester) async {
      await pump(
        tester,
        salon([haircut]),
        masters: const [
          Master(id: 'master-1', providerId: 'provider-1', displayName: 'Jamie Stylist', active: true),
        ],
      );

      expect(hint(tester), 'Choose a specialist');
      await tapVisible(tester, find.text('Jamie Stylist'));
      await tester.pumpAndSettle();
      expect(hint(tester), 'Choose a time');
    });
  });
}
