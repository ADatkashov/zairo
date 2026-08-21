import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../payments/presentation/widgets/payment_status_chip.dart';
import '../../../reviews/presentation/widgets/review_section.dart';
import '../../data/models/booking.dart';
import '../providers/booking_providers.dart';

class MyBookingsScreen extends ConsumerWidget {
  final String userId;

  const MyBookingsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final bookingsAsync = ref.watch(myBookingsProvider(userId));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: Text(l10n.myBookingsTitle)),
      body: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: FactoryEmptyState(
                icon: Icons.event_note_outlined,
                title: l10n.bookingsEmptyTitle,
                message: l10n.bookingsEmptyMessage,
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
              message: l10n.errorBookingsLoadFailed,
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
    final l10n = AppLocalizations.of(context)!;
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
                FactoryBadge(label: _statusLabel(l10n, booking.status), variant: _statusVariant(booking.status)),
              ],
            ),
            const SizedBox(height: FactorySpacing.space1),
            Text(
              l10n.bookedOnLabel(formatMonthDayTime(l10n, booking.createdAt.toLocal())),
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

String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
      'CONFIRMED' => l10n.bookingStatusConfirmed,
      'COMPLETED' => l10n.bookingStatusCompleted,
      'CANCELLED' => l10n.bookingStatusCancelled,
      _ => status.isEmpty ? status : '${status[0]}${status.substring(1).toLowerCase()}',
    };

FactoryBadgeVariant _statusVariant(String status) => switch (status) {
      'CONFIRMED' => FactoryBadgeVariant.available,
      'COMPLETED' => FactoryBadgeVariant.verified,
      'CANCELLED' => FactoryBadgeVariant.error,
      _ => FactoryBadgeVariant.neutral,
    };
