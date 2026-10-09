import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/booking.dart';
import '../providers/booking_providers.dart';
import 'booking_payment_screen.dart';

final _returnedBookingProvider = FutureProvider.autoDispose.family<Booking, String>(
  (ref, bookingId) => ref.watch(bookingApiProvider).getBooking(bookingId),
  // No silent retries: the customer is waiting, so a failure shows the error (with a Retry button) right away.
  retry: (retryCount, error) => null,
);

/// Where `zairo://app/payment-result?status=…&booking=…` lands — the link the
/// payment provider's return page opens once the customer has paid (or not).
/// It only loads the booking and hands over to [BookingPaymentScreen], which
/// asks the server where the payment stands: the link itself proves nothing.
class PaymentResultScreen extends ConsumerWidget {
  const PaymentResultScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final booking = ref.watch(_returnedBookingProvider(bookingId));
    return booking.when(
      data: (booking) => BookingPaymentScreen(args: BookingPaymentArgs(booking: booking, fromReturn: true)),
      loading: () => const Scaffold(body: FactoryLoadingState()),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: Text(l10n.paymentScreenTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FactoryErrorState(
                  message: l10n.paymentStartError,
                  onRetry: () => ref.invalidate(_returnedBookingProvider(bookingId)),
                ),
                FactoryButton(
                  label: l10n.paymentCloseButton,
                  variant: FactoryButtonVariant.text,
                  onPressed: () => context.go(AppRoutes.bookings),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
