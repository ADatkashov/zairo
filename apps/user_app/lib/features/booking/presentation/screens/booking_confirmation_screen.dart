import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/formatting/month_day_time.dart';
import '../../../../core/links/external_links.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../discovery/data/models/service_summary.dart';
import '../../../payments/presentation/widgets/payment_status_chip.dart';
import '../../data/models/booking.dart';
import '../providers/booking_providers.dart';
import '../widgets/booking_payment_summary.dart';

/// Board 19 (v2 design audit) — the booking flow previously ended with a
/// snackbar and a `pop()` back to Search/Home, which meant "was this
/// actually booked?" only ever got answered for a second. This screen
/// replaces the provider-detail route so there is a durable, shareable
/// confirmation with the details a customer would screenshot.
/// What the confirmation route (`AppRoutes.bookingConfirmation`) needs, handed
/// over as the route's `extra`.
class BookingConfirmationArgs {
  const BookingConfirmationArgs({
    required this.booking,
    required this.providerId,
    required this.providerName,
    required this.providerVertical,
    required this.service,
    required this.slotStartsAt,
    this.latitude,
    this.longitude,
  });

  final Booking booking;
  final String providerId;
  final String providerName;
  final String providerVertical;
  final ServiceSummary service;
  final DateTime? slotStartsAt;
  final double? latitude;
  final double? longitude;
}

class BookingConfirmationScreen extends StatelessWidget {
  final Booking booking;
  final String providerId;
  final String providerName;
  final String providerVertical;
  final ServiceSummary service;
  final DateTime? slotStartsAt;

  /// Where the business is, when known — enables the "Directions" action.
  final double? latitude;
  final double? longitude;

  const BookingConfirmationScreen({
    super.key,
    required this.booking,
    required this.providerId,
    required this.providerName,
    required this.providerVertical,
    required this.service,
    required this.slotStartsAt,
    this.latitude,
    this.longitude,
  });

  BookingConfirmationScreen.fromArgs(BookingConfirmationArgs args, {Key? key})
    : this(
        key: key,
        booking: args.booking,
        providerId: args.providerId,
        providerName: args.providerName,
        providerVertical: args.providerVertical,
        service: args.service,
        slotStartsAt: args.slotStartsAt,
        latitude: args.latitude,
        longitude: args.longitude,
      );

  void _addToCalendar(BuildContext context) {
    final startsAt = slotStartsAt;
    if (startsAt == null) return;
    final l10n = AppLocalizations.of(context)!;
    launchUrl(
      ExternalLinks.addToCalendar(
        title: l10n.bookingCalendarEventTitle(service.title, providerName),
        startsAt: startsAt,
        duration: Duration(minutes: service.durationMinutes),
        details: providerName,
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  void _openDirections() {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return;
    launchUrl(
      ExternalLinks.directionsTo(latitude: lat, longitude: lng),
      mode: LaunchMode.externalApplication,
    );
  }

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
                        // Soft success glow around the check.
                        boxShadow: [
                          BoxShadow(
                            color: colors.success.withValues(alpha: 0.22),
                            blurRadius: 36,
                            spreadRadius: 4,
                          ),
                        ],
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
                  Wrap(
                    spacing: FactorySpacing.space2,
                    runSpacing: FactorySpacing.space2,
                    children: [
                      if (slotStartsAt != null)
                        FactoryButton(
                          variant: FactoryButtonVariant.secondary,
                          icon: Symbols.event_available_rounded,
                          label: l10n.bookingConfirmationAddToCalendar,
                          onPressed: () => _addToCalendar(context),
                        ),
                      if (latitude != null && longitude != null)
                        FactoryButton(
                          variant: FactoryButtonVariant.secondary,
                          icon: Symbols.directions_rounded,
                          label: l10n.bookingConfirmationDirections,
                          onPressed: _openDirections,
                        ),
                    ],
                  ),
                  const SizedBox(height: FactorySpacing.space2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FactoryButton(
                      variant: FactoryButtonVariant.secondary,
                      icon: Symbols.workspace_premium_rounded,
                      label: l10n.loyaltyEntryTileTitle,
                      onPressed: () => context.push(
                        AppRoutes.loyalty(
                          providerId,
                          providerName: providerName,
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
