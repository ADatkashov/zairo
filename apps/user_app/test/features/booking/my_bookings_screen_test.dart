import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/booking/data/booking_api.dart';
import 'package:zairo/features/booking/data/models/availability_slot.dart';
import 'package:zairo/features/booking/data/models/booking.dart';
import 'package:zairo/features/booking/presentation/providers/booking_providers.dart';
import 'package:zairo/features/booking/presentation/screens/my_bookings_screen.dart';
import 'package:zairo/features/reviews/data/models/review.dart';
import 'package:zairo/features/reviews/data/reviews_api.dart';
import 'package:zairo/features/reviews/presentation/providers/reviews_providers.dart';

class _FakeBookingApi extends BookingApi {
  _FakeBookingApi(this._bookings) : super(DioClient(Dio()));

  final List<Booking> _bookings;

  @override
  Future<List<Booking>> listMyBookings(String userId) async => _bookings;

  @override
  Future<List<AvailabilitySlot>> listAvailabilitySlots(String providerId) async => const [];
}

class _FakeReviewsApi extends ReviewsApi {
  _FakeReviewsApi() : super(DioClient(Dio()));

  @override
  Future<Review?> getReview(String bookingId) async => null;
}

void main() {
  testWidgets('shows an empty state with no bookings', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bookingApiProvider.overrideWithValue(_FakeBookingApi(const []))],
        child: const MaterialApp(home: MyBookingsScreen(userId: 'user-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No bookings yet.'), findsOneWidget);
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
        overrides: [bookingApiProvider.overrideWithValue(_FakeBookingApi([booking]))],
        child: const MaterialApp(home: MyBookingsScreen(userId: 'user-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('\$42.50'), findsOneWidget);
    expect(find.text('CONFIRMED'), findsOneWidget);
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
        ],
        child: const MaterialApp(home: MyBookingsScreen(userId: 'user-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leave a review'), findsOneWidget);
  });
}
