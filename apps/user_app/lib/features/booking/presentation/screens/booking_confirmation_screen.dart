import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../discovery/data/models/service_summary.dart';
import '../../../loyalty/presentation/screens/business_loyalty_screen.dart';
import '../../../payments/presentation/widgets/payment_status_chip.dart';
import '../../data/models/booking.dart';
import '../providers/booking_providers.dart';
import '../widgets/booking_payment_summary.dart';

/// Board 19 (v2 design audit) — the booking flow previously ended with a
/// snackbar and a `pop()` back to Search/Home, which meant "was this
/// actually booked?" only ever got answered for a second. This screen
/// replaces the provider-detail route so there is a durable, shareable
/// confirmation with the details a customer would screenshot.
class BookingConfirmationScreen extends StatelessWidget {
  final Booking booking;
  final String providerId;
  final String providerName;
  final String providerVertical;
  final ServiceSummary service;
  final DateTime? slotStartsAt;

  const BookingConfirmationScreen({
    super.key,
    required this.booking,
    required this.providerId,
    required this.providerName,
    required this.providerVertical,
    required this.service,
    required this.slotStartsAt,
  });

  /// Leaves the confirmation for a *tab* ([location] is `/bookings` or `/`).
  /// The confirmation sits on top of whichever tab started the booking, so it
  /// is first popped off that tab's stack (otherwise it would still be there
  /// when the user came back to the tab), then the shell switches branch —
  /// which keeps the bottom nav in sync, unlike pushing a second copy of the
  /// bookings screen.
  void _leaveTo(BuildContext context, String location) {
    final router = GoRouter.of(context);
    // The Bookings tab stays alive in the shell's IndexedStack, so its
    // autoDispose list would otherwise not include the booking just made.
    ProviderScope.containerOf(context, listen: false)
        .invalidate(myBookingsProvider(booking.userId));
    Navigator.of(context).popUntil((route) => route.isFirst);
    router.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                children: [
                  const SizedBox(height: FactorySpacing.space6),
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Symbols.check_circle_rounded,
                        size: 48,
                        color: colors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: FactorySpacing.space4),
                  Text(
                    l10n.bookingConfirmationTitle,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                  const SizedBox(height: FactorySpacing.space1),
                  Text(
                    l10n.bookingConfirmationSubtitle(providerName),
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: FactorySpacing.space6),
                  FactoryCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ConfirmationRow(
                          icon: switch (providerVertical) {
                            'auto' => Symbols.directions_car_filled_rounded,
                            'cleaning' => Symbols.cleaning_services_rounded,
                            _ => Symbols.content_cut_rounded,
                          },
                          label: providerName,
                          value: service.title,
                        ),
                        const Divider(height: FactorySpacing.space6),
                        _ConfirmationRow(
                          icon: Symbols.event_rounded,
                          label: l10n.bookingConfirmationWhenLabel,
                          value: slotStartsAt == null
                              ? '—'
                              : formatMonthDayTime(l10n, slotStartsAt!.toLocal()),
                        ),
                        const Divider(height: FactorySpacing.space6),
                        BookingAmounts(booking: booking),
                        const SizedBox(height: FactorySpacing.space2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: PaymentStatusChip(bookingId: booking.id),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FactorySpacing.space4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FactoryButton(
                      variant: FactoryButtonVariant.secondary,
                      icon: Symbols.workspace_premium_rounded,
                      label: l10n.loyaltyEntryTileTitle,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BusinessLoyaltyScreen(
                            providerId: providerId,
                            providerName: providerName,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(FactorySpacing.space4),
              child: Column(
                children: [
                  FactoryButton(
                    label: l10n.bookingConfirmationViewBookingsButton,
                    variant: FactoryButtonVariant.primary,
                    expand: true,
                    onPressed: () => _leaveTo(context, '/bookings'),
                  ),
                  const SizedBox(height: FactorySpacing.space2),
                  FactoryButton(
                    label: l10n.bookingConfirmationBackHomeButton,
                    variant: FactoryButtonVariant.text,
                    expand: true,
                    onPressed: () => _leaveTo(context, '/'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ConfirmationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.textSecondary),
        const SizedBox(width: FactorySpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                value,
                style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
