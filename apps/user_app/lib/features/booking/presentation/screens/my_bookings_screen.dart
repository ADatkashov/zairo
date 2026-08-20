import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../reviews/presentation/widgets/review_section.dart';
import '../../data/models/booking.dart';
import '../providers/booking_providers.dart';

class MyBookingsScreen extends ConsumerWidget {
  final String userId;

  const MyBookingsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(myBookingsProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return const Center(child: Text('No bookings yet.'));
          }
          final sorted = [...bookings]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, index) => _BookingCard(booking: sorted[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Failed to load bookings: $error')),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;

  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('\$${booking.totalPrice.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium),
                Chip(
                  label: Text(booking.status),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Booked on ${booking.createdAt.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (booking.status == 'COMPLETED') ReviewSection(bookingId: booking.id),
          ],
        ),
      ),
    );
  }
}
