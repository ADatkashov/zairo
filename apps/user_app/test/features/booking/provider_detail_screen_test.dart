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
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/data/models/service_summary.dart';
import 'package:zairo/features/payments/data/models/payment.dart';
import 'package:zairo/features/payments/data/payments_api.dart';
import 'package:zairo/features/payments/presentation/providers/payments_providers.dart';
import 'package:zairo/features/staff/data/models/staff.dart';
import 'package:zairo/features/staff/data/staff_api.dart';
import 'package:zairo/features/staff/presentation/providers/staff_providers.dart';
import 'package:zairo/features/workforce/data/models/any_slot.dart';
import 'package:zairo/features/workforce/data/workforce_api.dart';
import 'package:zairo/features/workforce/presentation/providers/workforce_providers.dart';
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

class _FakePaymentsApi extends PaymentsApi {
  _FakePaymentsApi() : super(DioClient(Dio()));

  String? lastChargedBookingId;

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
    await tester.scrollUntilVisible(finder, 200);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

/// The detail screen at `/`, plus the confirmation route it replaces itself
/// with after a booking (the real router declares both as root routes).
Widget _routerApp(ProviderSearchResult provider) => MaterialApp.router(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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

void main() {
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

    final bookButtonFinder = find.widgetWithText(FactoryButton, 'Book');
    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNull);

    await tapVisible(tester, find.text('Haircut'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('10:00'));
    await tester.pumpAndSettle();

    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNotNull);

    await tester.tap(bookButtonFinder);
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
    await tapVisible(tester, find.text('Haircut'));
    await tester.pumpAndSettle();

    // No times are shown until a person (or "Any master") is chosen -> still disabled.
    expect(find.text('10:00'), findsNothing);
    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNull);

    await tapVisible(tester, find.text('Jamie Stylist'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('10:00'));
    await tester.pumpAndSettle();

    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNotNull);

    await tester.tap(bookButtonFinder);
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

    await tapVisible(tester, find.text('Oil Change'));
    await tester.pumpAndSettle();

    // Mechanic + vehicle + service picked, but no slot yet -> still disabled.
    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNull);

    await tapVisible(tester, find.text('10:00'));
    await tester.pumpAndSettle();

    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNotNull);

    await tester.tap(bookButtonFinder);
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
    await tapVisible(tester, find.text('Checkup'));
    await tester.pumpAndSettle();

    // No times are shown until a person is chosen -> still disabled.
    expect(find.text('10:00'), findsNothing);
    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNull);

    await tapVisible(tester, find.text('Dr. Aliya'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('10:00'));
    await tester.pumpAndSettle();

    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNotNull);

    await tester.tap(bookButtonFinder);
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

    await tapVisible(tester, find.text('Checkup'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('10:00'));
    await tester.pumpAndSettle();

    // No person was named, yet booking is enabled.
    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNotNull);
    await tester.tap(bookButtonFinder);
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

    await tapVisible(tester, find.text('Checkup'));
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

    await tapVisible(tester, find.text('Haircut'));
    await tester.pumpAndSettle();
    expect(find.textContaining('45'), findsNothing);

    await tapVisible(tester, find.text('Jamie Stylist'));
    await tester.pumpAndSettle();
    expect(find.textContaining('45'), findsWidgets);
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
          beautyApiProvider.overrideWithValue(_FakeBeautyApi()),
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
    await tapVisible(tester, find.text('Haircut'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('10:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FactoryButton, 'Book'));
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
    await tapVisible(tester, find.text('Haircut'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('10:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FactoryButton, 'Book'));
    await tester.pumpAndSettle();

    expect(fakePaymentsApi.lastChargedBookingId, isNull);
    expect(find.text('Waiting for payment'), findsNothing);
    expect(find.text('Booking confirmed!'), findsOneWidget);
  });
}
