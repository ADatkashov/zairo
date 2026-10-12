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
import '../../../catalog/presentation/category_icon.dart';
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

  /// The same confirmation for a fresher copy of the booking — the payment
  /// screen swaps in the server's CONFIRMED booking before showing this.
  BookingConfirmationArgs withBooking(Booking booking) => BookingConfirmationArgs(
    booking: booking,
    providerId: providerId,
    providerName: providerName,
    providerVertical: providerVertical,
    service: service,
    slotStartsAt: slotStartsAt,
    latitude: latitude,
    longitude: longitude,
  );
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
                  const Center(child: _SuccessMark()),
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
                          // The same category colours as the Home tiles, so the
                          // booking reads as belonging to its category.
                          color: colorForCategory(context, providerVertical)?.color,
                          tint: colorForCategory(context, providerVertical)?.tint,
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

  /// Icon plate colours; null falls back to the neutral brand tint.
  final Color? color;
  final Color? tint;

  const _ConfirmationRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tint ?? colors.primaryTint,
            borderRadius: FactoryRadius.mdRadius,
          ),
          child: Icon(icon, size: 22, color: color ?? colors.primary),
        ),
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

/// The success mark: a solid check on a soft halo, with a few small coloured
/// sparks around it — the category palette plus the brass accent — so a
/// confirmed booking feels like an event, not a form being submitted. Static
/// apart from one short scale-in, which is skipped when the system asks to
/// reduce motion. Decorative only: the title below carries the meaning.
class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  static const double _box = 136;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    // (dx, dy) from the box centre, diameter, colour.
    final sparks = <(double, double, double, Color)>[
      (-52, -40, 10, colors.coral),
      (50, -46, 8, colors.lavender),
      (-60, 6, 7, colors.accent),
      (58, 4, 12, colors.mint),
      (-38, 50, 9, colors.lavender),
      (40, 52, 7, colors.coral),
      (0, -62, 6, colors.accent),
      (-20, 60, 5, colors.mint),
    ];
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1),
        duration: FactoryMotion.resolve(context, FactoryMotion.slow),
        curve: FactoryMotion.standard,
        builder: (context, scale, child) => Opacity(
          opacity: ((scale - 0.6) / 0.4).clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        ),
        child: SizedBox(
          width: _box,
          height: _box,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final (dx, dy, d, c) in sparks)
                Positioned(
                  left: _box / 2 + dx - d / 2,
                  top: _box / 2 + dy - d / 2,
                  child: Container(
                    width: d,
                    height: d,
                    decoration: BoxDecoration(color: c.withValues(alpha: 0.85), shape: BoxShape.circle),
                  ),
                ),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: colors.success.withValues(alpha: 0.14), shape: BoxShape.circle),
              ),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: colors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: colors.success.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                child: Icon(Symbols.check_rounded, size: 42, weight: 700, color: colors.onPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
