import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:zairo/features/booking/presentation/screens/provider_detail_screen.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/features/discovery/data/models/service_summary.dart';
import 'package:zairo/features/payments/data/models/payment.dart';
import 'package:zairo/features/payments/data/payments_api.dart';
import 'package:zairo/features/payments/presentation/providers/payments_providers.dart';
import 'package:zairo/features/staff/data/models/staff.dart';
import 'package:zairo/features/staff/data/staff_api.dart';
import 'package:zairo/features/staff/presentation/providers/staff_providers.dart';
import 'package:zairo/l10n/app_localizations.dart';

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
      status: 'CONFIRMED',
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
      status: 'CONFIRMED',
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
      status: 'CONFIRMED',
      totalPrice: totalPrice,
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

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(fakeApi),
          paymentsApiProvider.overrideWithValue(fakePaymentsApi),
          beautyApiProvider.overrideWithValue(_FakeBeautyApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          navigatorKey: navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SizedBox()),
        ),
      ),
    );
    navigatorKey.currentState!
        .push(MaterialPageRoute(builder: (_) => const ProviderDetailScreen(provider: provider)));
    await tester.pumpAndSettle();

    expect(find.text('4.2'), findsOneWidget);
    expect(find.text('(55)'), findsOneWidget);

    final bookButtonFinder = find.widgetWithText(FactoryButton, 'Book');
    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNull);

    await tester.tap(find.text('Haircut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10:00'));
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
    final fakeBookingApi = _FakeBookingApi([slot]);
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

    expect(find.text('Jamie Stylist'), findsOneWidget);

    final bookButtonFinder = find.widgetWithText(FactoryButton, 'Book');
    await tester.tap(find.text('Haircut'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('10:00'), 200);
    await tester.tap(find.text('10:00'));
    await tester.pumpAndSettle();

    // Service + slot picked, but no master yet -> still disabled.
    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNull);

    await tester.tap(find.text('Jamie Stylist'));
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
  },
  skip: true,
  );

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

    expect(find.text('Yerlan Mechanic'), findsOneWidget);
    expect(find.text('Toyota Camry (2019)'), findsOneWidget);

    final bookButtonFinder = find.widgetWithText(FactoryButton, 'Book');
    await tester.tap(find.text('Yerlan Mechanic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toyota Camry (2019)'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Oil Change'), 200);
    await tester.tap(find.text('Oil Change'));
    await tester.pumpAndSettle();

    // Mechanic + vehicle + service picked, but no slot yet -> still disabled.
    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNull);

    await tester.scrollUntilVisible(find.text('10:00'), 200);
    await tester.tap(find.text('10:00'));
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
  },
  skip: true,
  );

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
    await tester.tap(find.text('Checkup'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('10:00'), 200);
    await tester.tap(find.text('10:00'));
    await tester.pumpAndSettle();

    // Service + slot picked, but no staff member yet -> still disabled.
    expect(tester.widget<FactoryButton>(bookButtonFinder).onPressed, isNull);

    await tester.tap(find.text('Dr. Aliya'));
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
}
