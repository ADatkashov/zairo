import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/booking/data/booking_api.dart';
import 'package:zairo/features/booking/data/booking_exception.dart';
import 'package:zairo/features/booking/data/models/availability_slot.dart';
import 'package:zairo/features/booking/data/models/book_again_suggestion.dart';
import 'package:zairo/features/booking/data/models/booking.dart';
import 'package:zairo/features/booking/presentation/providers/booking_providers.dart';
import 'package:zairo/app/router/app_routes.dart';
import 'package:zairo/features/booking/presentation/screens/booking_payment_screen.dart';
import 'package:zairo/features/booking/presentation/screens/my_bookings_screen.dart';
import 'package:zairo/features/messaging/data/messaging_api.dart';
import 'package:zairo/features/messaging/data/messaging_exception.dart';
import 'package:zairo/features/messaging/data/models/chat_message.dart';
import 'package:zairo/features/messaging/presentation/screens/chat_thread_screen.dart';
import 'package:zairo/features/messaging/data/models/conversation.dart';
import 'package:zairo/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:zairo/features/payments/data/models/payment.dart';
import 'package:zairo/features/payments/data/payments_api.dart';
import 'package:zairo/features/payments/presentation/providers/payments_providers.dart';
import 'package:zairo/features/reviews/data/models/review.dart';
import 'package:zairo/features/reviews/data/reviews_api.dart';
import 'package:zairo/features/reviews/presentation/providers/reviews_providers.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeBookingApi extends BookingApi {
  _FakeBookingApi(this._bookings) : super(DioClient(Dio()));

  final List<Booking> _bookings;
  String? lastCancelledBookingId;
  Object? errorOnCancel;

  @override
  Future<List<Booking>> listMyBookings(String userId) async => _bookings;

  @override
  Future<List<AvailabilitySlot>> listAvailabilitySlots(String providerId) async => const [];

  @override
  Future<Booking> cancelBooking(String bookingId) async {
    if (errorOnCancel != null) throw errorOnCancel!;
    lastCancelledBookingId = bookingId;
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    final cancelled = Booking(
      id: _bookings[index].id,
      userId: _bookings[index].userId,
      serviceId: _bookings[index].serviceId,
      availabilitySlotId: _bookings[index].availabilitySlotId,
      status: 'CANCELLED',
      totalPrice: _bookings[index].totalPrice,
      createdAt: _bookings[index].createdAt,
    );
    _bookings[index] = cancelled;
    return cancelled;
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

class _FakeMessagingApi extends MessagingApi {
  _FakeMessagingApi({this.conversations = const [], this.sendError})
    : super(DioClient(Dio()));

  final List<Conversation> conversations;
  final Object? sendError;
  String? lastBookingId;
  String? lastBody;

  @override
  Future<List<Conversation>> myInbox() async => conversations;

  @override
  Future<ChatMessage> sendAboutBooking(String bookingId, String body) async {
    if (sendError != null) throw sendError!;
    lastBookingId = bookingId;
    lastBody = body;
    return ChatMessage(
      id: 'message-1',
      conversationId: 'conversation-1',
      senderUserId: 'user-1',
      body: body,
      bookingId: bookingId,
      createdAt: DateTime(2026, 1, 3),
    );
  }

  @override
  Future<List<ChatMessage>> threadWithProvider(String providerId) async =>
      const [];
}

class _LoggedInAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(id: 'user-1', email: 'a@example.com', displayName: 'A', role: 'CUSTOMER');
  }
}

class _LoggedOutAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async => null;
}

