import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../payments/presentation/widgets/payment_status_chip.dart';
import '../../../reviews/presentation/widgets/review_section.dart';
import '../../data/models/booking.dart';
import '../providers/booking_providers.dart';

class MyBookingsScreen extends ConsumerWidget {
  final String userId;

  const MyBookingsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.factoryColors;
    final bookingsAsync = ref.watch(myBookingsProvider(userId));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('My bookings')),
      body: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return const Center(
              child: FactoryEmptyState(
                icon: Icons.event_note_outlined,
                title: 'No bookings yet',
                message: 'Once you book a service, it will show up here.',
              ),
            );
          }
          final sorted = [...bookings]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ListView.separated(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space3),
            itemBuilder: (context, index) => _BookingCard(booking: sorted[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: "Couldn't load your bookings.",
              onRetry: () => ref.invalidate(myBookingsProvider(userId)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;

  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FactoryPriceText(amount: booking.totalPrice, fontSize: 16, weight: FontWeight.w700),
                FactoryBadge(label: _statusLabel(booking.status), variant: _statusVariant(booking.status)),
              ],
            ),
            const SizedBox(height: FactorySpacing.space1),
            Text(
              'Booked on ${_formatDate(booking.createdAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            ),
            const SizedBox(height: FactorySpacing.space2),
            PaymentStatusChip(bookingId: booking.id),
            if (booking.status == 'COMPLETED') ReviewSection(bookingId: booking.id),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String status) => status.isEmpty ? status : '${status[0]}${status.substring(1).toLowerCase()}';

FactoryBadgeVariant _statusVariant(String status) => switch (status) {
      'CONFIRMED' => FactoryBadgeVariant.available,
      'COMPLETED' => FactoryBadgeVariant.verified,
      'CANCELLED' => FactoryBadgeVariant.error,
      _ => FactoryBadgeVariant.neutral,
    };

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime dt) {
  final month = _months[dt.month - 1];
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$month ${dt.day}, $hour:$minute';
}
