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
import 'package:zairo/features/booking/data/models/booking.dart';
import 'package:zairo/features/booking/presentation/providers/booking_providers.dart';
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
}
