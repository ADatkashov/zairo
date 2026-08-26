import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/logged_out_gate.dart';
import '../../../payments/presentation/providers/payments_providers.dart';
import '../../../payments/presentation/widgets/payment_status_chip.dart';
import '../../../reviews/presentation/widgets/review_section.dart';
import '../../data/booking_exception.dart';
import '../../data/models/booking.dart';
import '../providers/booking_providers.dart';

/// Reached directly from the bottom nav (a peer tab to Home/Search/
/// Favorites/Profile, not only pushed after already being logged in), so
/// it resolves the current user itself instead of requiring a caller to
/// pass one — see LoggedOutGate for the logged-out path.
class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.myBookingsTitle),
      body: authState.when(
        data: (user) => user == null
            ? LoggedOutGate(icon: Icons.event_note_outlined, message: l10n.bookingsLoggedOutPrompt)
            : _BookingsList(userId: user.id),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorProfileGeneric(error.toString()),
              onRetry: () => ref.invalidate(authControllerProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingsList extends ConsumerWidget {
  final String userId;

  const _BookingsList({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final bookingsAsync = ref.watch(myBookingsProvider(userId));

    return bookingsAsync.when(
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
          itemBuilder: (context, index) => _BookingCard(booking: sorted[index], userId: userId),
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
    );
  }
}

class _BookingCard extends ConsumerStatefulWidget {
  final Booking booking;
  final String userId;

  const _BookingCard({required this.booking, required this.userId});

  @override
  ConsumerState<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<_BookingCard> {
  bool _isCancelling = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final booking = widget.booking;

    return FactoryCard(
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
          if (booking.status == 'CONFIRMED') ...[
            const SizedBox(height: FactorySpacing.space2),
            Align(
              alignment: Alignment.centerLeft,
              child: FactoryButton(
                label: l10n.cancelBookingButton,
                variant: FactoryButtonVariant.textDanger,
                isLoading: _isCancelling,
                onPressed: _isCancelling ? null : _confirmAndCancel,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmAndCancel() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showFactoryDialog<bool>(
      context: context,
      title: l10n.cancelBookingConfirmTitle,
      message: l10n.cancelBookingConfirmMessage,
      actions: [
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.cancelBookingKeepButton,
            variant: FactoryButtonVariant.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.cancelBookingConfirmButton,
            variant: FactoryButtonVariant.danger,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ],
    );
    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      await ref.read(bookingApiProvider).cancelBooking(widget.booking.id);
      ref.invalidate(myBookingsProvider(widget.userId));
      ref.invalidate(paymentForBookingProvider(widget.booking.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.bookingCancelledMessage)));
    } on BookingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
      setState(() => _isCancelling = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorBookingGeneric(e.toString()))));
      setState(() => _isCancelling = false);
    }
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
