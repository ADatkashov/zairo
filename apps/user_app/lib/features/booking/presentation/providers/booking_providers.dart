import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/booking_api.dart';
import '../../data/models/availability_slot.dart';
import '../../data/models/book_again_suggestion.dart';
import '../../data/models/booking.dart';
import '../../data/models/payment_plan.dart';
import '../../data/models/reschedule_option.dart';

final bookingApiProvider = Provider<BookingApi>((ref) {
  return BookingApi(ref.watch(dioClientProvider));
});

final availabilitySlotsProvider = FutureProvider.autoDispose
    .family<List<AvailabilitySlot>, String>((ref, providerId) {
  return ref.watch(bookingApiProvider).listAvailabilitySlots(providerId);
});

final myBookingsProvider = FutureProvider.autoDispose.family<List<Booking>, String>((ref, userId) {
  return ref.watch(bookingApiProvider).listMyBookings(userId);
});

final bookAgainSuggestionsProvider =
    FutureProvider.autoDispose.family<List<BookAgainSuggestion>, String>((ref, userId) {
  return ref.watch(bookingApiProvider).listBookAgainSuggestions(userId);
});

final depositPolicyProvider = FutureProvider.autoDispose.family<DepositPolicy?, String>((ref, providerId) {
  return ref.watch(bookingApiProvider).getDepositPolicy(providerId);
});

/// The times a booking can be moved to; read when the customer opens the reschedule sheet.
final rescheduleOptionsProvider = FutureProvider.autoDispose.family<List<RescheduleOption>, String>((ref, bookingId) {
  return ref.watch(bookingApiProvider).rescheduleOptions(bookingId);
});