void main() {
  testWidgets('shows a login gate when logged out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(_FakeBookingApi(const [])),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          authControllerProvider.overrideWith(_LoggedOutAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MyBookingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log in to see your bookings'), findsOneWidget);
  });

  testWidgets('shows an empty state with no bookings', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(_FakeBookingApi(const [])),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MyBookingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No bookings yet'), findsOneWidget);
    expect(find.text('Find a service'), findsOneWidget);
  });

  testWidgets('lists bookings with status and price', (tester) async {
    final booking = Booking(
      id: 'booking-1',
      userId: 'user-1',
      serviceId: 'service-1',
      availabilitySlotId: 'slot-1',
      status: 'CONFIRMED',
      totalPrice: 42.5,
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(_FakeBookingApi([booking])),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MyBookingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('43 ₸'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    // No review section for a booking that isn't completed yet.
    expect(find.text('Leave a review'), findsNothing);
  });

  testWidgets('shows service, business and appointment time on every tab',
      (tester) async {
    Booking make(String id, String status, String title, String business,
            DateTime startsAt) =>
        Booking(
          id: id,
          userId: 'user-1',
          serviceId: 'service-$id',
          availabilitySlotId: 'slot-$id',
          status: status,
          totalPrice: 20,
          createdAt: DateTime(2026, 1, 1),
          serviceTitle: title,
          providerName: business,
          providerId: 'provider-1',
          providerVertical: 'beauty',
          // Local wall-clock time, sent as the UTC instant the API returns.
          startsAt: startsAt.toUtc(),
          endsAt: startsAt.add(const Duration(minutes: 30)).toUtc(),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(
            _FakeBookingApi([
              make('1', 'CONFIRMED', 'Haircut', 'Salon Aurora',
                  DateTime(2026, 10, 5, 14, 30)),
              make('2', 'COMPLETED', 'Manicure', 'Nail Bar',
                  DateTime(2026, 9, 1, 9, 5)),
              make('3', 'CANCELLED', 'Coloring', 'Studio K',
                  DateTime(2026, 8, 20, 18, 0)),
            ]),
          ),
          reviewsApiProvider.overrideWithValue(_FakeReviewsApi()),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MyBookingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('Salon Aurora'), findsOneWidget);
    expect(find.text('Appointment: Oct 5, 14:30'), findsOneWidget);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Manicure'), findsOneWidget);
    expect(find.text('Nail Bar'), findsOneWidget);
    expect(find.text('Appointment: Sep 1, 09:05'), findsOneWidget);

    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    expect(find.text('Coloring'), findsOneWidget);
    expect(find.text('Studio K'), findsOneWidget);
    expect(find.text('Appointment: Aug 20, 18:00'), findsOneWidget);
  });

  test('Booking.fromJson tolerates missing enrichment fields', () {
    final json = {
      'id': 'b',
      'userId': 'u',
      'serviceId': 's',
      'availabilitySlotId': 'sl',
      'status': 'CONFIRMED',
      'totalPrice': 10,
      'createdAt': '2026-01-01T00:00:00Z',
    };
    final plain = Booking.fromJson(json);
    expect(plain.serviceTitle, isNull);
    expect(plain.startsAt, isNull);

    final enriched = Booking.fromJson({
      ...json,
      'serviceTitle': 'Haircut',
      'providerId': 'p',
      'providerName': 'Salon',
      'providerVertical': 'beauty',
      'startsAt': '2026-10-05T09:30:00Z',
      'endsAt': '2026-10-05T10:00:00Z',
    });
    expect(enriched.serviceTitle, 'Haircut');
    expect(enriched.providerName, 'Salon');
    expect(enriched.startsAt, DateTime.utc(2026, 10, 5, 9, 30));
  });

  testWidgets('shows the review section only for completed bookings', (tester) async {
    final booking = Booking(
      id: 'booking-1',
      userId: 'user-1',
      serviceId: 'service-1',
      availabilitySlotId: 'slot-1',
      status: 'COMPLETED',
      totalPrice: 42.5,
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(_FakeBookingApi([booking])),
          reviewsApiProvider.overrideWithValue(_FakeReviewsApi()),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MyBookingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(find.text('Leave a review'), findsOneWidget);
  });

  testWidgets('cancel button only shows for confirmed bookings', (tester) async {
    final confirmed = Booking(
      id: 'booking-confirmed',
      userId: 'user-1',
      serviceId: 'service-1',
      availabilitySlotId: 'slot-1',
      status: 'CONFIRMED',
      totalPrice: 20,
      createdAt: DateTime(2026, 1, 1),
    );
    final completed = Booking(
      id: 'booking-completed',
      userId: 'user-1',
      serviceId: 'service-1',
      availabilitySlotId: 'slot-2',
      status: 'COMPLETED',
      totalPrice: 20,
      createdAt: DateTime(2026, 1, 2),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(_FakeBookingApi([confirmed, completed])),
          reviewsApiProvider.overrideWithValue(_FakeReviewsApi()),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MyBookingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cancel booking'), findsOneWidget);
  });

  testWidgets('a booking awaiting payment is listed with a Pay now button that opens the payment screen', (
    tester,
  ) async {
    final unpaid = Booking(
      id: 'booking-unpaid',
      userId: 'user-1',
      serviceId: 'service-1',
      availabilitySlotId: 'slot-1',
      status: 'PENDING_PAYMENT',
      totalPrice: 20,
      createdAt: DateTime(2026, 1, 1),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const MyBookingsScreen()),
        GoRoute(
          path: AppRoutes.bookingPayment,
          builder: (_, state) => Text('PAYMENT SCREEN for ${(state.extra! as BookingPaymentArgs).booking.id}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(_FakeBookingApi([unpaid])),
          reviewsApiProvider.overrideWithValue(_FakeReviewsApi()),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp.router(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Awaiting payment'), findsOneWidget);
    // It can still be cancelled.
    expect(find.text('Cancel booking'), findsOneWidget);

    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();
    expect(find.text('PAYMENT SCREEN for booking-unpaid'), findsOneWidget);
  });

  testWidgets('cancelling asks for confirmation, then calls the API and shows a snackbar', (tester) async {
    final booking = Booking(
      id: 'booking-1',
      userId: 'user-1',
      serviceId: 'service-1',
      availabilitySlotId: 'slot-1',
      status: 'CONFIRMED',
      totalPrice: 20,
      createdAt: DateTime(2026, 1, 1),
    );
    final fakeApi = _FakeBookingApi([booking]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(fakeApi),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MyBookingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();

    // Confirmation dialog — dismissing with "Keep booking" doesn't call the API.
    expect(find.text('Cancel this booking?'), findsOneWidget);
    await tester.tap(find.text('Keep booking'));
    await tester.pumpAndSettle();
    expect(fakeApi.lastCancelledBookingId, isNull);

    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel booking'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastCancelledBookingId, 'booking-1');
    expect(find.text('Booking cancelled.'), findsOneWidget);

    // The booking left the Upcoming tab now that it's CANCELLED — it only
    // shows up under the Cancelled tab.
    await tester.tap(find.text('Cancelled').first);
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'), findsWidgets);
  });

  testWidgets('shows a readable error when cancellation fails', (tester) async {
    final booking = Booking(
      id: 'booking-1',
      userId: 'user-1',
      serviceId: 'service-1',
      availabilitySlotId: 'slot-1',
      status: 'CONFIRMED',
      totalPrice: 20,
      createdAt: DateTime(2026, 1, 1),
    );
    final fakeApi = _FakeBookingApi([booking])
      ..errorOnCancel = const BookingException(BookingErrorKey.notCancellable);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(fakeApi),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MyBookingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel booking'));
    await tester.pumpAndSettle();

    expect(find.text('This booking can no longer be cancelled.'), findsOneWidget);
    // Still shows the Cancel button — the booking stayed CONFIRMED.
    expect(find.text('Cancel booking'), findsOneWidget);
  });

  testWidgets('message about this booking sends it and opens the matching chat thread', (
    tester,
  ) async {
    final booking = Booking(
      id: 'booking-1',
      userId: 'user-1',
      serviceId: 'service-1',
      availabilitySlotId: 'slot-1',
      status: 'CONFIRMED',
      totalPrice: 20,
      createdAt: DateTime(2026, 1, 1),
    );
    final conversation = Conversation(
      id: 'conversation-1',
      customerId: 'user-1',
      providerId: 'provider-1',
      providerName: 'Glow Salon',
      createdAt: DateTime(2026, 1, 1),
      lastMessageAt: DateTime(2026, 1, 3),
    );
    final fakeMessagingApi = _FakeMessagingApi(conversations: [conversation]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(_FakeBookingApi([booking])),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          messagingApiProvider.overrideWithValue(fakeMessagingApi),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp.router(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const MyBookingsScreen(),
              ),
              GoRoute(
                path: '/messages/:providerId',
                builder: (_, state) => ChatThreadScreen(
                  providerId: state.pathParameters['providerId']!,
                  providerName: state.uri.queryParameters['name']!,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Message about this booking'));
    await tester.pumpAndSettle();

    expect(find.text('Message the business'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField),
      'When can I reschedule?',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();

    expect(fakeMessagingApi.lastBookingId, 'booking-1');
    expect(fakeMessagingApi.lastBody, 'When can I reschedule?');
    // Navigated straight into the matched conversation's thread rather
    // than staying on MyBookingsScreen with a plain snackbar.
    expect(find.text('Glow Salon'), findsOneWidget);
  });

  testWidgets('shows a readable error when messaging about a booking fails', (
    tester,
  ) async {
    final booking = Booking(
      id: 'booking-1',
      userId: 'user-1',
      serviceId: 'service-1',
      availabilitySlotId: 'slot-1',
      status: 'CONFIRMED',
      totalPrice: 20,
      createdAt: DateTime(2026, 1, 1),
    );
    final fakeMessagingApi = _FakeMessagingApi(
      sendError: const MessagingException(MessagingErrorKey.notYourBooking),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(_FakeBookingApi([booking])),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          messagingApiProvider.overrideWithValue(fakeMessagingApi),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MyBookingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Message about this booking'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Hello?');
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();

    // The dialog stays open with an inline error rather than closing.
    expect(find.text("This isn't your booking."), findsOneWidget);
    expect(find.text('Message the business'), findsOneWidget);
  });

  testWidgets('a completed booking offers "Book again" when a suggestion matches its service', (
    tester,
  ) async {
    final booking = Booking(
      id: 'booking-1',
      userId: 'user-1',
      serviceId: 'service-1',
      availabilitySlotId: 'slot-1',
      status: 'COMPLETED',
      totalPrice: 25,
      createdAt: DateTime(2026, 1, 1),
    );
    final suggestion = BookAgainSuggestion(
      providerId: 'provider-9',
      providerName: 'Glow Salon',
      vertical: 'beauty',
      serviceId: 'service-1',
      serviceTitle: 'Haircut',
      durationMinutes: 30,
      price: 25,
      currency: 'USD',
      lastVisitAt: DateTime(2026, 1, 1),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const MyBookingsScreen()),
        GoRoute(
          path: '/provider/:id',
          builder: (_, state) => Scaffold(body: Text('provider ${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingApiProvider.overrideWithValue(_FakeBookingApi([booking])),
          reviewsApiProvider.overrideWithValue(_FakeReviewsApi()),
          paymentsApiProvider.overrideWithValue(_FakePaymentsApi()),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
          bookAgainSuggestionsProvider('user-1').overrideWith((ref) async => [suggestion]),
        ],
        child: MaterialApp.router(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Book again'));
    await tester.pumpAndSettle();

    expect(find.text('provider provider-9'), findsOneWidget);
  });
}
